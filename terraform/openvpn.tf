############
## Instance
############

# cloud-config script
# 1. Sets hostname
# 2. Install Python 2.x (to bootstrap Ansible)
data "template_file" "base_user_data" {
  template = "${file("${path.module}/template/base_user_data.yml")}"
  depends_on = ["aws_route53_zone.internal"]
  vars {
    hostname = "openvpn"
    domain_name = "${var.internal_dns_zone_name}"
  }
}

# OpenVPN instance
resource "aws_instance" "openvpn" {
  ami = "${var.openvpn_ami}"
  instance_type = "${var.openvpn_instance_type}"
  availability_zone = "${element(var.zones, 0)}" # AZ is arbitrary
  vpc_security_group_ids = ["${aws_security_group.openvpn.id}"]
  subnet_id = "${aws_subnet.dmz.0.id}" # DMZ subnet is arbitrary, but must match the AZ, above
  source_dest_check = false
  associate_public_ip_address = true # Needs a public IP

  key_name = "${var.default_keypair_name}"

  user_data = "${ data.template_file.base_user_data.rendered }"

  tags {
    Owner = "${var.owner}"
    Name = "openvpn"
    ansibleFilter = "${var.ansibleFilter}"
    ansibleGroup = "openvpn"
    ansibleNodeName = "openvpn"
  }
}


############
# Security
############

# Security Group allowing incoming TCP 1194 + SSH for provisioning only
resource "aws_security_group" "openvpn" {
  vpc_id = "${aws_vpc.main.id}"
  name = "openvpn"
  description = "Inbound TCP 1194; SSH from Control; all outbound"

  # Allow SSH traffic from Control IP (for provisioning)
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }

  # Allow inbound TPC traffic on 1194 (OpenVPN)
  ingress {
    from_port = 1194
    to_port = 1194
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "openvpn"
  }
}

###########
## Outputs
###########

output "openvpn_ip" {
  value = "${aws_instance.openvpn.public_ip}"
}

output "openvpn_public_dns" {
  value = "${aws_instance.openvpn.public_dns}"
}
