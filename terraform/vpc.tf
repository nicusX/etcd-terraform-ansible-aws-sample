######
# VPC
######

resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"

  # DNS enabled
  enable_dns_support = true
  enable_dns_hostnames = true

  tags {
    Name = "${var.vpc_name}"
    Owner = "${var.owner}"
  }
}


##########
# Keypair
##########

# Import keypair (must match the PEM file we are going to use for SSH)
# Simplification: We are using a single keypair for both Bastion and etcd nodes
resource "aws_key_pair" "default_keypair" {
  key_name = "${var.default_keypair_name}"
  public_key = "${var.default_keypair_public_key}"
}

##############
## DMZ subnets
##############

# Public (DMZ) Subnets
resource "aws_subnet" "dmz" {
  count = "${var.node_count}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 8, 100 + count.index)}" # DMZ subnets are x.x.10[0-2].0/24
  availability_zone = "${element(var.zones, count.index)}"

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
    count = "${var.node_count}"
    subnet_id = "${element(aws_subnet.dmz.*.id, count.index)}"
    route_table_id = "${aws_route_table.inetgw.id}"
}


##################
## Private subnets
##################


# Private  Subnets
resource "aws_subnet" "private" {
  count = "${var.node_count}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 8, count.index)}" # Private subnets are using x.x.[0-2].0/24 subnets
  availability_zone = "${element(var.zones, count.index)}"

  tags {
    Name = "private-${count.index}"
    Owner = "${var.owner}"
  }
}

# EIPs for NAT Gateways
resource "aws_eip" "nat" {
  count = "${var.node_count}"
  vpc = true
}

# NAT Gateways
resource "aws_nat_gateway" "nat" {
  count = "${var.node_count}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.dmz.*.id, count.index)}" # Must be in a public subnet
}

# Route Tables for Private Subnets
resource "aws_route_table" "nat" {
  count = "${var.node_count}"
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
  count = "${var.node_count}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.nat.*.id, count.index)}"
}
