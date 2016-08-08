# Provisioning etcd cluster on AWS using Terraform and Ansible

Goal of this sample project is provisioning AWS infrastructure and installing a [etcd](https://coreos.com/etcd/) AH cluster.

The infrastructure is not completely *production ready*, but close to it:

- 3 etcd nodes in separate Availability Zones
- etcd nodes in internal subnet, not directly reachable from the Internet
- etcd client access through a load balancer
- management access to internal nodes by SSH multiplexing through a Bastion, and only from authorised IPs
- realistic firewall rules (Security Groups)
- Ansible uses dynamic AWS inventory to find instances

Known simplifications:

- **requires manual modification of `./terraform/variables.tf` or overriding security defaults** (see *Edit Terraform defaults*, below)
- Single keypair for bastion and internal nodes
- etcd exposes HTTP
- Simplified Ansible lifecycle: playbooks do not properly support changes
- Static cluster: adding a node require redeploying the cluster (but not necessarily destroying existing nodes)
- The project is not using DNS. Setting stable internal and external DNS names, for bastion and etcd nodes, would actually simplify SSH configuration, avoiding to dynamically generate ssh configuration (see "Generated SSH config", below)

## Requirements

The control machine must have the following installed:

- Terraform (tested with Terraform 0.6.16)
- Python (tested with Python 2.7.12)
- Ansible (tested with Ansible 2.1.0.0)
- SSH Agent

### OSX installation

- Terraform: see https://www.terraform.io/intro/getting-started/install.html (the version in brew is outdated!)
- Python: `brew install python`
- Ansible: `pip install ansible` or http://docs.ansible.com/ansible/intro_installation.html
- SSH Agent: already running



## Credentials

### Keypair

Easiest way to generate keypairs is using AWS console. This also generates the identity file (`.pem`) in the correct format for AWS (not trivial to do it by CLI).

Note that Terraform script expects keypairs have been loaded into AWS.
Keypair names can be modified in `variables.tf` (default: use `lorenzo-glf` both for Bastion and etcd nodes)

### Terraform and Ansible authentication

Both Terraform and Ansible expects AWS credentials in environment variables:
```
> export AWS_ACCESS_KEY_ID=<access-key-id>
> export AWS_SECRET_ACCESS_KEY="<secret-key>"
```

Ansible expects ssh identity loaded into ssh agent:
```
ssh-add <keypair-name>.pem
```

## Terraform

(from `./terraform` subdir)

### Setup variables defining the environment

Before running Terraform, you MUST set a number of variables defining the environment.

- `default_keypair_name`: AWS KeyPair name for all instances. The KeyPair must be already loaded in AWS (mandatory)
- `control_cidr`: The CIDR of your IP. The Bastion will accept only traffic from this address. Note this is a CIDR, not a single IP. e.g. `123.45.67.89/32` (mandatory)
- `vpc_name`: VPC Name. Must be unique in the AWS Account (Default: "ETCD")
- `elb_name`: ELB Name. Can only contain characters valid for DNS names. Must be unique in the AWS Account (Default: "etcd")
- `owner`: `Owner` tag added to all AWS resources. No functional use. Useful if you are sharing the same AWS account with others, to easily filter your resources on AWS console. (Default: "ETCD")

A second set of variables may be optionally modified:
- `region`: AWS Region (default: "eu-west-1")
- `zones`: Comma separated list of AWS Availability Zones, in the selected Region (default: "eu-west-1a,eu-west-1b,eu-west-1c")
- `zone_count`: Number of AZ to use. Must be <= the number of AZ in `zones` (default: 3)


You have two options to set up these variables:

1. Setting `TF_VAR_name` environment variables for all of them
2. Creating a `environment.tfvars` file, and pass it as a parameter to Terraform: `terraform plan -var-file=environment.tfvars`  

Example of `environment.tfvars`:
```
default_keypair_name = "lorenzo-glf"
control_cidr = "123.45.67.89/32"
vpc_name = "Lorenzo ETCD"
elb_name = "lorenzo-etcd"
owner = "Lorenzo"
```

### Provision infrastructure

```
> terraform plan
...
> terraform apply
```

Example output of Terraform:
```
  bastion_ip = 52.51.187.85
  etcd_dns = lorenzo-etcd-1143709951.eu-west-1.elb.amazonaws.com
  etcd_ip = 10.42.0.20,10.42.1.103,10.42.2.188
```

### Generated SSH config

Terraform generates `./ssh.cfg` (in project root directory - not to be committed in repo).
This file is used by Ansible to connect to internal instances through the Bastion.

It is also useful to connect to internal instances for troubleshooting (see: troubleshooting, below).


## Ansible

(from `./ansible` subdir)

Bootstrap Ansible: Install Python 2.x on all instances (the current AMI uses Ubuntu 16.04 that have only Python 3 pre-installed)

```
> ansible-playbook bootstrap.yaml
```

Install and configure etcd:
```
> ansible-playbook etcd.yaml
```

## Verify etcd is working

(from the local machine)

Read etcd version:
```
> curl -L http://<etc-elb-dns-name>:2379/version
{"etcdserver":"3.0.4","etcdcluster":"3.0.0"}
```

Set key:
```
> curl http://<etc-elb-dns-name>:2379/v2/keys/hello -XPUT -d value="world"
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```

Retrieve key:
```
> curl http://<etc-elb-dns-name>:2379/v2/keys/hello
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```

`<etc-elb-dns-name>` is the public DNS name of the etcd ELB (as output by Terraform).

## Troubleshooting

** Be sure you have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and loaded the identity into ssh agent.**

** Also be sure you have modified `./terraform/variables.tf` to match your configuration and IP**

(from `./ansible` dir)

SSH to Bastion
```
> ssh -F ../ssh.cfg bastion
```

SSH to an internal instance (through the Bastion). Find internal node IP in Terraform output.
```
> ssh -F ../ssh.cfg <internal-node-ip>
```


Test Ansibledynamic inventory:
```
> ./hosts/ec2.py --list
```

Ansible direct command to etcd node:
```
> ansible etcd_<node-n> -a "<command>"` (e.g. `ansible etcd0 -a "/bin/hostname"`)
```

Ansible direct command to all etcd nodes:
```
> ansible etcd -a "<command>"
```

## Known Issues

### `ssh.cfg` file not overwritten

If an old version of `./ssh.cfg` exists, it might not be overwritten by Terraform, and Ansible is not able to connect.

If this is the case, just delete the file, taint the Terraform resource and regenerate (from `./terraform` dir)
```
> rm ../ssh.cfg
> terraform taint template_file.ssh_cfg
> terraform apply
```

It just regenerate `ssh.cfg` file, without touching the infrastructure.
