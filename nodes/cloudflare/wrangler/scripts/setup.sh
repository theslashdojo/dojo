#!/usr/bin/env bash
set -euo pipefail

# Install Wrangler CLI and verify authentication
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID

echo "=== Wrangler Setup ==="

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "Error: Node.js is required (>= 18)" >&2
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "Error: Node.js >= 18 required, found v$(node -v)" >&2
  exit 1
fi
echo "Node.js: $(node -v)"

# Install wrangler if not present
if ! command -v wrangler &>/dev/null; then
  echo "Installing wrangler..."
  npm install -g wrangler
else
  echo "Wrangler: $(wrangler --version)"
fi

# Check authentication
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo ""
  echo "Warning: CLOUDFLARE_API_TOKEN is not set."
  echo "Set it with: export CLOUDFLARE_API_TOKEN=\"your-token\""
  echo "Or run: wrangler login"
else
  echo ""
  echo "Verifying authentication..."
  export CLOUDFLARE_API_TOKEN
  if [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    export CLOUDFLARE_ACCOUNT_ID
  fi
  wrangler whoami
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Quick start:"
echo "  npm create cloudflare@latest my-worker   # Create a project"
echo "  cd my-worker && wrangler dev              # Start dev server"
echo "  wrangler deploy                           # Deploy to production"
