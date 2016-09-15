# Terraform remote state

By default, Terraform stores the state in a local file (`terraform.tfstate` in project directory).
In any real-world project the state is kept (and shared) on a remote store, for teamwork, backup etc.

Terraform directly supports storing the state in an S3 bucket.


## Create S3 bucket

You need to have AWS CLI on your machine, for creating and removing the S3 Bucket (not required by Terraform).

Create an S3 bucket for storing Terraform remote state. AWS CLI uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables for authentication.

```
$ aws s3api create-bucket \
  --bucket etcd-sample-state \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
```

In any real project, you should also enable Bucket Versioning, as recommended by [Terraform documentation](https://www.terraform.io/docs/state/remote/s3.html#s3).

To enable Bucket Versioning:
```
$ aws s3api put-bucket-versioning \
  --bucket etcd-sample-state \
  --versioning-configuration Status=Enabled
```

If you enable versioning, beware cleaning up the bucket will be a bit more tricky (see *Cleanup*, below).

## Initialise Terraform

Move to `./terraform` subdirectory and initialise Terraform project to use remote state.

```
$ terraform remote config \
  -backend=s3 \
  -backend-config="bucket=etcd-sample-state" \
  -backend-config="key=sample/terraform.state" \
  -backend-config="region=eu-west-1"
```

If any remote state exists, it is automatically pulled locally.
Otherwise, a remote state is created (possibly empty) based on the current local state.

Terraform maintains the state locally, in `.terraform/terraform.tfstate` file (when remote state is enabled).


## Remote state update

Remote state is automatically updated when you make any change that affects the state,
updating the `sample/terraform.state` file in the S3 bucket.

You may explicitly push your local state to remote using `terraform remote push`, but this is not usually required.


As we enabled Bucket Versioning, a new version of the file is created, as you may verify listing object versions:
```
$ aws s3api list-object-versions --bucket etcd-sample-state
```

## Pull remote state

To sync from the remote:
```
$ terraform remote pull
```


## Cleanup: remove S3 bucket

To completely destroy the bucket, after deleting the content:
```
$ aws s3api delete-object --bucket etcd-sample-state --key sample/terraform.state
...
$ aws s3api delete-bucket --bucket etcd-sample-state
```

If you have enabled bucket versioning, things are more tricky [see this, for example](http://stackoverflow.com/questions/29809105/ow-do-i-delete-a-versioned-bucket-in-aws-s3-using-the-cli).
The easiest solution is using  AWS web console.
