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
- single keypair for bastion and internal nodes
- etcd exposes HTTP
- simplified Ansible lifecycle: playbooks do not properly support changes
- static cluster: adding a node require redeploying the cluster (but not necessarily destroying existing nodes)


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


### Edit Terraform defaults

Edit file `./terraform/variables.tf` to match your setup (see `TODO comments in the file`)

Alternatively, you may create a personal variable file overriding the defaults. E.g.
```
> terraform apply -var-file=my.tfvars
```
or setting variables from CLI
```
> terraform apply -var 'name1=value1' -var 'name2=value2'
```

**IMPORTANT: If you fail to set `control_cidr` variable to the CIDR you are connecting from, Terraform will fail connecting to the instances**

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
