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
  etcd_ip = 10.42.0.157 10.42.1.109 10.42.2.174
  etcd_private_dns = etcd0.vpc.aws etcd1.vpc.aws etcd2.vpc.aws
  openvpn_public_ip = 52.51.126.135
  openvpn_public_dns = ec2-52-51-126-135.eu-west-1.compute.amazonaws.com
```
