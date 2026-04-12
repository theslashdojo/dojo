#!/bin/bash
# Start the Vite dev server with configurable host, port, and browser-open behavior.
#
# Usage:
#   PROJECT_DIR=/path/to/project bash start-dev.sh
#   PROJECT_DIR=. HOST=0.0.0.0 PORT=3000 OPEN=false bash start-dev.sh
#
# Environment variables:
#   PROJECT_DIR  (required)  Path to the Vite project root
#   HOST         (optional)  Server host (default: localhost)
#   PORT         (optional)  Server port (default: 5173)
#   OPEN         (optional)  Open browser on start: true/false (default: true)
#
# Requires: Node.js 20.19+, vite installed in the project

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR is required — set it to the Vite project root}"
HOST="${HOST:-localhost}"
PORT="${PORT:-5173}"
OPEN="${OPEN:-true}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "Starting Vite dev server..."
echo "  Project: $PROJECT_DIR"
echo "  Host:    $HOST"
echo "  Port:    $PORT"
echo "  Open:    $OPEN"

cd "$PROJECT_DIR"

# Check for vite — local install (npx) or global
if [ -f "node_modules/.bin/vite" ]; then
    VITE_BIN="node_modules/.bin/vite"
elif command -v vite &>/dev/null; then
    VITE_BIN="vite"
elif command -v npx &>/dev/null; then
    VITE_BIN="npx vite"
else
    echo "Error: vite is not installed in this project."
    echo "Run: npm install vite"
    exit 1
fi

# Build CLI arguments
ARGS=("--host" "$HOST" "--port" "$PORT")

if [ "$OPEN" = "true" ]; then
    ARGS+=("--open")
fi

echo ""
echo "Running: $VITE_BIN ${ARGS[*]}"
echo ""

exec $VITE_BIN "${ARGS[@]}"
