output "api_url" {
  description = "Production API URL"
  value       = "https://${var.domain_name}"
}

output "alb_dns_name" {
  description = "Raw ALB DNS name (fallback if DNS not yet propagated)"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this in deploy.sh and as container_image in tfvars"
  value       = module.ecs.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by deploy.sh"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name — used by deploy.sh"
  value       = module.ecs.service_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group to view app logs"
  value       = module.ecs.log_group_name
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret (reference this to update secrets)"
  value       = module.secrets.secret_arn
}

output "cloudtrail_bucket" {
  description = "S3 bucket storing CloudTrail audit logs (HIPAA)"
  value       = module.cloudtrail.trail_bucket
}
