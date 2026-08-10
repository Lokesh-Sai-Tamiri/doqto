#!/usr/bin/env bash
# Deploy the Doqto backend: build+push image to ECR, terraform apply, bounce service.
set -euo pipefail
cd "$(dirname "$0")"

PROFILE="${AWS_PROFILE_NAME:-loki-doqto}"
REGION=us-east-1
ACCOUNT=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
REPO="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/doqto-backend"

terraform init -input=false
terraform apply

aws ecr get-login-password --profile "$PROFILE" --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

docker build --platform linux/amd64 -t "$REPO:latest" ../../doqto_backend
docker push "$REPO:latest"

aws ecs update-service --profile "$PROFILE" --region "$REGION" \
  --cluster doqto-backend --service doqto-backend --force-new-deployment >/dev/null

echo "Deployed: $(terraform output -raw api_url)"
