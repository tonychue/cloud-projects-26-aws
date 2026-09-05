#checkov:skip=CKV2_AWS_62:Terraform state bucket does not require S3 event notifications
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
  # bucket_namespace = "account-regional"

  tags = {
    Name        = var.state_bucket_name
    Purpose     = "Terraform state bucket"
    ManagedBy   = "Terraform"
    Environment = "Bootstrap"

  }
}


resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
