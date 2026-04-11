#!/usr/bin/env bash
set -euo pipefail
# Publish an npm package with pre-flight safety checks
# Usage: publish-package.sh [--dry-run] [--access public|restricted] [--tag latest|next|beta] [--provenance]
#
# Examples:
#   publish-package.sh                          # publish with defaults
#   publish-package.sh --dry-run                # preview without publishing
#   publish-package.sh --access public --tag beta
#   publish-package.sh --provenance             # with supply chain attestation (CI only)

DRY_RUN=""
ACCESS="public"
TAG="latest"
PROVENANCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN="--dry-run"; shift ;;
    --access)      ACCESS="${2:?--access requires a value (public or restricted)}"; shift 2 ;;
    --tag)         TAG="${2:?--tag requires a value (e.g., latest, beta, next)}"; shift 2 ;;
    --provenance)  PROVENANCE="--provenance"; shift ;;
    *)             echo "Unknown option: $1"; echo "Usage: publish-package.sh [--dry-run] [--access public|restricted] [--tag latest|beta|next] [--provenance]"; exit 1 ;;
  esac
done

# Pre-flight: package.json must exist
if [ ! -f "package.json" ]; then
  echo "Error: No package.json found in current directory"
  exit 1
fi

PACKAGE_NAME=$(node -e "console.log(require('./package.json').name)")
PACKAGE_VERSION=$(node -e "console.log(require('./package.json').version)")
IS_PRIVATE=$(node -e "console.log(require('./package.json').private === true)")

# Guard against publishing private packages
if [ "$IS_PRIVATE" = "true" ]; then
  echo "Error: package.json has \"private\": true — refusing to publish"
  exit 1
fi

echo "=== Pre-flight Checks ==="
echo "  Package: $PACKAGE_NAME"
echo "  Version: $PACKAGE_VERSION"
echo "  Access:  $ACCESS"
echo "  Tag:     $TAG"
echo ""

# Check if user is logged in
if ! npm whoami >/dev/null 2>&1; then
  echo "Error: Not logged in to npm. Run 'npm login' first."
  exit 1
fi
LOGGED_IN_AS=$(npm whoami)
echo "  Logged in as: $LOGGED_IN_AS"
echo ""

# Check if this version already exists on the registry
if npm view "${PACKAGE_NAME}@${PACKAGE_VERSION}" version >/dev/null 2>&1; then
  echo "Error: ${PACKAGE_NAME}@${PACKAGE_VERSION} already exists on the registry."
  echo "Bump the version with 'npm version patch|minor|major' and try again."
  exit 1
fi
echo "  Version ${PACKAGE_VERSION} is available (not yet published)"
echo ""

# Run prepublishOnly if defined
HAS_PREPUBLISH=$(node -e "
  const s = require('./package.json').scripts || {};
  console.log(s.prepublishOnly ? 'yes' : 'no');
")
if [ "$HAS_PREPUBLISH" = "yes" ]; then
  echo "=== Running prepublishOnly ==="
  npm run prepublishOnly
  echo ""
fi

# Show what would be published
echo "=== Files to be published ==="
npm pack --dry-run 2>&1
echo ""

# Calculate tarball size
TARBALL_SIZE=$(npm pack --dry-run --json 2>/dev/null | node -e "
  const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  if (Array.isArray(data) && data[0]) {
    const bytes = data[0].size || 0;
    const kb = (bytes / 1024).toFixed(1);
    console.log(kb + ' KB');
  } else {
    console.log('unknown');
  }
" 2>/dev/null || echo "unknown")
echo "  Tarball size: $TARBALL_SIZE"
echo ""

# Build publish command
CMD="npm publish --access $ACCESS --tag $TAG"
[ -n "$DRY_RUN" ] && CMD="$CMD $DRY_RUN"
[ -n "$PROVENANCE" ] && CMD="$CMD $PROVENANCE"

echo "=== Publishing ==="
echo "  Command: $CMD"
echo ""

eval "$CMD"

if [ -z "$DRY_RUN" ]; then
  echo ""
  echo "Successfully published ${PACKAGE_NAME}@${PACKAGE_VERSION} with tag '${TAG}'"
  echo "  Registry: https://www.npmjs.com/package/${PACKAGE_NAME}"
else
  echo ""
  echo "Dry run complete for ${PACKAGE_NAME}@${PACKAGE_VERSION} — no changes made"
fi
