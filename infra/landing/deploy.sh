#!/usr/bin/env bash
# Deploy the Doqto landing page: terraform apply, next build (static export), s3 sync, invalidate.
set -euo pipefail
cd "$(dirname "$0")"

PROFILE="${AWS_PROFILE_NAME:-loki-doqto}"

npm install --prefix lambda --omit=dev

terraform init -input=false
terraform apply

BUCKET=$(terraform output -raw bucket)
DIST=$(terraform output -raw distribution_id)

(cd ../../landing && npm run build)

aws s3 sync ../../landing/out "s3://$BUCKET" --delete --profile "$PROFILE"
aws cloudfront create-invalidation --distribution-id "$DIST" --paths "/*" --profile "$PROFILE" >/dev/null

echo "Deployed: $(terraform output -raw site_url)"
