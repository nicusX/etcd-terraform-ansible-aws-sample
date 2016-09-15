variable default_keypair_public_key {
  description = "Public Key of the default keypair"
}

variable control_cidr {
  description = "CIDR you are connecting from: inbound traffic will be allowed from this IPs"
}

variable default_keypair_name {
  description = "Name of the KeyPair used for all nodes"
  default = "etcd-sample"
}

variable vpc_name {
  description = "Name of the VPC"
  default = "etcd-sample"
}

variable elb_name {
  description = "Name of the ELB"
  default = "etcd"
}


variable owner {
  default = "ETCD"
  # No functional use.
  # Useful if you are sharing the same AWS account with others, to easily filter your resources on AWS console.
}

variable ansibleFilter {
  description = "`ansibleFilter` tag value added to all instances, to enable instance filtering in Ansible dynamic inventory"
  default = "ETCD01" # IF YOU CHANGE THIS YOU HAVE TO CHANGE instance_filters = tag:ansibleFilter=Kubernetes01 in ./ansible/hosts/ec2.ini
}

# Networking setup
variable "region" {
  default = "eu-west-1"
}

variable "zones" {
  description = "Availability Zones"
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

## Do not change the following variables without a good reason ##

variable "node_count" {
  description = "Number of etcd nodes to use (one per AZ)"
  # Must be <= the number of 'zones'
  default = 3
}

variable vpc_cidr {
  default = "10.42.0.0/16"
}

# Used in ssh.cfg. Must match vpc_cidr
variable vpc_cidr_glob {
  default = "10.42.*"
}

variable internal_dns_zone_name {
  default = "vpc.aws"
  # Must match the zone name defined in ./ansible/group_vars/all/vars.yml, if changed
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
  default = "ami-1967056a" // Unbuntu 16.04 LTS HVM, EBS-SSD (eu-west-1)
}

variable etcd_instance_type {
  default = "t2.micro"
}

variable openvpn_ami {
  description = "AMI for OpenVPN node"
  default = "ami-1967056a" // Unbuntu 16.04 LTS HVM, EBS-SSD (eu-west-1)
}

variable openvpn_user {
  default = "ubuntu"
}

variable openvpn_instance_type {
  default = "t2.micro"
}

# ETCD data volumes setup
variable etcd_data_volume_size {
  default = 5
}

variable etcd_data_volume_type {
  default = "standard"
}
