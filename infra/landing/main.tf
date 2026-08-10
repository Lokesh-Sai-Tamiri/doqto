# Doqto landing: static site on S3 + CloudFront, waitlist API on a single Lambda.
# Usage: ./deploy.sh (installs lambda deps, terraform apply, builds & syncs the site).

terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

variable "aws_profile" {
  default = "loki-doqto"
}

variable "mongo_uri" {
  sensitive = true
}

variable "mongodb_database" {
  default = "hymn-chat"
}

variable "admin_token" {
  sensitive   = true
  description = "Token required to list waitlist entries on /admin"
}

# ponytail: PriceClass_100 (NA+EU edges) is cheapest; bump to PriceClass_200 if
# most traffic is from Asia.
variable "price_class" {
  default = "PriceClass_100"
}

data "aws_caller_identity" "me" {}

# ---------- custom domain ----------

resource "aws_acm_certificate" "site" {
  domain_name               = "doqto.ai"
  subject_alternative_names = ["www.doqto.ai"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn
}

output "acm_validation_records" {
  value = aws_acm_certificate.site.domain_validation_options
}

locals {
  name = "doqto-landing"
}

# ---------- static site bucket ----------

resource "aws_s3_bucket" "site" {
  bucket = "${local.name}-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn } }
    }]
  })
}

# ---------- waitlist lambda ----------

resource "aws_iam_role" "lambda" {
  name = "${local.name}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "waitlist" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/waitlist.zip"
  excludes    = ["package-lock.json"]
}

resource "aws_lambda_function" "waitlist" {
  function_name    = "${local.name}-waitlist"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.waitlist.output_path
  source_code_hash = data.archive_file.waitlist.output_base64sha256
  memory_size      = 256
  timeout          = 10

  environment {
    variables = {
      MONGO_URI        = var.mongo_uri
      MONGODB_DATABASE = var.mongodb_database
      ADMIN_TOKEN      = var.admin_token
    }
  }
}

# Function URL is IAM-only; CloudFront invokes it via OAC (sigv4).
resource "aws_lambda_function_url" "waitlist" {
  function_name      = aws_lambda_function.waitlist.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "cloudfront_url" {
  statement_id  = "AllowCloudFrontFunctionUrl"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.waitlist.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.site.arn
}

# AWS additionally requires plain InvokeFunction for URL invokes since Oct 2025.
resource "aws_lambda_permission" "cloudfront_invoke" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waitlist.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.site.arn
}

# ---------- cloudfront ----------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = local.name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "api" {
  name                              = "${local.name}-api"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Rewrites clean URLs (/privacy) to the files next export emits (/privacy.html).
resource "aws_cloudfront_function" "rewrite" {
  name    = "${local.name}-rewrite"
  runtime = "cloudfront-js-2.0"
  code    = <<-EOF
    function handler(event) {
      var req = event.request;
      if (req.uri.endsWith("/") && req.uri !== "/") req.uri = req.uri.slice(0, -1);
      if (!req.uri.includes(".") && req.uri !== "/") req.uri += ".html";
      return req;
    }
  EOF
}

locals {
  # AWS managed cache/origin-request policy IDs
  cache_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cache_disabled  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  fwd_all_no_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = ["doqto.ai", "www.doqto.ai"]

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin {
    origin_id                = "api"
    origin_access_control_id = aws_cloudfront_origin_access_control.api.id
    domain_name              = trimsuffix(trimprefix(aws_lambda_function_url.waitlist.function_url, "https://"), "/")
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.cache_optimized
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite.arn
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "api"
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = local.cache_disabled
    origin_request_policy_id = local.fwd_all_no_host
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ---------- CI deploy user (GitHub Actions) ----------
# ponytail: access keys in repo secrets; switch to OIDC if keys become a concern.

resource "aws_iam_user" "ci" {
  name = "${local.name}-ci"
}

resource "aws_iam_user_policy" "ci" {
  name = "deploy"
  user = aws_iam_user.ci.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.site.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.site.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = aws_cloudfront_distribution.site.arn
      }
    ]
  })
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

output "ci_access_key_id" {
  value = aws_iam_access_key.ci.id
}

output "ci_secret_access_key" {
  value     = aws_iam_access_key.ci.secret
  sensitive = true
}

output "site_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "bucket" {
  value = aws_s3_bucket.site.id
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}
