
## Change the following variables according to your configuration ##

variable default_keypair_name {
  description = "Name of the KeyPair used for all nodes"
  # TODO MUST BE CHANGED to match your keypair namees
  default = "lorenzo-glf"
}

variable vpc_name {
  # TODO Change to be unique in the AWS account
  default = "Lorenzo ETCD"
}

variable elb_name {
  # TODO Change to be unique in the AWS account
  default = "lorenzo-etcd"
}

variable control_cidr {
  description = "CIDR for maintenance: inbound traffic will be allowed from this IPs"
  # TODO MUST BE CHANGED to match the outbound IP you are managing the infrastructure from
  default = "217.138.34.2/32"
  # THIS MUST BE A CIDR, not a simple address
}

variable owner {
  # TODO Change to match your name
  default = "Lorenzo"
  # No functional use.
  # Useful if you are sharing the same AWS account with others, to easily filter your resources on AWS console.
}


## Change the following variables to use a different Region ##

# Networking setup
variable "region" {
  default = "eu-west-1"
}

variable "zones" {
  description = "Availability Zones"
  default = "eu-west-1a,eu-west-1b,eu-west-1c"
}

## Do not change the following variables without a good reason ##

variable "zone_count" {
  description = "Number of AZ to use"
  default = 3
}

variable vpc_cidr {
  default = "10.42.0.0/16"
}
variable vpc_cird_glob {
  # Used for ssh_config. Must match vpc_cidr
  default = "10.42.*"
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
  default = "ami-1967056a" // Unbuntu 16.04 LTS HVM, EBS-SSD
}

variable etcd_user {
  default = "ubuntu"
}

variable etcd_instance_type {
  default = "t2.micro"
}

variable bastion_ami {
  description = "AMI for Bastion node"
  default = "ami-1967056a" // Unbuntu 16.04 LTS HVM, EBS-SSD
}

variable bastion_user {
  default = "ubuntu"
}

variable bastion_instance_type {
  default = "t2.micro"
}
