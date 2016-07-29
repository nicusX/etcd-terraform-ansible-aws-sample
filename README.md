# Provisioning etcd cluster on AWS using Terraform and Ansible

TODO Describe the goal architecture

## Terraform

Run terraform from `./terraform` subdir.

### Pre-requisites

Terraform script expect `credentials` file in the working directory (not to be committed into git):
```
[default]
aws_access_key_id=XXXXX
aws_secret_access_key=YYYYYYYY
```

#### Keypair

Easiest way to generate keypairs is using AWS console. This also generates the identity file (`.pem`) in the correct format for AWS (not trivial to do it by CLI).

Note that Terraform script expects keypairs have been loaded into AWS.
Keypair names can be modified in `variables.tf` (default: use `lorenzo-glf` both for Bastion and etcd nodes)

### Provisioning infrastructure

1. Edit `variables.tf`
2. `terraform plan`
3. `terraform apply`

Example output of Terraform:
```
  bastion_ip = 52.51.187.85
  etcd_dns = lorenzo-etcd-1143709951.eu-west-1.elb.amazonaws.com
  etcd_ip = 10.42.0.20,10.42.1.103,10.42.2.188
```

## Ansible

Run Ansible from `./ansible` subdir.

### Setup

Ansible expects a file named `<keypair-name>.pem` (default: `lorenzo-glf.pem`)(not to be committed into git)

* Add SSH identity to the SSH Agent: `ssh-add <keypair-name>.pem`
* Bastion IP: `export BASTION_IP=52.51.187.85`
* AWS Credentials: `export AWS_ACCESS_KEY_ID="<ACCESS-KEY-ID>"` `export AWS_SECRET_ACCESS_KEY="<SECRET-ACCESS-KEY>"`

### SSH Access to nodes

Bastion: `ssh -F ssh.cfg bastion`
etcd node: `ssh -F ssh.cfg <NODE-PRIVATE-IP>`

### Running Ansible
Test dynamic inventory: `./ec2.py --list`
Ansible direct command to etcd node: `ansible etcd_<node-n> -i ec2.py -a "<command>"` (e.g. `ansible etcd_0 -i ec2.py -a "/bin/hostname"`)
Ansible direct command to all etcd nodes: `ansible tag_ansibleGroup_etcd -i ec2.py -a "<command>"`

Execute Ansible playbook:
```
ansible-playbook -i ec2.py -v etcd.yaml
```
