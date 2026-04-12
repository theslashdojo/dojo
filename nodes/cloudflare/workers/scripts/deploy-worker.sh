#!/usr/bin/env bash
set -euo pipefail

# Deploy a Cloudflare Worker using Wrangler
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
# Optional env: WORKER_ENV (named environment, e.g., "staging")

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "Error: CLOUDFLARE_ACCOUNT_ID is not set" >&2
  exit 1
fi

# Check wrangler is available
if ! command -v wrangler &>/dev/null; then
  echo "Installing wrangler..."
  npm install -g wrangler
fi

# Check wrangler.toml exists
if [ ! -f "wrangler.toml" ]; then
  echo "Error: wrangler.toml not found in current directory" >&2
  exit 1
fi

# Build deploy command
DEPLOY_CMD="wrangler deploy"

if [ -n "${WORKER_ENV:-}" ]; then
  DEPLOY_CMD="$DEPLOY_CMD --env $WORKER_ENV"
  echo "Deploying to environment: $WORKER_ENV"
else
  echo "Deploying to production"
fi

# Deploy
export CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ACCOUNT_ID

echo "Running: $DEPLOY_CMD"
$DEPLOY_CMD

echo "Deployment complete."

# Show deployment info
WORKER_NAME=$(grep '^name' wrangler.toml | head -1 | sed 's/name *= *"\(.*\)"/\1/')
echo "Worker: $WORKER_NAME"
echo "Streaming logs: wrangler tail $WORKER_NAME"
