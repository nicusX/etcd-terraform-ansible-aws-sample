# Install components, with Ansible

Run Ansible commands from `./ansible` subdirectory.

If you run the Ansible playbook immediately after Terraform has finished, the Instances may be still in pending state.
The playbooks will wait until SSH become available, but it may take minutes.

As we are using a VPN, the installation requires two phases:
1. Install the VPN
2. Install the site (the *etcd* cluster), through the VPN

## Install VPN

```
$ ansible-playbook -i vpn_inventory/ vpn.yaml
```

Note you have to specify a special inventory for installing the VPN, as the OpenVPN instance is resolved using public DNS name,
while internal instances are resolved through the internal (private) DNS.
Ansible EC2 Dynamic Inventory doesn't allow to specify different `vpc_destination_variable` for different groups of instances.

## Setup and open VPN

The installation generates and download in the project main directory a zip file containing OpenVPN client configuration: `sample_vpn.zip`.
Extract and install the configuration in the OpenVPN client of your choice.

Open the VPN.

## Install *etcd* cluster

The VPN must be active, to be able to configures internal nodes.
If you forget to open the VPN the playbook waits long (minutes) before timing out.

```
$ ansible-playbook site.yaml
```

The VPN may be closed when the installation is complete.
