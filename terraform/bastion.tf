##############
## Instances
##############

# Bastion
# (Bastion has no internal DNS name)
resource "aws_instance" "bastion" {
  ami = "${var.bastion_ami}"
  instance_type = "${var.bastion_instance_type}"
  availability_zone = "${element(var.zones, 0)}" # AZ is arbitrary
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  subnet_id = "${aws_subnet.dmz.0.id}"
  associate_public_ip_address = true
  source_dest_check = false
  key_name = "${var.default_keypair_name}"

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
    ansibleFilter = "${var.ansibleFilter}"
    ansibleGroup = "bastion"
    ansibleNodeName = "bastion"
  }

  # Wait until SSH connection is available
  # (requires Identity loaded into SSH Agent)
  provisioner "remote-exec" {
    inline = ["# Connected!"]
    connection {
      host = "${self.public_ip}"
      user = "${var.bastion_user}"
      timeut = "6m"
    }
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
  value = "${aws_instance.bastion.public_ip}"
}
