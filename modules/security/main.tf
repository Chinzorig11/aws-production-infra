/**
 * # Security Module
 *
 * KMS keys, S3 log buckets with encryption, and shared security resources.
 */

# --- S3 Bucket for Logs ---
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs-${var.environment}-${var.account_id}"
  tags   = { Name = "${var.project_name}-logs-${var.environment}" }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "log-lifecycle"
    status = "Enabled"
    transition { days = 30; storage_class = "STANDARD_IA" }
    transition { days = 90; storage_class = "GLACIER" }
    expiration { days = var.log_retention_days }
  }
}

variable "project_name" { type = string }
variable "environment" { type = string }
variable "account_id" { type = string }
variable "kms_key_arn" { type = string; default = "" }
variable "log_retention_days" { type = number; default = 365 }

output "log_bucket_arn" { value = aws_s3_bucket.logs.arn }
output "log_bucket_name" { value = aws_s3_bucket.logs.id }
