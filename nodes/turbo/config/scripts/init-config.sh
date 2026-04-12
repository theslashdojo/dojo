#!/usr/bin/env bash
set -euo pipefail

# Initialize or update turbo.json for a monorepo
# Usage: ./init-config.sh [--remote-cache] [--env-mode strict|loose]

REMOTE_CACHE=false
ENV_MODE="${TURBO_ENV_MODE:-strict}"
CONCURRENCY="${TURBO_CONCURRENCY:-10}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote-cache) REMOTE_CACHE=true; shift ;;
    --env-mode) ENV_MODE="$2"; shift 2 ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Detect package manager
detect_package_manager() {
  if [[ -f "pnpm-workspace.yaml" ]] || [[ -f "pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "yarn.lock" ]]; then
    echo "yarn"
  elif [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    echo "bun"
  elif [[ -f "package-lock.json" ]]; then
    echo "npm"
  else
    echo "npm"
  fi
}

# Check if turbo is installed
check_turbo_installed() {
  if ! command -v turbo &>/dev/null; then
    local pm
    pm=$(detect_package_manager)
    echo "turbo not found. Installing..."
    case "$pm" in
      pnpm) pnpm add turbo --save-dev --workspace-root ;;
      yarn) yarn add turbo --dev ;;
      bun) bun add turbo --dev ;;
      npm) npm install turbo --save-dev ;;
    esac
  fi
}

# Detect workspace output patterns by scanning for common frameworks
detect_outputs() {
  local outputs='["dist/**"]'
  if [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "next.config.ts" ]]; then
    outputs='[".next/**", "!.next/cache/**"]'
  fi
  echo "$outputs"
}

CONFIG_FILE="turbo.json"

if [[ -f "$CONFIG_FILE" ]]; then
  echo "turbo.json already exists at $(pwd)/$CONFIG_FILE"
  echo "To update, edit the file directly or delete and re-run this script."
  exit 0
fi

PM=$(detect_package_manager)
echo "Detected package manager: $PM"

check_turbo_installed

# Build remote cache section
REMOTE_CACHE_JSON=""
if [[ "$REMOTE_CACHE" == "true" ]]; then
  REMOTE_CACHE_JSON=',
  "remoteCache": {
    "enabled": true,
    "signature": false,
    "preflight": false,
    "timeout": 30,
    "uploadTimeout": 60
  }'
fi

# Generate turbo.json
cat > "$CONFIG_FILE" <<TURBO_JSON
{
  "\$schema": "https://turborepo.dev/schema.json",
  "globalDependencies": [".env"],
  "globalEnv": ["NODE_ENV", "CI"],
  "envMode": "${ENV_MODE}",
  "concurrency": ${CONCURRENCY},
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "persistent": true,
      "cache": false
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    }
  }${REMOTE_CACHE_JSON}
}
TURBO_JSON

echo "Created $CONFIG_FILE with envMode=$ENV_MODE, concurrency=$CONCURRENCY"

if [[ "$REMOTE_CACHE" == "true" ]]; then
  echo "Remote cache enabled. Set TURBO_TOKEN and TURBO_TEAM environment variables."
  if [[ -n "${TURBO_TOKEN:-}" ]] && [[ -n "${TURBO_TEAM:-}" ]]; then
    echo "TURBO_TOKEN and TURBO_TEAM are set."
  else
    echo "Run 'npx turbo login && npx turbo link' to authenticate with Vercel."
  fi
fi

echo "Done. Run 'turbo build' to verify configuration."
