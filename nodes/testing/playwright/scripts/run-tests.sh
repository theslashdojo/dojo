#!/usr/bin/env bash
set -euo pipefail

# Run Playwright end-to-end tests with automatic environment setup.
#
# Checks for @playwright/test, installs browsers if missing, and forwards
# arguments to the Playwright test runner.
#
# Usage:
#   ./run-tests.sh                                  # run all tests
#   ./run-tests.sh tests/login.spec.ts              # run specific file
#   ./run-tests.sh --ui                             # interactive UI mode
#   ./run-tests.sh --headed                         # visible browser
#   ./run-tests.sh --project=chromium               # single browser
#   ./run-tests.sh --grep "checkout"                # filter by name
#   ./run-tests.sh --update-snapshots               # update visual references
#   ./run-tests.sh tests/login.spec.ts --headed --project=firefox
#
# Environment variables:
#   CI                          Detected automatically; forces headless, skips UI mode
#   PLAYWRIGHT_BROWSERS_PATH    Custom directory for browser binaries
#   PWDEBUG=1                   Enable step-by-step debugging with inspector
#   PLAYWRIGHT_RETRIES          Override retry count (default: 0 local, 2 in CI)
#   PLAYWRIGHT_WORKERS          Override worker count (default: auto local, 1 in CI)
#
# Requires: Node.js 18+, npm

# --- Color helpers (disabled in CI or non-interactive shells) ---
if [[ -t 1 ]] && [[ -z "${CI:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { echo -e "${BLUE}[playwright]${NC} $*"; }
warn()  { echo -e "${YELLOW}[playwright]${NC} $*"; }
error() { echo -e "${RED}[playwright]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[playwright]${NC} $*"; }

# --- Preflight: Node.js ---
if ! command -v node &>/dev/null; then
  error "Node.js is not installed. Install Node.js 18+ and retry."
  exit 1
fi

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if (( NODE_MAJOR < 18 )); then
  error "Node.js 18+ is required (found v${NODE_MAJOR}). Upgrade and retry."
  exit 1
fi

# --- Preflight: @playwright/test package ---
if ! node -e "require.resolve('@playwright/test')" 2>/dev/null; then
  error "@playwright/test is not installed in this project."
  echo ""
  echo "  To install:  npm install -D @playwright/test"
  echo "  Or scaffold:  npm init playwright@latest"
  echo ""
  exit 1
fi

PLAYWRIGHT_VERSION=$(node -e "console.log(require('@playwright/test/package.json').version)")
info "Found @playwright/test v${PLAYWRIGHT_VERSION}"

# --- Install browsers if missing ---
# playwright install --check is not a real command in all versions, so we
# check for the chromium executable directly via the registry.
BROWSERS_INSTALLED=true
if ! npx playwright install --dry-run &>/dev/null 2>&1; then
  BROWSERS_INSTALLED=false
fi

# Fallback: try to launch a quick check
if ! node -e "
  const pw = require('playwright');
  (async () => {
    try { const b = await pw.chromium.launch(); await b.close(); }
    catch { process.exit(1); }
  })();
" 2>/dev/null; then
  BROWSERS_INSTALLED=false
fi

if [[ "$BROWSERS_INSTALLED" == "false" ]]; then
  warn "Playwright browsers not found. Installing..."
  npx playwright install --with-deps
  ok "Browsers installed successfully."
else
  info "Browsers already installed."
fi

# --- Build argument list ---
ARGS=()

# Detect CI mode
if [[ -n "${CI:-}" ]]; then
  info "CI environment detected — running headless."

  # Strip --ui flag if someone accidentally passed it in CI
  for arg in "$@"; do
    if [[ "$arg" == "--ui" ]]; then
      warn "Ignoring --ui flag in CI environment."
    else
      ARGS+=("$arg")
    fi
  done

  # Apply CI defaults unless explicitly overridden
  HAS_RETRIES=false
  HAS_WORKERS=false
  for arg in "${ARGS[@]:-}"; do
    [[ "$arg" == --retries* ]] && HAS_RETRIES=true
    [[ "$arg" == --workers* ]] && HAS_WORKERS=true
  done

  RETRIES="${PLAYWRIGHT_RETRIES:-2}"
  WORKERS="${PLAYWRIGHT_WORKERS:-1}"

  if [[ "$HAS_RETRIES" == "false" ]]; then
    ARGS+=("--retries=${RETRIES}")
  fi
  if [[ "$HAS_WORKERS" == "false" ]]; then
    ARGS+=("--workers=${WORKERS}")
  fi
else
  # Local mode — pass all arguments through
  ARGS=("$@")

  # Apply env overrides if set
  if [[ -n "${PLAYWRIGHT_RETRIES:-}" ]]; then
    ARGS+=("--retries=${PLAYWRIGHT_RETRIES}")
  fi
  if [[ -n "${PLAYWRIGHT_WORKERS:-}" ]]; then
    ARGS+=("--workers=${PLAYWRIGHT_WORKERS}")
  fi
fi

# --- Run tests ---
info "Running: npx playwright test ${ARGS[*]:-}"
echo ""

exec npx playwright test "${ARGS[@]:-}"
