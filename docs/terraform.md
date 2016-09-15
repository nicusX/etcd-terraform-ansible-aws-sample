# Provision infrastructure, with Terraform

Run Terraform commands from `./terraform` subdirectory.

```
$ terraform plan
$ terraform apply
```

When infrastructure provisioning is complete, Terraform outputs some useful information:
```
Outputs:

  etcd_dns = lorenzo-etcd-770737878.eu-west-1.elb.amazonaws.com
  bastion_ip = 52.51.126.135
  etcd_ip = 10.42.0.157 10.42.1.109 10.42.2.174
  etcd_private_dns = etcd0.vpc.aws etcd1.vpc.aws etcd2.vpc.aws
```


## Generated SSH config

Terraform generates `./ssh.cfg` (in project root directory, not to be committed in repo).
Ansible uses this configuration to SSH into internal instances through the Bastion.

You may also use this configuration file to SSH into internal nodes using a single command (see: [Troubleshooting](#troubleshooting)).
