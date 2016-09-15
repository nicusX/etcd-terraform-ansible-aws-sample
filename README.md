# Sample project: Provisioning an clustered, HA application on AWS, using Terraform and Ansible


The goal of this sample project is demonstrate how to use Terraform and Ansible to provision the infrastructure, install and configure a clustered, High Availability application on AWS, from scratch.

We will deploy an [etcd](https://coreos.com/etcd/) HA cluster. Note that *etcd* is not the goal of this exercise, but provide a realistic use case for Terraform and Ansible.

The resulting setup is not production-ready, but gets very close to it.

- HA setup: 3 *etcd* nodes cluster, in separate Availability Zones
- *etcd* API exposed through a Load Balancer
- Separate VPC private and public subnets. *etcd* nodes not directly accessible from the Internet and managed through a VPN (*OpenVPN*).
- Private (internal) DNS zone. Nodes have stable internal DNS names.
- Nodes maintain their DNS records at boot, using cloud-init (as opposed to DNS records statically managed at provisioning-time).
- *etcd* cluster uses dynamic [DNS discovery](https://coreos.com/etcd/docs/latest/clustering.html#dns-discovery).
= *etcd* data stored on separate EBS volumes.

![infrastructure Diagram](docs/architecture-vpn.png)

## Requirements

You need a AWS with [wide permissions](docs/aws_permissions.md).
The provisioned infrastructure uses `t2.micro` instances by default and no expensive AWS resource, but it might cost a few bucks running it.


Requirements on control machine:

- Terraform (tested with Terraform 0.7.1; NOT compatible with Terraform 0.6)
- Python (tested with Python 2.7.12)
- Ansible (tested with Ansible 2.1.1.0)
- OpenVPN Client (tested with Tunelblick 3.5.0)
- (optionally) AWS CLI

If you installed Terraform using a package manager, please check the version. They are often outdated. Install the latest stable version from [Terraform website](https://www.terraform.io/intro/getting-started/install.html).

## Running the project

* [Credentials](docs/credentials.md)
* [Set up environment](docs/environment.md)
* [Terraform remote state](docs/remote_state.md)
* [Provision the infrastructure, with Terraform](docs/terraform.md)
* [Install and configure VPN and *etcd*, with Ansible](docs/ansible.md)
* [Verify *etcd* is working](docs/test_etcd.md)

Also:
* [Known simplifications](docs/simplifications.md)
* [Troubleshooting](docs/troubleshooting.md)
