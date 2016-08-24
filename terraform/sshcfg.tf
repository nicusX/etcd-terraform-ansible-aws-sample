
####################
## Generate ssh.cfg
####################

# Generate ../ssh.cfg
# (ssh config required several cut-and-try to make it work properly, through the Bastion)
data "template_file" "ssh_cfg" {
    template = "${file("${path.module}/template/ssh.cfg")}"
    depends_on = ["aws_instance.etcd", "aws_instance.bastion"]
    vars {
      bastion_private_ip = "${aws_instance.bastion.private_ip}"
      bastion_public_ip = "${aws_instance.bastion.public_ip}"
      bastion_user = "${var.bastion_user}"
      etcd_user = "${var.etcd_user}"
      vpc_cird_glob = "${var.vpc_cird_glob}"
    }
}

resource "null_resource" "ssh_cfg" {
  triggers {
    template_rendered = "${ data.template_file.ssh_cfg.rendered }"
  }
  provisioner "local-exec" {
    command = "echo '${ data.template_file.ssh_cfg.rendered }' > ../ssh.cfg"
  }
}
