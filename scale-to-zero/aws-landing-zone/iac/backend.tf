terraform {
  backend "s3" {
    bucket       = "terraform-state-bkend-01"
    key          = "lambda-sqs-terraform/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
