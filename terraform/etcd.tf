provider "aws" {
  # Retrieve AWS credentials from env variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  access_key = ""
  secret_key = ""
  region = "${var.region}"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"

  tags {
    Name = "${var.vpc_name}"
    Owner = "${var.owner}"
  }
}

##############
## DMZ subnets
##############

# Public (DMZ) Subnets
resource "aws_subnet" "dmz" {
  count = "${var.zone_count}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 8, 100 + count.index)}" # DMZ subnets are x.x.10[0-2].0/24
  availability_zone = "${element( split(",", var.zones), count.index)}"

  tags {
    Name = "dmz-${count.index}"
    Owner = "${var.owner}"
  }
}

# Internet Gateway for DMZ Subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "dmz"
    Owner = "${var.owner}"
  }
}

# Route Tables for DMZs, through the Internet Gateway
resource "aws_route_table" "inetgw" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags {
    Name = "dmz"
    Owner = "${var.owner}"
  }
}
resource "aws_route_table_association" "dmzinetgw" {
    count = "${var.zone_count}"
    subnet_id = "${element(aws_subnet.dmz.*.id, count.index)}"
    route_table_id = "${aws_route_table.inetgw.id}"
}

#######
# ELB
######

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

##################
## Private subnets
##################


# Private  Subnets
resource "aws_subnet" "private" {
  count = "${var.zone_count}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 8, count.index)}" # Private subnets are using x.x.[0-2].0/24 subnets
  availability_zone = "${element( split(",", var.zones), count.index)}"

  tags {
    Name = "private-${count.index}"
    Owner = "${var.owner}"
  }
}

# EIPs for NAT Gateways
resource "aws_eip" "nat" {
  count = "${var.zone_count}"
  vpc = true
}

# NAT Gateways
resource "aws_nat_gateway" "nat" {
  count = "${var.zone_count}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.dmz.*.id, count.index)}" # Must be in a public subnet
}

# Route Tables for Private Subnets
resource "aws_route_table" "nat" {
  count = "${var.zone_count}"
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }
  tags {
    Name = "nat-${count.index}"
    Owner = "${var.owner}"
  }
}
resource "aws_route_table_association" "nat" {
  count = "${var.zone_count}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.nat.*.id, count.index)}"
}

##############
## Instances
##############


# Instances for etcd
resource "aws_instance" "etcd" {
  count = "${var.zone_count}"
  ami = "${var.etcd_ami}"
  instance_type = "${var.etcd_instance_type}"
  availability_zone = "${element( split(",", var.zones), count.index)}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  key_name = "${var.default_keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  tags {
    Owner = "${var.owner}"
    Name = "etcd-${count.index}"
    ansibleGroup = "etcd"
    ansibleNodeName = "etcd${count.index}"
  }
}

# EIP for Bastion
resource "aws_eip" "bastion" {
    instance = "${aws_instance.bastion.id}"
    vpc = true
}

# Bastion
resource "aws_instance" "bastion" {
  ami = "${var.bastion_ami}"
  instance_type = "${var.bastion_instance_type}"
  availability_zone = "${element(split(",", var.zones), 0)}" # AZ is arbitrary
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  subnet_id = "${aws_subnet.dmz.0.id}"
  associate_public_ip_address = true
  source_dest_check = false # TODO Is this required for tunneling SSH?
  key_name = "${var.default_keypair_name}"

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
    ansibleGroup = "bastion"
    ansibleNodeName = "bastion"
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

  # Allow etcd client traffic between nodes (required?)
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    self = true
  }

  # Allow etcd client traffic from lb
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    security_groups = ["${aws_security_group.etcdlb.id}"]
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

# Security Group allowing incoming SSH (and ping) from control IP
resource "aws_security_group" "bastion" {
  vpc_id = "${aws_vpc.main.id}"
  name = "bastion"
  description = "SSH + ICMP from control CIDR; all outbound"

  # Allow SSH traffic from control CIDR
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }

  # Allow ICMP from control CIDR
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.control_cidr}"]
  }

  # Allow all outbound traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
  }
}


####################
## Generate ssh.cfg
####################

# Generate ../ssh.cfg
# (ssh config required several cut-and-try to make it work properly, through the Bastion)
resource "template_file" "ssh_cfg" {
    template = "${file("${path.module}/template/ssh.cfg")}"
    depends_on = ["aws_instance.etcd", "aws_instance.bastion"]
    vars {
      bastion_private_ip = "${aws_instance.bastion.private_ip}"
      bastion_public_ip = "${aws_instance.bastion.public_ip}"
      bastion_user = "${var.bastion_user}"
      etcd_user = "${var.etcd_user}"
      vpc_cird_glob = "${var.vpc_cird_glob}"
    }
    provisioner "local-exec" {
      command = "echo '${ template_file.ssh_cfg.rendered }' > ../ssh.cfg"
    }
}

###########
## Outputs
###########

output "bastion_ip" {
  value = "${aws_eip.bastion.public_ip}"
}

output "etcd_dns" {
  value = "${aws_elb.etcd.dns_name}"
}

output "etcd_ip" {
  value = "${join(",", aws_instance.etcd.*.private_ip)}"
}
