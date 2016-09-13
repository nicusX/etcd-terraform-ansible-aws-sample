# Sample project: Provisioning an clustered, HA application on AWS, using Terraform and Ansible


The goal of this sample project is demonstrate how to use Terraform and Ansible to provision the infrastructure, install and configure a clustered, High Availability application on AWS, from scratch.

We will deploy an [etcd](https://coreos.com/etcd/) HA cluster. Note that *etcd* is not the goal of this exercise, but provide a realistic use case for Terraform and Ansible.

The resulting setup is not production-ready, but gets very close to it.

- HA setup: 3 *etcd* nodes cluster, in separate Availability Zones
- *etcd* API exposed through a Load Balancer
- Separate VPC private and public subnets. *etcd* nodes not directly accessible from the Internet and managed through a VPN (*OpenVPN*).
- Private (internal) DNS zone. Nodes have stable internal DNS names.
- Nodes maintain their DNS records at boot, using cloud-init (as opposed to DNS records statically managed at provisioning-time). Nodes remain reachable if dynamic IP change.
- *etcd* cluster uses dynamic [DNS discovery](https://coreos.com/etcd/docs/latest/clustering.html#dns-discovery)

![infrastructure Diagram](docs/architecture-vpn.png)

## Requirements

Requirements on control machine:

- Terraform (tested with Terraform 0.7.1; NOT compatible with Terraform 0.6)
- Python (tested with Python 2.7.12)
- Ansible (tested with Ansible 2.1.1.0)
- OpenVPN Client (tested with Tunelblick 3.5.0)
- (optionally) AWS CLI

If you installed Terraform using a package manager, please check the version. They are often outdated. Install the latest stable version from [Terraform website](https://www.terraform.io/intro/getting-started/install.html).

### AWS Account

You AWS account must have at least `AmazonEC2FullAccess`, `AmazonVPCFullAccess` and `AmazonRoute53FullAccess` permissions.

The provisioned infrastructure uses `t2.micro` instances by default and no expensive AWS resource, but it might cost a few bucks running it.


## Credentials

### KeyPair

You need a valid AWS Identity (PEM) file and the corresponding Public Key. Terraform will import the [KeyPair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and Ansible will use the Identity to SSH into the machines.

Please read [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws) about supported formats.

Hint: To extract the public key from the PEM file:
```
$ ssh-keygen -y -f <keyfile>.pem
```

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
- `bastion_ami` and `etcd_ami`: Choose AMI with Unbuntu 16.04 LTS HVM, EBS-SSD, available in the new Region

You also have to **manually** modify `./ansible/site_inventory/ec2.ini` and `./ansible/vpn_inventory/ec2.ini`, changing `regions = eu-west-1` to the Region you are using.

### (optional) Terraform remote state

By default, Terraform maintain the state only locally.
In any real-world project the state is kept (and shared) on a remote store.
An S3 bucket is one of the options provided by Terraform.

See: [How to store the state remotely, in a S3 bucket](docs/remote_state.md).


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
  etcd_ip = 10.42.0.157 10.42.1.109 10.42.2.174
  etcd_private_dns = etcd0.vpc.aws etcd1.vpc.aws etcd2.vpc.aws
  openvpn_public_ip = 52.51.126.135
  openvpn_public_dns = ec2-52-51-126-135.eu-west-1.compute.amazonaws.com
```


## Install components, with Ansible

Run Ansible commands from `./ansible` subdirectory.

If you run the Ansible playbook immediately after Terraform has finished, the Instances may be still in pending state.
The playbooks will wait until SSH become available, but it may take minutes.

As we are using a VPN, the installation requires two phases:
1. Install the VPN
2. Install the site (the *etcd* cluster), through the VPN

### Install VPN

```
> ansible-playbook -i vpn_inventory/ vpn.yaml
```

The installation generates and download in the project main directory a zip file containing OpenVPN client configuration: `sample_vpn.zip`.
Extract and install the configuration in the OpenVPN client of your choice.

### Install *etcd* cluster

The VPN must be active, to be able to configures internal nodes.
(If you forget to open the VPN the playbook waits for minutes before timing out).

```
> ansible-playbook -i site_inventory/ site.yaml
```

The VPN may be closed when the installation is complete.

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

- OpenVPN and internal nodes use the same key-pair.
- Simplified Ansible lifecycle: playbooks support changes in a simplistic way, including possibly unnecessary restarts.
- *etcd* exposed as HTTP, not HTTPS. No certificate handling.
- The OpenVPN server may not work property if the node reboots.

## Replacing an *etcd* node

If an *etcd* node gets destroyed, and you reprovision it with Ansible, not data are lost, but the new node will not be able to join the cluster.
It would require to [reconfigure the cluster](https://coreos.com/etcd/docs/latest/runtime-reconf-design.html), removing the dead node and adding the new one, using the runtime reconfiguration API.
The newly provisioned node should also start with `inital-cluster-state=existing` parameter, while `etcd.service` generated by Ansible has `inital-cluster-state=new`.


## Troubleshooting

First check:
- Have you have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and loaded the identity into ssh-agent?
- Is the VPN active?
- Have you created `./terraform/terraform.tfvars` setting valid `control_cidr` and `default_keypair_public_key`?

**The VPN must be active to reach etcd nodes**

SSH into an internal instance.
```
> ssh ubuntu@etcd0.vpc.aws
```

You may also use the private IP of the node
```
> ssh ubuntu@<internal-node-private-ip>
```

Test Ansible dynamic inventory:
```
> ./site_inventory/ec2.py --list
```

Ansible direct command to etcd node:
```
> ansible -i site_inventory/ etcd_<node-n> -a "<command>"` (e.g. `ansible etcd0 -a "/bin/hostname"`)
```

Ansible direct command to all etcd nodes:
```
> ansible -i site_inventory/ etcd -a "<command>"
```
