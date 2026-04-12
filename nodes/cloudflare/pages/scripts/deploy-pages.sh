#!/usr/bin/env bash
set -euo pipefail

# Deploy to Cloudflare Pages via Wrangler CLI
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
# Usage:
#   ./deploy-pages.sh <output-dir> <project-name> [branch]
# Example:
#   ./deploy-pages.sh ./dist my-site
#   ./deploy-pages.sh ./dist my-site staging

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "Error: CLOUDFLARE_ACCOUNT_ID is not set" >&2
  exit 1
fi

OUTPUT_DIR="${1:?Usage: deploy-pages.sh <output-dir> <project-name> [branch]}"
PROJECT_NAME="${2:?Usage: deploy-pages.sh <output-dir> <project-name> [branch]}"
BRANCH="${3:-}"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: Output directory not found: $OUTPUT_DIR" >&2
  echo "Did you run the build command first?" >&2
  exit 1
fi

# Check wrangler is available
if ! command -v wrangler &>/dev/null; then
  echo "Installing wrangler..."
  npm install -g wrangler
fi

# Build deploy command
DEPLOY_CMD="wrangler pages deploy $OUTPUT_DIR --project-name $PROJECT_NAME"

if [ -n "$BRANCH" ]; then
  DEPLOY_CMD="$DEPLOY_CMD --branch $BRANCH"
  echo "Deploying to branch: $BRANCH (preview)"
else
  echo "Deploying to production"
fi

export CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ACCOUNT_ID

echo "Running: $DEPLOY_CMD"
$DEPLOY_CMD

echo ""
echo "Deployment complete."
echo "Production URL: https://$PROJECT_NAME.pages.dev"
if [ -n "$BRANCH" ]; then
  echo "Preview URL: https://$BRANCH.$PROJECT_NAME.pages.dev"
fi
