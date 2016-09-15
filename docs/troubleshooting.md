# Troubleshooting

First check:
- Have you have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and loaded the identity into ssh-agent?
- Is the VPN active?
- Have you created `./terraform/terraform.tfvars` setting valid `control_cidr` and `default_keypair_public_key`?

**The VPN must be active to reach etcd nodes**

SSH into an internal instance.
```
$ ssh ubuntu@etcd0.vpc.aws
```

You may also use the private IP of the node
```
$ ssh ubuntu@<internal-node-private-ip>
```

Test Ansible dynamic inventory:
```
$ ./site_inventory/ec2.py --list
```

Ansible direct command to etcd node:
```
$ ansible -i site_inventory/ etcd_<node-n> -a "<command>"` (e.g. `ansible etcd0 -a "/bin/hostname"`)
```

Ansible direct command to all etcd nodes:
```
$ ansible -i site_inventory/ etcd -a "<command>"
```
