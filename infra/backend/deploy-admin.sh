#!/usr/bin/env bash
# Deploy the Doqto admin panel: build+push image to ECR, terraform apply, bounce service.
# First run: terraform prints admin_acm_validation_records — add that CNAME plus
# admin.doqto.ai CNAME -> alb_dns at the registrar before the cert validates.
set -euo pipefail
cd "$(dirname "$0")"

PROFILE="${AWS_PROFILE_NAME:-loki-doqto}"
REGION=us-east-1
ACCOUNT=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
REPO="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/doqto-admin"

terraform init -input=false
terraform apply

aws ecr get-login-password --profile "$PROFILE" --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

docker build --platform linux/amd64 -t "$REPO:latest" ../../doqto_admin
docker push "$REPO:latest"

aws ecs update-service --profile "$PROFILE" --region "$REGION" \
  --cluster doqto-backend --service doqto-admin --force-new-deployment >/dev/null

echo "Deployed: $(terraform output -raw admin_url)"
