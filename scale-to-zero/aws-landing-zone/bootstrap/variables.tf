variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in"
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Aws s3 bucket name"
  default     = "terraform-state-bkend-01"
}
