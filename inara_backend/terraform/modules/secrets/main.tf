# ─────────────────────────────────────────────────────────────────
# AWS Secrets Manager — single JSON secret holding all sensitive vars.
# ECS injects each key as an individual environment variable via the
# "secrets" field in the task definition.
# HIPAA: secret is encrypted at rest with AWS-managed key by default.
# ─────────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "app" {
  name        = "${var.project_name}/prod/app-secrets"
  description = "Sensitive env vars for ${var.project_name} production — HIPAA"

  # Allows recovery within 7 days if accidentally deleted
  recovery_window_in_days = 7

  tags = {
    Name       = "${var.project_name}-app-secrets"
    HIPAAScope = "true"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = jsonencode(var.app_secrets)

  lifecycle {
    # Prevents Terraform from overwriting secrets rotated outside Terraform.
    # Remove this block only if you always manage secret values via Terraform.
    ignore_changes = [secret_string]
  }
}
