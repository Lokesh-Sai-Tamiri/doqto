#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Build, push Docker image to ECR, then trigger ECS rolling deploy
#
# Usage:
#   cd terraform/
#   ./deploy.sh              # uses default AWS profile
#   ./deploy.sh my-profile   # uses named AWS profile
#
# Requirements:
#   - terraform init + apply already run once (ECR repo must exist)
#   - Docker running locally
#   - AWS CLI installed and authenticated
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="${1:-default}"
REGION="${AWS_REGION:-us-east-1}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " inara_backend deploy — profile: $PROFILE  region: $REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Read outputs from Terraform ───────────────────────────────────────────────
cd "$SCRIPT_DIR"
echo "→ Reading Terraform outputs..."
ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
IMAGE="${ECR_URL}:latest"
echo "  ECR repo : $ECR_URL"
echo "  Cluster  : $CLUSTER"
echo "  Service  : $SERVICE"

# ── ECR login ─────────────────────────────────────────────────────────────────
echo ""
echo "→ Logging in to ECR..."
aws ecr get-login-password --region "$REGION" --profile "$PROFILE" \
  | docker login --username AWS --password-stdin "$ECR_URL"

# ── Build image ───────────────────────────────────────────────────────────────
echo ""
echo "→ Building Docker image (platform linux/amd64)..."
cd "$BACKEND_DIR"
docker build \
  --platform linux/amd64 \
  --tag "$IMAGE" \
  .

# ── Push image ────────────────────────────────────────────────────────────────
echo ""
echo "→ Pushing image to ECR..."
docker push "$IMAGE"

# ── Trigger rolling deployment ────────────────────────────────────────────────
echo ""
echo "→ Triggering ECS rolling deployment (zero downtime)..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --profile "$PROFILE" \
  --output table \
  --query "service.deployments[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}"

echo ""
echo "✅ Deployment started. The old task stays up until the new one passes health checks."
echo ""
echo "Monitor progress:"
echo "  aws ecs describe-services \\"
echo "    --cluster $CLUSTER \\"
echo "    --services $SERVICE \\"
echo "    --region $REGION \\"
echo "    --profile $PROFILE \\"
echo "    --query 'services[0].deployments'"
echo ""
echo "Stream logs:"
echo "  aws logs tail /ecs/inara --follow --region $REGION --profile $PROFILE"
