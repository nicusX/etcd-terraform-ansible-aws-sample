data "terraform_remote_state" "etcd-sample" {
  backend = "s3"
  config {
    bucket = "etcd-sample-state"
    key = "sample/terraform.state"
    region = "eu-west-1"
  }
}
