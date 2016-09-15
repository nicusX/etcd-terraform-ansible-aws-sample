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

The installation generates and download in the project main directory a zip file containing OpenVPN client configuration: `sample_vpn.zip`.
Extract and install the configuration in the OpenVPN client of your choice.

## Install *etcd* cluster

The VPN must be active, to be able to configures internal nodes.
(If you forget to open the VPN the playbook waits for minutes before timing out).

```
$ ansible-playbook -i site_inventory/ site.yaml
```

The VPN may be closed when the installation is complete.
