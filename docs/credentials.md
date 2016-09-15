# Credentials

## KeyPair

You need a valid AWS Identity (PEM) file and the corresponding Public Key. Terraform will import the [KeyPair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and Ansible will use the Identity to SSH into the machines.

Please read [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws) about supported formats.

Hint: To extract the public key from the PEM file:
```
$ ssh-keygen -y -f <keyfile>.pem
```

## Terraform and Ansible authentication

Both Terraform and Ansible expect AWS credentials in environment variables:
```
$ export AWS_ACCESS_KEY_ID=<access-key-id>
$ export AWS_SECRET_ACCESS_KEY="<secret-key>"
```

Ansible also expects ssh identity loaded into ssh agent:
```
$ ssh-add <keypair-name>.pem
```
