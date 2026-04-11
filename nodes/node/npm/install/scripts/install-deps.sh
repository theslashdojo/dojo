#!/usr/bin/env bash
set -euo pipefail
# Install npm dependencies with optional flags and run an audit check
# Usage: install-deps.sh [--dev] [--exact] [--ci] [--audit] [packages...]
#
# Examples:
#   install-deps.sh                          # install all from package.json
#   install-deps.sh express body-parser      # add production deps
#   install-deps.sh --dev typescript eslint   # add dev deps
#   install-deps.sh --ci                     # clean install for CI
#   install-deps.sh --ci --audit             # clean install + audit

DEV_FLAG=""
EXACT_FLAG=""
CI_MODE=""
RUN_AUDIT=""
PACKAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev|-D)   DEV_FLAG="--save-dev"; shift ;;
    --exact|-E) EXACT_FLAG="--save-exact"; shift ;;
    --ci)       CI_MODE="true"; shift ;;
    --audit)    RUN_AUDIT="true"; shift ;;
    -*)         echo "Unknown flag: $1"; echo "Usage: install-deps.sh [--dev] [--exact] [--ci] [--audit] [packages...]"; exit 1 ;;
    *)          PACKAGES+=("$1"); shift ;;
  esac
done

# Verify package.json exists
if [ ! -f "package.json" ]; then
  echo "Error: No package.json found in current directory ($(pwd))"
  exit 1
fi

PACKAGE_NAME=$(node -e "console.log(require('./package.json').name || 'unnamed')")
echo "Project: $PACKAGE_NAME"
echo ""

# CI mode: strict clean install from lockfile
if [ "$CI_MODE" = "true" ]; then
  if [ ! -f "package-lock.json" ]; then
    echo "Error: npm ci requires package-lock.json to exist"
    exit 1
  fi
  echo "Running clean install (npm ci)..."
  npm ci
  INSTALLED_COUNT=$(npm ls --depth=0 --json 2>/dev/null | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const deps = data.dependencies || {};
    console.log(Object.keys(deps).length);
  " 2>/dev/null || echo "unknown")
  echo ""
  echo "Clean install complete. Top-level packages: $INSTALLED_COUNT"

  if [ "$RUN_AUDIT" = "true" ]; then
    echo ""
    echo "=== Security Audit ==="
    npm audit --omit=dev 2>&1 || true
  fi
  exit 0
fi

# Standard install
if [ ${#PACKAGES[@]} -eq 0 ]; then
  echo "Installing all dependencies from package.json..."
  npm install
else
  echo "Installing: ${PACKAGES[*]}"
  # Build the command with optional flags
  CMD="npm install"
  [ -n "$DEV_FLAG" ] && CMD="$CMD $DEV_FLAG"
  [ -n "$EXACT_FLAG" ] && CMD="$CMD $EXACT_FLAG"
  eval "$CMD ${PACKAGES[*]}"
fi

echo ""

# Show installed top-level packages
INSTALLED_COUNT=$(npm ls --depth=0 --json 2>/dev/null | node -e "
  const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const deps = data.dependencies || {};
  console.log(Object.keys(deps).length);
" 2>/dev/null || echo "unknown")

echo "=== Installed ($INSTALLED_COUNT top-level packages) ==="
npm ls --depth=0 2>/dev/null || true

# Run audit if requested
if [ "$RUN_AUDIT" = "true" ]; then
  echo ""
  echo "=== Security Audit ==="
  AUDIT_OUTPUT=$(npm audit --json 2>/dev/null || true)
  VULN_COUNT=$(echo "$AUDIT_OUTPUT" | node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const meta = data.metadata && data.metadata.vulnerabilities || {};
    const total = Object.values(meta).reduce((a, b) => a + b, 0);
    console.log(total);
  " 2>/dev/null || echo "unknown")
  echo "Vulnerabilities found: $VULN_COUNT"
  if [ "$VULN_COUNT" != "0" ] && [ "$VULN_COUNT" != "unknown" ]; then
    npm audit 2>&1 || true
  else
    echo "No known vulnerabilities."
  fi
fi
