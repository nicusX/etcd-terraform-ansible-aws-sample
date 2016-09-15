# Set up environment

Before running Terraform, you must set some Terraform variables defining the environment.

- `control_cidr`: The CIDR of your IP. OpenVPN node will accept only traffic from this address (used only during VPN installation). Note this is a CIDR, not a single IP. e.g. `123.45.67.89/32` (mandatory)
- `default_keypair_public_key`: Valid public key corresponding to the Identity (PEM) you will use to SSH into VMs. e.g. `"ssh-rsa AAA....xyz"` (mandatory)


You may also optionally defines the following variables:

- `default_keypair_name`: AWS KeyPair name for all instances (Default: "etcd-sample")
- `vpc_name`: VPC Name. Must be unique in the AWS Account (Default: "ETCD")
- `elb_name`: ELB Name. Can only contain characters valid for DNS names. Must be unique in the AWS Account (Default: "etcd")
- `owner`: `Owner` tag added to all AWS resources. No functional use. It may become useful to filter your resources on AWS console if you are sharing the same AWS account with others. (Default: "ETCD").

The easiest way to do it is creating a `terraform.tfvars` [variable file](https://www.terraform.io/docs/configuration/variables.html#variable-files) in `./terraform` directory. Terraform automatically includes this file.

Example of `terraform.tfvars` variable file:
```
# Mandatory
default_keypair_public_key = "ssh-rsa AAA...zzz"
control_cidr = "123.45.67.89/32"
# Optional
default_keypair_name = "lorenzo-glf"
vpc_name = "Lorenzo ETCD"
elb_name = "lorenzo-etcd"
owner = "Lorenzo"
```

### How To Change AWS Region

By default, it uses *eu-west-1* AWS Region. To use a different Region, you have to set two additional Terraform variables:

- `region`: AWS Region (default: "eu-west-1")
- `zones`: Comma separated list of AWS Availability Zones, in the selected Region (default: "eu-west-1a,eu-west-1b,eu-west-1c")
- `zone_count`: Number of AZ to use. Must be <= the number of AZ in `zones` (default: 3)
- `openvpn_ami` and `etcd_ami`: Choose AMI with Unbuntu 16.04 LTS HVM, EBS-SSD, available in the new Region

You also have to **manually** modify `./ansible/site_inventory/ec2.ini` and `./ansible/vpn_inventory/ec2.ini`, changing `regions = eu-west-1` to the Region you are using.
