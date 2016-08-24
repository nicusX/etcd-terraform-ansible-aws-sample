provider "aws" {
  # Retrieve AWS credentials from env variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  access_key = ""
  secret_key = ""
  region = "${var.region}"
}
