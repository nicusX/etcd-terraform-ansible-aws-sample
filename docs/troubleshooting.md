# Troubleshooting

First check:
- Have you have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and loaded the identity into ssh-agent?
- Have you created `./terraform/terraform.tfvars` setting valid `control_cidr` and `default_keypair_public_key`?


SSH into Bastion (the generated `ssh.cfg` file defines an alias for Bastion's IP)
```
$ ssh -F ssh.cfg bastion
```

SSH into an internal instance (through the Bastion).

```
$ ssh -F ssh.cfg etcd0.vpc.aws
```

You may also use the private IP of the node
```
$ ssh -F ssh.cfg <internal-node-private-ip>
```


Test Ansible dynamic inventory:
```
$ ./inventory/ec2.py --list
```

Ansible direct command to etcd node:
```
$ ansible etcd_<node-n> -a "<command>"` (e.g. `ansible etcd0 -a "/bin/hostname"`)
```

Ansible direct command to all etcd nodes:
```
$ ansible etcd -a "<command>"
```
