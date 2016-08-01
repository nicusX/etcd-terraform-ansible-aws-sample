variable owner {
  default = "Lorenzo"
}

variable bastion_keypair_name {
  description = "Name of the KeyPair used for Bastion"
  default = "lorenzo-glf"
}

variable internal_keypair_name {
  description = "Name of the KeyPair used for internal nodes"
  # TODO Use different keys for Bastion and internal nodes
  default = "lorenzo-glf"
}

# Networking setup
variable "region" {
  default = "eu-west-1"
}

variable "zones" {
  description = "Availability Zones"
  default = "eu-west-1a,eu-west-1b,eu-west-1c"
}

variable "zone_count" {
  description = "Number of AZ to use"
  default = 3
}

variable vpc_name {
  default = "Lorenzo GLF"
}

variable vpc_cidr {
  default = "10.42.0.0/16"
}

variable oc_cidr {
  description = "OC outbound external IP"
  default = "217.138.34.2/32"
}

variable elb_name {
  default = "lorenzo-etcd"
}

variable etcd_client_port {
  default = "2379"
}
variable etcd_peer_port {
  default = "2380"
}


# Instances Setup
variable etcd_ami {
  description = "AMI for etcd nodes"
  default = "ami-f9dd458a" #Amazon Linux AMI 2016.03.3 x86_64 HVM GP2 (user: ec2-user)
}
variable etcd_instance_type {
  default = "t2.micro"
}

variable bastion_ami {
  description = "AMI for Bastion node"
  default = "ami-f9dd458a" #Amazon Linux AMI 2016.03.3 x86_64 HVM GP2 (user: ec2-user)
}

variable bastion_instance_type {
  default = "t2.micro"
}
