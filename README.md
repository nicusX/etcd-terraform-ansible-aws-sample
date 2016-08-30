# Sample project: Provisioning an etcd cluster on AWS, using Terraform and Ansible

The goal of this sample project is using Terraform and Ansible to provision AWS infrastructure and install an [etcd](https://coreos.com/etcd/) cluster.

The configuration is not production-ready, but get very close to it.

- HA setup: 3 *etcd* nodes cluster, in separate Availability Zones
- *etcd* API exposed through a Load Balancer
- Separate VPC private and public subnets. *etcd* nodes not directly accessible from the Internet, but managed through a *Bastion*.
- Private (internal) DNS zone. *etcd* have stable DNS names
- Instance private DNS name is not statically assigned on provisioning, but pushed by the Instance itself using cloud-init, so the Instance remains reachable even if it restarts and change IP.
- *etcd* cluster uses dynamic [DNS discovery](https://coreos.com/etcd/docs/latest/clustering.html#dns-discovery)

![infrastructure Diagram](docs/architecture.png)

Still, there are some known simplifications, compared to a production-ready solution (See [Known simplifications](#user-content-known-issues))

## Requirements

Requirements on control machine:

- Terraform (tested with Terraform 0.7.1; NOT compatible with Terraform 0.6)
- Python (tested with Python 2.7.12)
- Ansible (tested with Ansible 2.1.0.0)
- SSH Agent running

Check the version of Terraform installed by your distribution package manager, or by `brew` for OS X users. They are usually outdated. To download and install the latest version, see: https://www.terraform.io/intro/getting-started/install.html

You also need an AWS account, with `AmazonEC2FullAccess`, `AmazonVPCFullAccess` and `AmazonRoute53FullAccess` permissions.

The provisioned infrastructure uses `t2.micro` instances by default and no "expensive" AWS resource, but it might cost a few bucks running it.

## AWS Credentials

### KeyPair

You need a valid AWS Identity (`.pem`) file and Public Key. Terraform will import the [KeyPair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and Ansible will use the Identity to SSH into the machines.

Please read [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws) about supported formats.


### Terraform and Ansible authentication

Both Terraform and Ansible expect AWS credentials in environment variables:
```
> export AWS_ACCESS_KEY_ID=<access-key-id>
> export AWS_SECRET_ACCESS_KEY="<secret-key>"
```

Ansible also expects ssh identity loaded into ssh agent:
```
ssh-add <keypair-name>.pem
```


## Set up environment

Before running Terraform, you must set some Terraform variables defining the environment.

- `control_cidr`: The CIDR of your IP. The Bastion will accept only traffic from this address. Note this is a CIDR, not a single IP. e.g. `123.45.67.89/32` (mandatory)
- `default_keypair_public_key`: Valid public key corresponding to the Identity you will use to SSH into VMs. e.g. `"ssh-rsa AAA....xyz"` (mandatory)

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
- `bastion_ami` and `etcd_ami`: Choose AMI with Unbuntu 16.04 LTS HVM, EBS-SSD, available in the new Region

You also have to **manually** modify `./ansible/hosts/ec2.ini`, changing `regions = eu-west-1` to the Region you are using.


## Provision infrastructure, with Terraform

Run Terraform commands from `./terraform` subdirectory.

```
> terraform plan
> terraform apply
```

When infrastructure provisioning is complete, Terraform outputs some useful information:
```
Outputs:

  etcd_dns = lorenzo-etcd-770737878.eu-west-1.elb.amazonaws.com
  bastion_ip = 52.51.126.135
  etcd_ip = 10.42.0.157 10.42.1.109 10.42.2.174
  etcd_private_dns = etcd0.vpc.aws etcd1.vpc.aws etcd2.vpc.aws
```

### Generated SSH config

Terraform generates `./ssh.cfg` (in project root directory, not to be committed in repo).
Ansible uses this configuration to SSH into internal instances through the Bastion.

You may also use this configuration file to SSH into internal nodes using a single command (see: [Troubleshooting](#user-content-troubleshooting)).



## Install components, with Ansible

If you run the Ansible playbook immediately after Terraform has finished, the Instances may be still in pending state.
The included `bootstrap.yaml` playbook waits until Bastion SSH become available.

Run Ansible commands from `./ansible` subdirectory.

```
> ansible-playbook site.yaml
```

## Verify etcd is working

The *etcd* cluster is now running and exposed through the ELB.
`<etc-elb-dns-name>` is the public DNS name of the ELB, outputs by Terraform.


Read *etcd* version:
```
> curl -L http://<etc-elb-dns-name>:2379/version
{"etcdserver":"3.0.4","etcdcluster":"3.0.0"}
```

Set a key:
```
> curl http://<etc-elb-dns-name>:2379/v2/keys/hello -XPUT -d value="world"
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```

Retrieve a key:
```
> curl http://<etc-elb-dns-name>:2379/v2/keys/hello
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```

## Known simplifications

This sample project has simplifications, compared to a real-world infrastructure.

- Same key-pair used for Bastion and internal nodes
- Simplified Ansible lifecycle: playbooks support changes in a simplistic way, including possibly unnecessary restarts.
- *etcd* exposed as HTTP (not HTTPS)

## Replacing an *etcd* node

If an *etcd* node get destroyed and reprovision it with Ansible playbook, not data is lost, but the new node will not be able to join the cluster.
It would require to [reconfigure the cluster](https://coreos.com/etcd/docs/latest/runtime-reconf-design.html), removing the dead node and adding the new one, using the runtime reconfiguration API.
The newly provisioned node should also start with `inital-cluster-state=existing` parameter, while `etcd.service` generated by Ansible has `inital-cluster-state=new`.


## Troubleshooting

First check:
- Have you have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and loaded the identity into ssh-agent?
- Have you created `./terraform/terraform.tfvars` setting valid `control_cidr` and `default_keypair_public_key`?


SSH into Bastion (the generated `ssh.cfg` file defines an alias for Bastion's IP)
```
> ssh -F ssh.cfg bastion
```

SSH into an internal instance (through the Bastion).

```
> ssh -F ssh.cfg etcd0.vpc.aws
```

You may also use the private IP of the node
```
> ssh -F ssh.cfg <internal-node-private-ip>
```


Test Ansible dynamic inventory:
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
