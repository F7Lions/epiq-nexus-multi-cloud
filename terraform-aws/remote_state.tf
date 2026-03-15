# 1. The S3 Bucket for the State File (Must be globally unique)
resource "aws_s3_bucket" "terraform_state" {

  bucket = "epiq-nexus-tfstate-f7lions"
  force_destroy = true

  # Senior Tip: We prevent destroy so a rogue pipeline doesn't delete our state
  #lifecycle {
  #prevent_destroy = true
  #}
}

# IM8 Requirement: Versioning for audit trails
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IM8 Requirement: Encryption at Rest (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IM8 Requirement: Block ALL public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. The DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "epiq-nexus-tf-locks"
  billing_mode = "PAY_PER_REQUEST" # FinOps: Costs $0 if idle
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}