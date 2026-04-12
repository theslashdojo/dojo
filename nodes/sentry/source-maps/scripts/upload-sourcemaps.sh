#!/usr/bin/env bash
# Upload source maps to Sentry with full release management
#
# Required env:
#   SENTRY_AUTH_TOKEN  — Sentry auth token (Release:Admin, Project:Read&Write)
#   SENTRY_ORG         — Sentry organization slug
#   SENTRY_PROJECT     — Sentry project slug
# Optional env:
#   BUILD_DIR          — Path to build output (default: ./dist)
#   SENTRY_RELEASE     — Release version (default: auto-detected from git)
#   SENTRY_ENVIRONMENT — Deployment environment for deploy tracking
#   DELETE_MAPS        — Delete .map files after upload (default: true)

set -euo pipefail

# Validate required env vars
: "${SENTRY_AUTH_TOKEN:?SENTRY_AUTH_TOKEN is required — create at sentry.io/settings/auth-tokens/}"
: "${SENTRY_ORG:?SENTRY_ORG is required — your organization slug}"
: "${SENTRY_PROJECT:?SENTRY_PROJECT is required — your project slug}"

BUILD_DIR="${BUILD_DIR:-./dist}"
DELETE_MAPS="${DELETE_MAPS:-true}"
ENVIRONMENT="${SENTRY_ENVIRONMENT:-}"

# Check sentry-cli is available
if ! command -v sentry-cli &> /dev/null; then
  echo "sentry-cli not found. Installing..."
  npm install -g @sentry/cli
fi

# Auto-detect release version from git if not provided
if [ -z "${SENTRY_RELEASE:-}" ]; then
  VERSION=$(sentry-cli releases propose-version)
  echo "Auto-detected release version: ${VERSION}"
else
  VERSION="$SENTRY_RELEASE"
  echo "Using provided release version: ${VERSION}"
fi

# Verify build directory exists and contains source maps
if [ ! -d "$BUILD_DIR" ]; then
  echo "ERROR: Build directory '${BUILD_DIR}' does not exist."
  echo "Run your build command first (e.g., npm run build)."
  exit 1
fi

MAP_COUNT=$(find "$BUILD_DIR" -name "*.map" -type f | wc -l)
if [ "$MAP_COUNT" -eq 0 ]; then
  echo "WARNING: No .map files found in ${BUILD_DIR}."
  echo "Ensure your build generates source maps (sourcemap: true)."
  echo "Continuing with Debug ID injection..."
fi

echo "=== Sentry Source Map Upload ==="
echo "Organization: ${SENTRY_ORG}"
echo "Project:      ${SENTRY_PROJECT}"
echo "Release:      ${VERSION}"
echo "Build dir:    ${BUILD_DIR}"
echo "Map files:    ${MAP_COUNT}"
echo ""

# Step 1: Create release
echo "--- Creating release ---"
sentry-cli releases new "$VERSION"

# Step 2: Associate commits (if in a git repo)
if git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
  echo "--- Associating commits ---"
  sentry-cli releases set-commits "$VERSION" --auto || \
    sentry-cli releases set-commits "$VERSION" --local || \
    echo "WARNING: Could not associate commits. Continuing..."
fi

# Step 3: Inject Debug IDs
echo "--- Injecting Debug IDs ---"
sentry-cli sourcemaps inject "$BUILD_DIR"

# Step 4: Upload source maps
echo "--- Uploading source maps ---"
sentry-cli sourcemaps upload \
  --release="$VERSION" \
  --validate \
  "$BUILD_DIR"

# Step 5: Finalize release
echo "--- Finalizing release ---"
sentry-cli releases finalize "$VERSION"

# Step 6: Record deploy (if environment is set)
if [ -n "$ENVIRONMENT" ]; then
  echo "--- Recording deploy to ${ENVIRONMENT} ---"
  sentry-cli deploys new --release "$VERSION" -e "$ENVIRONMENT"
fi

# Step 7: Delete source maps from build output (optional)
if [ "$DELETE_MAPS" = "true" ] && [ "$MAP_COUNT" -gt 0 ]; then
  echo "--- Deleting .map files from ${BUILD_DIR} ---"
  find "$BUILD_DIR" -name "*.map" -type f -delete
  echo "Deleted ${MAP_COUNT} source map files."
fi

echo ""
echo "=== Upload Complete ==="
echo "Release ${VERSION} is now live with source maps."
echo "Verify at: https://${SENTRY_ORG}.sentry.io/settings/projects/${SENTRY_PROJECT}/source-maps/"
