#######
# ELB
#######

# Load Balancer for etcd API
resource "aws_elb" "etcd" {
    name = "${var.elb_name}"
    listener {
      instance_port = "${var.etcd_client_port}"
      instance_protocol = "TCP"
      lb_port = "${var.etcd_client_port}"
      lb_protocol = "TCP"
    }
    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 5
      target = "HTTP:${var.etcd_client_port}/health"
      interval = 30
    }

    cross_zone_load_balancing = true
    instances = ["${aws_instance.etcd.*.id}"]
    subnets = ["${aws_subnet.dmz.*.id}"]
    security_groups = ["${aws_security_group.etcdlb.id}"]

    tags {
      Name = "etcd"
      Owner = "${var.owner}"
    }
}

###############
## IAM Policy
###############


# Datasource to retrieve AWS account ID (see https://github.com/hashicorp/terraform/issues/4390)
data "aws_caller_identity" "current" {}


# IAM Role for etcd instances
resource "aws_iam_role" "etcd" {
  name = "etcd-node"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Role Policy allowing Instances to update Route53 records
resource "aws_iam_role_policy" "etcd_update_dns_record" {
  name = "manage-route53-records"
  role = "${aws_iam_role.etcd.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "route53:ChangeResourceRecordSets",
      "Effect": "Allow",
      "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.internal.zone_id}"
    }
  ]
}
EOF
}

# Role Policy allowing Instances to attach EBS volumes
# TODO Add a Condition to limit attachable Volumes based on Tag
resource "aws_iam_role_policy" "attach_volume" {
  name = "attach-volume"
  role = "${aws_iam_role.etcd.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ec2:AttachVolume",
      "Effect": "Allow",
      "Resource": "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
    },
    {
      "Action": "ec2:AttachVolume",
      "Effect": "Allow",
      "Resource": "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*"
    }
  ]
}
EOF
}

# IAM Instance Profile
resource  "aws_iam_instance_profile" "etcd" {
 name = "etcd-node"
 roles = ["${aws_iam_role.etcd.name}"]
}


##########################
# Persistent Data Volumes
##########################

# Prepare one persistent EBS volume per etcd node
resource "aws_ebs_volume" "etcd_data" {
  count = "${var.node_count}"
  availability_zone = "${element(var.zones, count.index)}"

  size = "${var.etcd_data_volume_size}"
  type = "${var.etcd_data_volume_type}"

  tags {
    Owner = "${var.owner}"
    Name = "etcd-data-${count.index}"
  }
}

# Cannot directly attach the EBS volume to the instance, using `aws_volume_attachment`
# as a known Terraform issue would prevent instances to be shut down
# (see https://github.com/hashicorp/terraform/issues/2957)


##############
## Instances
##############


# cloud-config script
# 1. Sets hostname and update Route53 record at boot
# 2. Attach EBS Volume
# 3. Install Python 2.x
data "template_file" "etcd_user_data" {
  template = "${file("${path.module}/template/etcd_user_data.yml")}"
  depends_on = ["aws_route53_zone.internal"]
  vars {
    region = "${var.region}"
    zone_id = "${aws_route53_zone.internal.zone_id}"
    record_ttl = 60
    domain_name = "${var.internal_dns_zone_name}"
  }
}

# Instances for etcd
resource "aws_instance" "etcd" {
  count = "${var.node_count}"
  depends_on = ["aws_ebs_volume.etcd_data"] # This dependecy is implicit inside user_data script

  ami = "${var.etcd_ami}"
  instance_type = "${var.etcd_instance_type}"
  availability_zone = "${element(var.zones, count.index)}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  key_name = "${var.default_keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.etcd.id}"

  # We have to use the 'replace' hack, as Terraform doesn't support instance specific variabes in template_file yet
  # See https://github.com/hashicorp/terraform/issues/2167
  user_data = "${ replace( replace( data.template_file.etcd_user_data.rendered, "#HOSTNAME", "etcd${count.index}"), "#VOLUMEID", "${ element(aws_ebs_volume.etcd_data.*.id, count.index) }" ) }"

  tags {
    Owner = "${var.owner}"
    Name = "etcd-${count.index}"
    ansibleFilter = "${var.ansibleFilter}"
    ansibleGroup = "etcd"
    ansibleNodeName = "etcd${count.index}"
  }
}


############
# Security
############

# Securty group allowing all outbound traffic and SSH from the Bastion, and etcd ports internally
resource "aws_security_group" "internal" {
  vpc_id = "${aws_vpc.main.id}"
  name = "internal"
  description = "SSH from bastion; internal+lb etcd; all outbound"

  # Allow all outbound traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH from Bastion
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    security_groups = ["${aws_security_group.bastion.id}"]
  }

  # Allow etcd peer traffic between nodes
  ingress {
    from_port = "${var.etcd_peer_port}"
    to_port = "${var.etcd_peer_port}"
    protocol = "TCP"
    self = true
  }

  # Allow etcd client traffic between nodes
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    self = true
  }

  # Allow etcd client traffic from LB
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    security_groups = ["${aws_security_group.etcdlb.id}"]
  }

  # Allow internal ICMP traffic
  ingress {
    from_port = 8
    to_port = 0
    protocol = "ICMP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "internal"
  }
}

# Security Group for etcd ELB
resource "aws_security_group" "etcdlb" {
  vpc_id = "${aws_vpc.main.id}"
  name = "etcd-lb"
  description = "Inbound etcd client from world; outbound etcd client to internal"

  # etcd client from world
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound etcd client to VPC
  egress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "etcd-lb"
  }
}

###########
## Outputs
###########

output "etcd_dns" {
  value = "${aws_elb.etcd.dns_name}"
}

output "etcd_ip" {
  value = "${join(" ", aws_instance.etcd.*.private_ip)}"
}
