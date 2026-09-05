locals {
  project     = "aws-landing-zone"
  environment = "management"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "Terraform"
    Repository  = "aws-landing-zone"
    Owner       = "platform-engineering"
  }
}
