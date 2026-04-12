#!/usr/bin/env bash
# Start the Dojo registry server.
# Usage: ./start-server.sh [--dev|--prod]
#
# Environment variables:
#   PORT             - HTTP port (default: 3000)
#   DOJO_NODES_DIR   - Path to nodes directory (default: ../nodes relative to server/)
#   DOJO_ENV         - development or production (default: development)
#   DOJO_LOG_LEVEL   - debug, info, warn, error (default: info)
#   DOJO_CORS_ORIGIN - CORS allowed origins (default: *)
#   DOJO_AUTH_SECRET - JWT secret for publish endpoints (optional)

set -euo pipefail

DOJO_ROOT="${DOJO_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
SERVER_DIR="$DOJO_ROOT/server"

# Parse mode argument
MODE="${1:-}"
case "$MODE" in
  --dev)  export DOJO_ENV="development" ;;
  --prod) export DOJO_ENV="production" ;;
  "")     ;; # use DOJO_ENV from environment or default
  *)      echo "Usage: start-server.sh [--dev|--prod]" >&2; exit 1 ;;
esac

export PORT="${PORT:-3000}"
export DOJO_ENV="${DOJO_ENV:-development}"
export DOJO_LOG_LEVEL="${DOJO_LOG_LEVEL:-info}"
export DOJO_CORS_ORIGIN="${DOJO_CORS_ORIGIN:-*}"
export DOJO_NODES_DIR="${DOJO_NODES_DIR:-$DOJO_ROOT/nodes}"

# Verify server directory exists
if [[ ! -d "$SERVER_DIR" ]]; then
  echo "Error: server directory not found at $SERVER_DIR" >&2
  echo "Make sure DOJO_ROOT points to the dojo repository root" >&2
  exit 1
fi

# Verify nodes directory exists
if [[ ! -d "$DOJO_NODES_DIR" ]]; then
  echo "Error: nodes directory not found at $DOJO_NODES_DIR" >&2
  exit 1
fi

# Count nodes
NODE_COUNT=$(find "$DOJO_NODES_DIR" -name "node.json" | wc -l)

echo "Starting Dojo server..."
echo "  Mode:  $DOJO_ENV"
echo "  Port:  $PORT"
echo "  Nodes: $DOJO_NODES_DIR ($NODE_COUNT node.json files)"
echo "  Log:   $DOJO_LOG_LEVEL"
echo ""

cd "$SERVER_DIR"

# Install dependencies if needed
if [[ ! -d "node_modules" ]]; then
  echo "Installing dependencies..."
  npm install --production 2>/dev/null || npm install
  echo ""
fi

# Start the server
if [[ "$DOJO_ENV" == "development" ]]; then
  echo "Development mode — hot-reload enabled"
  if command -v npx &>/dev/null && [[ -f "node_modules/.bin/nodemon" ]]; then
    exec npx nodemon src/server.js
  else
    exec node src/server.js
  fi
else
  echo "Production mode"
  exec node src/server.js
fi
