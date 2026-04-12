#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# add-plugin.sh — Install and configure a Vite framework plugin
#
# Environment / Arguments:
#   PLUGIN         (required) react | react-swc | vue | svelte | solid | legacy
#   USE_TYPESCRIPT (optional) true | false  (default: true)
#   PROJECT_DIR    (optional) target directory  (default: .)
###############################################################################

PLUGIN="${PLUGIN:?PLUGIN is required (react|react-swc|vue|svelte|solid|legacy)}"
USE_TYPESCRIPT="${USE_TYPESCRIPT:-true}"
PROJECT_DIR="${PROJECT_DIR:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Verify we are in a node project with vite
if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
  echo "ERROR: No package.json found in $PROJECT_DIR" >&2
  exit 1
fi

# Detect package manager
detect_pm() {
  if [[ -f "$PROJECT_DIR/bun.lockb" || -f "$PROJECT_DIR/bun.lock" ]]; then
    echo "bun"
  elif [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

PM="$(detect_pm)"

install_cmd() {
  case "$PM" in
    bun)  echo "bun add -D $*" ;;
    pnpm) echo "pnpm add -D $*" ;;
    yarn) echo "yarn add -D $*" ;;
    npm)  echo "npm install -D $*" ;;
  esac
}

# Map plugin name to npm package, import name, and config factory call
case "$PLUGIN" in
  react)
    PKG="@vitejs/plugin-react"
    IMPORT_NAME="react"
    FACTORY_CALL="react()"
    EXTRA_PKGS=""
    ;;
  react-swc)
    PKG="@vitejs/plugin-react-swc"
    IMPORT_NAME="react"
    FACTORY_CALL="react()"
    EXTRA_PKGS=""
    ;;
  vue)
    PKG="@vitejs/plugin-vue"
    IMPORT_NAME="vue"
    FACTORY_CALL="vue()"
    EXTRA_PKGS=""
    ;;
  svelte)
    PKG="@sveltejs/vite-plugin-svelte"
    IMPORT_NAME="{ svelte }"
    FACTORY_CALL="svelte()"
    EXTRA_PKGS="svelte"
    ;;
  solid)
    PKG="vite-plugin-solid"
    IMPORT_NAME="solid"
    FACTORY_CALL="solid()"
    EXTRA_PKGS="solid-js"
    ;;
  legacy)
    PKG="@vitejs/plugin-legacy"
    IMPORT_NAME="legacy"
    FACTORY_CALL="legacy({ targets: ['defaults', 'not IE 11'] })"
    EXTRA_PKGS="terser"
    ;;
  *)
    echo "ERROR: Unknown plugin '$PLUGIN'. Supported: react, react-swc, vue, svelte, solid, legacy" >&2
    exit 1
    ;;
esac

echo "==> Plugin:       $PLUGIN"
echo "==> Package:      $PKG"
echo "==> Directory:    $PROJECT_DIR"
echo "==> Pkg Manager:  $PM"
echo ""

# Install the plugin package (and extras if any)
ALL_PKGS="$PKG"
if [[ -n "$EXTRA_PKGS" ]]; then
  ALL_PKGS="$PKG $EXTRA_PKGS"
fi

INSTALL="$(install_cmd "$ALL_PKGS")"
echo "==> Installing: $INSTALL"
(cd "$PROJECT_DIR" && eval "$INSTALL")
echo ""
echo "==> Installed $PKG successfully."

# Determine config file extension
if [[ "$USE_TYPESCRIPT" == "true" ]]; then
  CONFIG_EXT="ts"
else
  CONFIG_EXT="js"
fi

# Print configuration instructions
echo ""
echo "================================================================"
echo " Next: Update your vite.config.$CONFIG_EXT"
echo "================================================================"
echo ""

if [[ "$USE_TYPESCRIPT" == "true" ]]; then
cat <<TSEOF
  import { defineConfig } from 'vite';
  import $IMPORT_NAME from '$PKG';

  export default defineConfig({
    plugins: [
      $FACTORY_CALL,
    ],
  });
TSEOF
else
cat <<JSEOF
  import { defineConfig } from 'vite';
  import $IMPORT_NAME from '$PKG';

  export default defineConfig({
    plugins: [
      $FACTORY_CALL,
    ],
  });
JSEOF
fi

echo ""
echo "==> Done. Run 'npx vite' to verify the plugin loads correctly."
