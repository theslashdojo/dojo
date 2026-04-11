#!/usr/bin/env bash
set -euo pipefail
# Run an npm script by name with optional argument forwarding and env vars
# Usage: run-script.sh <script-name> [--env KEY=VALUE]... [-- args...]
#
# Examples:
#   run-script.sh build
#   run-script.sh test -- --watch --coverage
#   run-script.sh build --env NODE_ENV=production
#   run-script.sh dev --env PORT=3000 --env DEBUG=true

SCRIPT_NAME=""
SCRIPT_ARGS=()
ENV_VARS=()
PARSING_SCRIPT_ARGS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  if [ -n "$PARSING_SCRIPT_ARGS" ]; then
    # Everything after -- is forwarded to the script
    SCRIPT_ARGS+=("$1")
    shift
    continue
  fi

  case "$1" in
    --)
      PARSING_SCRIPT_ARGS="true"
      shift
      ;;
    --env)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        echo "Error: --env requires KEY=VALUE format"
        exit 1
      fi
      ENV_VARS+=("$2")
      shift 2
      ;;
    -*)
      echo "Unknown flag: $1"
      echo "Usage: run-script.sh <script-name> [--env KEY=VALUE]... [-- args...]"
      exit 1
      ;;
    *)
      if [ -z "$SCRIPT_NAME" ]; then
        SCRIPT_NAME="$1"
      else
        echo "Error: Multiple script names provided. Use -- to separate script arguments."
        echo "Usage: run-script.sh <script-name> [--env KEY=VALUE]... [-- args...]"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate inputs
if [ -z "$SCRIPT_NAME" ]; then
  echo "Usage: run-script.sh <script-name> [--env KEY=VALUE]... [-- args...]"
  echo ""
  if [ -f "package.json" ]; then
    echo "Available scripts:"
    node -e "
      const s = require('./package.json').scripts || {};
      const entries = Object.entries(s);
      if (entries.length === 0) { console.log('  (none defined)'); }
      else { entries.forEach(([k, v]) => console.log('  ' + k + ': ' + v)); }
    "
  else
    echo "(no package.json found in current directory)"
  fi
  exit 1
fi

# Verify package.json exists
if [ ! -f "package.json" ]; then
  echo "Error: No package.json found in current directory ($(pwd))"
  exit 1
fi

# Check if the script exists in package.json
SCRIPT_EXISTS=$(node -e "
  const scripts = require('./package.json').scripts || {};
  console.log(scripts['$SCRIPT_NAME'] ? 'yes' : 'no');
")

if [ "$SCRIPT_EXISTS" = "no" ]; then
  echo "Error: Script '$SCRIPT_NAME' not found in package.json"
  echo ""
  echo "Available scripts:"
  node -e "
    const s = require('./package.json').scripts || {};
    const entries = Object.entries(s);
    if (entries.length === 0) { console.log('  (none defined)'); }
    else { entries.forEach(([k, v]) => console.log('  ' + k + ': ' + v)); }
  "
  exit 1
fi

# Show what we are about to run
SCRIPT_CMD=$(node -e "console.log(require('./package.json').scripts['$SCRIPT_NAME'])")
echo "=== Running: npm run $SCRIPT_NAME ==="
echo "  Command: $SCRIPT_CMD"

if [ ${#ENV_VARS[@]} -gt 0 ]; then
  echo "  Environment:"
  for env_var in "${ENV_VARS[@]}"; do
    echo "    $env_var"
  done
fi

if [ ${#SCRIPT_ARGS[@]} -gt 0 ]; then
  echo "  Arguments: ${SCRIPT_ARGS[*]}"
fi
echo ""

# Export environment variables
for env_var in "${ENV_VARS[@]}"; do
  export "$env_var"
done

# Run the script with argument forwarding
EXIT_CODE=0
if [ ${#SCRIPT_ARGS[@]} -gt 0 ]; then
  npm run "$SCRIPT_NAME" -- "${SCRIPT_ARGS[@]}" || EXIT_CODE=$?
else
  npm run "$SCRIPT_NAME" || EXIT_CODE=$?
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "=== Script '$SCRIPT_NAME' completed successfully ==="
else
  echo "=== Script '$SCRIPT_NAME' failed with exit code $EXIT_CODE ==="
fi

exit $EXIT_CODE
