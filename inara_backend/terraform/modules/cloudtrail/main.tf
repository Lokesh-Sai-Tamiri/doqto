# ─────────────────────────────────────────────────────────────────
# CloudTrail — logs all AWS API calls (HIPAA Security Rule § 164.312)
# Retention: 7 years (HIPAA requires 6 years minimum)
# ─────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "trail" {
  # Account ID in the name ensures global uniqueness
  bucket        = "${var.project_name}-cloudtrail-${var.aws_account_id}"
  force_destroy = false
  tags          = { Name = "${var.project_name}-cloudtrail" }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER" # cost-optimised cold storage after 90 days
    }

    expiration {
      days = 2555 # 7 years
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.bucket
  include_global_service_events = true # captures IAM, STS, etc.
  is_multi_region_trail         = true # captures all regions
  enable_log_file_validation    = true # SHA-256 digest for tamper detection (HIPAA)

  tags = {
    Name       = "${var.project_name}-cloudtrail"
    HIPAAScope = "true"
  }

  depends_on = [aws_s3_bucket_policy.trail]
}
