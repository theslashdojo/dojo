#!/usr/bin/env bash
set -euo pipefail

# Initialize ESLint flat config for a project
# Detects TypeScript, React, Node.js and creates appropriate eslint.config.mjs
#
# Usage: ./init-config.sh [project_dir]
# Environment:
#   PROJECT_DIR - project directory (default: current directory)

PROJECT_DIR="${1:-${PROJECT_DIR:-.}}"
cd "$PROJECT_DIR"

echo "==> Detecting project type in $(pwd)..."

HAS_TS=false
HAS_REACT=false
HAS_NEXT=false
HAS_PRETTIER=false
IS_MODULE=false

# Detect TypeScript
if [ -f "tsconfig.json" ] || [ -f "tsconfig.base.json" ]; then
  HAS_TS=true
  echo "    Found TypeScript"
fi

# Detect React/Next.js from package.json
if [ -f "package.json" ]; then
  if grep -q '"react"' package.json 2>/dev/null; then
    HAS_REACT=true
    echo "    Found React"
  fi
  if grep -q '"next"' package.json 2>/dev/null; then
    HAS_NEXT=true
    echo "    Found Next.js"
  fi
  if grep -q '"type":\s*"module"' package.json 2>/dev/null; then
    IS_MODULE=true
  fi
fi

# Detect Prettier
if [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f ".prettierrc.js" ] || [ -f "prettier.config.js" ]; then
  HAS_PRETTIER=true
  echo "    Found Prettier"
fi

# Check for existing ESLint config
if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.cjs" ]; then
  echo "==> ESLint flat config already exists. Aborting."
  echo "    To reconfigure, remove the existing config first."
  exit 0
fi

# Check for legacy config
if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f ".eslintrc.yaml" ] || [ -f ".eslintrc.cjs" ]; then
  echo "==> Legacy ESLint config found. Consider migrating:"
  echo "    npx @eslint/migrate-config .eslintrc.json"
  echo "    Proceeding with new flat config creation..."
fi

# Build package list
PACKAGES="eslint @eslint/js"

if [ "$HAS_TS" = true ]; then
  PACKAGES="$PACKAGES typescript-eslint"
fi

if [ "$HAS_REACT" = true ]; then
  PACKAGES="$PACKAGES eslint-plugin-react eslint-plugin-react-hooks"
fi

if [ "$HAS_PRETTIER" = true ]; then
  PACKAGES="$PACKAGES eslint-config-prettier"
fi

PACKAGES="$PACKAGES globals"

echo "==> Installing packages: $PACKAGES"
npm install --save-dev $PACKAGES

# Generate config file
CONFIG_FILE="eslint.config.mjs"
echo "==> Creating $CONFIG_FILE..."

if [ "$HAS_TS" = true ] && [ "$HAS_REACT" = true ]; then
  cat > "$CONFIG_FILE" << 'ESLINT_CONFIG'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "build/", "node_modules/", "coverage/", ".next/"],
  },
  {
    files: ["src/**/*.{ts,tsx}"],
    plugins: {
      react,
      "react-hooks": reactHooks,
    },
    languageOptions: {
      globals: { ...globals.browser },
      parserOptions: {
        ecmaFeatures: { jsx: true },
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react/react-in-jsx-scope": "off",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
    settings: {
      react: { version: "detect" },
    },
  },
);
ESLINT_CONFIG

elif [ "$HAS_TS" = true ]; then
  cat > "$CONFIG_FILE" << 'ESLINT_CONFIG'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import globals from "globals";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ["dist/", "build/", "node_modules/", "coverage/"],
  },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      globals: { ...globals.node },
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
  },
);
ESLINT_CONFIG

elif [ "$HAS_REACT" = true ]; then
  cat > "$CONFIG_FILE" << 'ESLINT_CONFIG'
import js from "@eslint/js";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";

export default [
  js.configs.recommended,
  {
    ignores: ["dist/", "build/", "node_modules/", "coverage/"],
  },
  {
    files: ["src/**/*.{js,jsx}"],
    plugins: {
      react,
      "react-hooks": reactHooks,
    },
    languageOptions: {
      globals: { ...globals.browser },
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react/react-in-jsx-scope": "off",
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
    settings: {
      react: { version: "detect" },
    },
  },
];
ESLINT_CONFIG

else
  cat > "$CONFIG_FILE" << 'ESLINT_CONFIG'
import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  {
    ignores: ["dist/", "build/", "node_modules/", "coverage/"],
  },
  {
    files: ["src/**/*.{js,mjs,cjs}"],
    languageOptions: {
      globals: { ...globals.node },
      sourceType: "module",
    },
    rules: {
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "prefer-const": "error",
      eqeqeq: ["error", "always"],
    },
  },
];
ESLINT_CONFIG
fi

# Append prettier config if detected
if [ "$HAS_PRETTIER" = true ]; then
  echo ""
  echo "==> Note: eslint-config-prettier installed."
  echo "    Add 'import prettier from \"eslint-config-prettier\";' and add 'prettier' as the last item in your config array."
fi

echo ""
echo "==> ESLint config created: $CONFIG_FILE"
echo "==> Run 'npx eslint .' to lint your project"
echo "==> Run 'npx eslint --fix .' to auto-fix issues"
