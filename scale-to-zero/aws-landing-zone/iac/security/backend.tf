terraform {
  backend "s3" {
    bucket       = "terraform-state-bkend-01"
    key          = "landing-zone/security/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
