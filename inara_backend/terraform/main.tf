terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ─────────────────────────────────────────────────────────────────
  # Recommended: use S3 backend so state is shared and not local.
  # Create the bucket manually first, then uncomment.
  # ─────────────────────────────────────────────────────────────────
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "inara-backend/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "terraform"
      HIPAAScope  = "true"
    }
  }
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────
# Networking — VPC, public subnets, security groups
# ─────────────────────────────────────────────────────────────────
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

# ─────────────────────────────────────────────────────────────────
# Secrets — AWS Secrets Manager for all sensitive env vars
# ─────────────────────────────────────────────────────────────────
module "secrets" {
  source       = "./modules/secrets"
  project_name = var.project_name
  app_secrets  = var.app_secrets
}

# ─────────────────────────────────────────────────────────────────
# ALB — HTTPS load balancer with custom domain + ACM cert
# ─────────────────────────────────────────────────────────────────
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.networking.alb_sg_id
  domain_name       = var.domain_name
  zone_id           = var.route53_zone_id
  aws_account_id    = data.aws_caller_identity.current.account_id
}

# ─────────────────────────────────────────────────────────────────
# ECS Fargate — FastAPI + Socket.io container, zero-downtime deploys
# ─────────────────────────────────────────────────────────────────
module "ecs" {
  source            = "./modules/ecs"
  project_name      = var.project_name
  aws_region        = var.aws_region
  aws_account_id    = data.aws_caller_identity.current.account_id
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  ecs_sg_id         = module.networking.ecs_sg_id
  target_group_arn  = module.alb.target_group_arn
  container_image   = var.container_image
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  desired_count     = var.desired_count
  secret_arn        = module.secrets.secret_arn
  secret_keys       = keys(var.app_secrets)
  app_env_vars      = var.app_env_vars
  s3_bucket_names = [
    lookup(var.app_env_vars, "S3_BUCKET_AVATARS", "hymnchat-avatars"),
    lookup(var.app_env_vars, "S3_BUCKET_ATTACHMENTS", "hymnchat-attachments"),
    lookup(var.app_env_vars, "S3_BUCKET_ORG_LOGOS", "hymnchat-org-logos"),
  ]
}

# ─────────────────────────────────────────────────────────────────
# CloudTrail — API audit logging required for HIPAA
# ─────────────────────────────────────────────────────────────────
module "cloudtrail" {
  source         = "./modules/cloudtrail"
  project_name   = var.project_name
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
}
