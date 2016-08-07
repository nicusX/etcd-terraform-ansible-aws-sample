provider "aws" {
  access_key = ""
  secret_key = ""
  shared_credentials_file = "./credentials"
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

# ELB
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
  key_name = "${var.internal_keypair_name}"
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  tags {
    Owner = "${var.owner}"
    Name = "etcd-${count.index}"
    ansibleGroup = "etcd"
  }
}

# Securty group allowing all outbound traffic and SSH from the Bastion, and etcd ports internally
resource "aws_security_group" "internal" {
  vpc_id = "${aws_vpc.main.id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    security_groups = ["${aws_security_group.bastion.id}"] # Allow SSH from the Bastion
  }

  # Allow communication between internal nodes
  ingress {
    from_port = "${var.etcd_peer_port}"
    to_port = "${var.etcd_peer_port}"
    protocol = "TCP"
    self = true
  }
  ingress {
    from_port = "${var.etcd_client_port}"
    to_port = "${var.etcd_client_port}"
    protocol = "TCP"
    self = true
  }

  tags {
    Owner = "${var.owner}"
    Name = "internal"
  }
}

##########
## Bastion
##########

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
  key_name = "${var.bastion_keypair_name}"

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
    ansibleGroup = "bastion"
  }
}

# Security Group allowing incoming SSH (and ping) from OC IP
resource "aws_security_group" "bastion" {
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.oc_cidr}"]
  }
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.oc_cidr}"]
  }

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
resource "template_file" "ssh_cfg" {
    template = "${file("${path.module}/template/ssh.cfg")}"
    depends_on = ["aws_instance.etcd", "aws_instance.bastion"]
    vars {
      bastion_public_ip = "${aws_instance.bastion.public_ip}"
      bastion_user = "${var.bastion_user}"
      etcd_user = "${var.etcd_user}"
      vpc_cird_glob = "${var.vpc_cird_glob}"
    }
    provisioner "local-exec" {
      command = "echo '${ template_file.ssh_cfg.rendered }' > ../ssh.cfg"
    }
}


## Outputs

output "bastion_ip" {
  value = "${aws_eip.bastion.public_ip}"
}

output "etcd_dns" {
  value = "${aws_elb.etcd.dns_name}"
}

output "etcd_ip" {
  value = "${join(",", aws_instance.etcd.*.private_ip)}"
}
