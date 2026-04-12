#!/usr/bin/env bash
# Initialize a vite.config.ts (or .js) with defineConfig, framework plugin, and resolve.alias.
# Usage: FRAMEWORK=react USE_TYPESCRIPT=true PROJECT_DIR=./my-app ./init-config.sh
#
# Env:
#   FRAMEWORK     - react, vue, svelte, solid, or vanilla (default: vanilla)
#   USE_TYPESCRIPT - true or false (default: true)
#   PROJECT_DIR   - Target directory (default: current directory)

set -euo pipefail

FRAMEWORK="${FRAMEWORK:-vanilla}"
USE_TYPESCRIPT="${USE_TYPESCRIPT:-true}"
PROJECT_DIR="${PROJECT_DIR:-.}"

# Normalize framework name to lowercase
FRAMEWORK="$(echo "$FRAMEWORK" | tr '[:upper:]' '[:lower:]')"

# Validate framework
case "$FRAMEWORK" in
  react|vue|svelte|solid|vanilla) ;;
  *)
    echo "Error: Unsupported framework '$FRAMEWORK'. Choose: react, vue, svelte, solid, vanilla." >&2
    exit 1
    ;;
esac

# Determine file extension
if [ "$USE_TYPESCRIPT" = "true" ]; then
  CONFIG_FILE="vite.config.ts"
else
  CONFIG_FILE="vite.config.js"
fi

CONFIG_PATH="$PROJECT_DIR/$CONFIG_FILE"

# Check if config already exists
for existing in vite.config.ts vite.config.js vite.config.mts vite.config.mjs; do
  if [ -f "$PROJECT_DIR/$existing" ]; then
    echo "Error: $PROJECT_DIR/$existing already exists. Remove it first or edit manually." >&2
    exit 1
  fi
done

# Ensure project directory exists and has package.json
mkdir -p "$PROJECT_DIR"
if [ ! -f "$PROJECT_DIR/package.json" ]; then
  echo "No package.json found in $PROJECT_DIR — initializing one."
  (cd "$PROJECT_DIR" && npm init -y --silent)
fi

# Determine plugin package and import line
PLUGIN_PACKAGE=""
PLUGIN_IMPORT=""
PLUGIN_CALL=""

case "$FRAMEWORK" in
  react)
    PLUGIN_PACKAGE="@vitejs/plugin-react"
    PLUGIN_IMPORT="import react from '@vitejs/plugin-react';"
    PLUGIN_CALL="react()"
    ;;
  vue)
    PLUGIN_PACKAGE="@vitejs/plugin-vue"
    PLUGIN_IMPORT="import vue from '@vitejs/plugin-vue';"
    PLUGIN_CALL="vue()"
    ;;
  svelte)
    PLUGIN_PACKAGE="@sveltejs/vite-plugin-svelte"
    PLUGIN_IMPORT="import { svelte } from '@sveltejs/vite-plugin-svelte';"
    PLUGIN_CALL="svelte()"
    ;;
  solid)
    PLUGIN_PACKAGE="vite-plugin-solid"
    PLUGIN_IMPORT="import solid from 'vite-plugin-solid';"
    PLUGIN_CALL="solid()"
    ;;
  vanilla)
    # No plugin needed
    ;;
esac

# Install vite and the framework plugin
echo "Installing vite..."
INSTALL_PACKAGES="vite"
if [ -n "$PLUGIN_PACKAGE" ]; then
  INSTALL_PACKAGES="$INSTALL_PACKAGES $PLUGIN_PACKAGE"
  echo "Installing $PLUGIN_PACKAGE..."
fi
(cd "$PROJECT_DIR" && npm install --save-dev $INSTALL_PACKAGES)

# Generate the config file
if [ "$FRAMEWORK" = "vanilla" ]; then
  cat > "$CONFIG_PATH" <<'VANILLA_EOF'
import { defineConfig } from 'vite';
import path from 'node:path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
});
VANILLA_EOF
else
  # Build config with framework plugin
  cat > "$CONFIG_PATH" <<PLUGIN_EOF
import { defineConfig } from 'vite';
import path from 'node:path';
${PLUGIN_IMPORT}

export default defineConfig({
  plugins: [${PLUGIN_CALL}],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
});
PLUGIN_EOF
fi

# Create src directory if it does not exist
mkdir -p "$PROJECT_DIR/src"

echo ""
echo "Created $CONFIG_PATH"
echo "  Framework: $FRAMEWORK"
echo "  Language:  $([ "$USE_TYPESCRIPT" = "true" ] && echo "TypeScript" || echo "JavaScript")"
echo "  Alias:     @ -> ./src"
echo ""

# Remind about tsconfig paths if using TypeScript
if [ "$USE_TYPESCRIPT" = "true" ]; then
  echo "For TypeScript path resolution, add to tsconfig.json compilerOptions:"
  echo '  "baseUrl": ".",'
  echo '  "paths": { "@/*": ["src/*"] }'
  echo ""
  echo "Or install vite-tsconfig-paths to sync automatically:"
  echo "  npm i -D vite-tsconfig-paths"
fi
