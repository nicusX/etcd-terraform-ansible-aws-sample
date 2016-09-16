
####################
## Generate ssh.cfg
####################

# Generate ssh.cfg for connecting to internal instances through the Bastion
data "template_file" "ssh_cfg" {
    template = "${file("${path.module}/template/ssh.cfg")}"
    depends_on = ["aws_instance.etcd", "aws_instance.bastion"]
    vars {
      bastion_user = "${var.bastion_user}"
      etcd_user = "${var.etcd_user}"
      bastion_public_ip = "${aws_instance.bastion.public_ip}"
      bastion_public_dns = "${aws_instance.bastion.public_dns}"
      internal_dns_zone_name = "${var.internal_dns_zone_name}"
      vpc_cidr_glob = "${var.vpc_cidr_glob}"
    }
}

resource "null_resource" "ssh_cfg" {
  triggers {
    template_rendered = "${ data.template_file.ssh_cfg.rendered }"
  }
  # Remove any old ssh.cfg file
  provisioner "local-exec" {
    command = "rm -f ../ssh.cfg; echo '${ data.template_file.ssh_cfg.rendered }' > ../ssh.cfg"
  }
}
