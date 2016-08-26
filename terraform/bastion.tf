##############
## Static IP
##############

# EIP for Bastion
resource "aws_eip" "bastion" {
    instance = "${aws_instance.bastion.id}"
    vpc = true
}

##############
## Instances
##############

# Bastion
# (Bastion has not internal DNS name)
resource "aws_instance" "bastion" {
  ami = "${var.bastion_ami}"
  instance_type = "${var.bastion_instance_type}"
  availability_zone = "${element(var.zones, 0)}" # AZ is arbitrary
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  subnet_id = "${aws_subnet.dmz.0.id}"
  source_dest_check = false # TODO Is this required?
  key_name = "${var.default_keypair_name}"

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
    ansibleFilter = "${var.ansibleFilter}"
    ansibleGroup = "bastion"
    ansibleNodeName = "bastion"
  }
}


############
# Security
############

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

  # Allow ICMP internal and from Control IP
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.control_cidr}", "${var.vpc_cidr}"]
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

###########
## Outputs
###########

output "bastion_ip" {
  value = "${aws_eip.bastion.public_ip}"
}
