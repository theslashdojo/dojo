#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Install Playwright packages and browser binaries.

Usage:
  install-playwright.sh [test|library|agent-cli] [browsers...]

Modes:
  test       Install @playwright/test for end-to-end tests and fixtures.
  library    Install playwright for standalone browser automation scripts.
  agent-cli  Install @playwright/cli for token-efficient coding-agent control.

Environment:
  PLAYWRIGHT_PACKAGE_MANAGER   npm, pnpm, yarn, or bun. Auto-detected by lockfile.
  PLAYWRIGHT_WITH_DEPS         1 to pass --with-deps when installing browsers.
  PLAYWRIGHT_SKIP_PACKAGE      1 to skip package installation and only install browsers.
  PLAYWRIGHT_SKIP_BROWSERS     1 to skip browser binary installation.

Examples:
  nodes/playwright/scripts/install-playwright.sh test chromium firefox webkit
  PLAYWRIGHT_PACKAGE_MANAGER=pnpm nodes/playwright/scripts/install-playwright.sh library chromium
  nodes/playwright/scripts/install-playwright.sh agent-cli
USAGE
}

mode="${1:-test}"
if [[ "${mode}" == "-h" || "${mode}" == "--help" ]]; then
  usage
  exit 0
fi
shift || true

case "${mode}" in
  test) package="@playwright/test" ;;
  library) package="playwright" ;;
  agent-cli) package="@playwright/cli@latest" ;;
  *)
    echo "Unknown mode: ${mode}" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ ! -f package.json && "${mode}" != "agent-cli" ]]; then
  echo "No package.json found in $(pwd). Run this from a Node project root." >&2
  exit 1
fi

if [[ -n "${PLAYWRIGHT_PACKAGE_MANAGER:-}" ]]; then
  pm="${PLAYWRIGHT_PACKAGE_MANAGER}"
elif [[ -f pnpm-lock.yaml ]]; then
  pm="pnpm"
elif [[ -f yarn.lock ]]; then
  pm="yarn"
elif [[ -f bun.lockb || -f bun.lock ]]; then
  pm="bun"
else
  pm="npm"
fi

if [[ "${PLAYWRIGHT_SKIP_PACKAGE:-0}" != "1" ]]; then
  case "${pm}" in
    npm)
      if [[ "${mode}" == "agent-cli" ]]; then
        npm install -g "${package}"
      else
        npm install -D "${package}"
      fi
      ;;
    pnpm)
      if [[ "${mode}" == "agent-cli" ]]; then
        pnpm add -g "${package}"
      else
        pnpm add -D "${package}"
      fi
      ;;
    yarn)
      if [[ "${mode}" == "agent-cli" ]]; then
        npm install -g "${package}"
      else
        yarn add -D "${package}"
      fi
      ;;
    bun)
      if [[ "${mode}" == "agent-cli" ]]; then
        bun add -g "${package}"
      else
        bun add -d "${package}"
      fi
      ;;
    *)
      echo "Unsupported package manager: ${pm}" >&2
      exit 2
      ;;
  esac
fi

if [[ "${PLAYWRIGHT_SKIP_BROWSERS:-0}" == "1" || "${mode}" == "agent-cli" ]]; then
  exit 0
fi

browsers=("$@")
if (( ${#browsers[@]} == 0 )); then
  browsers=(chromium firefox webkit)
fi

install_args=(playwright install)
if [[ "${PLAYWRIGHT_WITH_DEPS:-1}" == "1" ]]; then
  install_args+=(--with-deps)
fi
install_args+=("${browsers[@]}")

case "${pm}" in
  npm|yarn|bun) npx "${install_args[@]}" ;;
  pnpm) pnpm exec "${install_args[@]}" ;;
esac
