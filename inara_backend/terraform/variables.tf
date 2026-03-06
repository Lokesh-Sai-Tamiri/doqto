variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all AWS resources"
  type        = string
  default     = "inara"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy into (min 2 required by ALB)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "domain_name" {
  description = "Custom domain for the backend API (e.g. api.yourdomain.com). Must already have a hosted zone in Route 53."
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID for var.domain_name"
  type        = string
}

variable "container_image" {
  description = "Full ECR image URI. Set this after the first deploy.sh run. Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/inara:latest"
  type        = string
  default     = "public.ecr.aws/docker/library/python:3.12-slim" # placeholder — overridden in tfvars
}

variable "task_cpu" {
  description = "ECS task CPU units. 256 = 0.25 vCPU (~$7/month). Bump to 512 if you need more."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "ECS task memory in MiB. 512 is sufficient for low traffic."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS task replicas. 1 is fine for 10-25 users/month."
  type        = number
  default     = 1
}

# ─────────────────────────────────────────────────────────────────
# Non-sensitive env vars — stored in plaintext in the ECS task definition.
# Do NOT put secrets here.
# ─────────────────────────────────────────────────────────────────
variable "app_env_vars" {
  description = "Non-sensitive environment variables injected into the ECS container"
  type        = map(string)
  default = {
    DEBUG                   = "false"
    HOST                    = "0.0.0.0"
    PORT                    = "8000"
    AWS_REGION              = "us-east-1"
    S3_BUCKET_AVATARS       = "hymnchat-avatars"
    S3_BUCKET_ATTACHMENTS   = "hymnchat-attachments"
    S3_BUCKET_ORG_LOGOS     = "hymnchat-org-logos"
    S3_PRESIGNED_URL_EXPIRY = "3600"
    RATE_LIMIT_REQUESTS     = "100"
    RATE_LIMIT_WINDOW       = "60"
    MONGODB_DATABASE        = "hymn-chat"
    # Replace * with your mobile app origin (e.g. capacitor://localhost)
    CORS_ORIGINS = "[\"*\"]"
  }
}

# ─────────────────────────────────────────────────────────────────
# Sensitive secrets — stored in AWS Secrets Manager, NEVER in state.
# Populate these in terraform.tfvars (which is gitignored).
# Each key in this map becomes an environment variable name in the container.
# ─────────────────────────────────────────────────────────────────
variable "app_secrets" {
  description = "Sensitive env vars. Each key = one env var injected from Secrets Manager."
  type        = map(string)
  sensitive   = true
  default     = {}
}
