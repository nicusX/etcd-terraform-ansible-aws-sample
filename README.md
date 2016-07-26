# Provisioning etcd cluster on AWS using Terraform and Ansible

## Credentials
Terraform script expect file `credentials` in the same directory:

```
[default]
aws_access_key_id=XXXXX
aws_secret_access_key=YYYYYYYY
```

## Key
AWS keypair named `lorenzo-glf` is expected to be manually loaded (currently NOT imported by Terraform)
