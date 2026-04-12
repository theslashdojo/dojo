#!/usr/bin/env bash
set -euo pipefail

# Deploy to Firebase Hosting
# Supports production deploy, preview channels, deploy targets, and rollback.
#
# Usage:
#   ./deploy-hosting.sh [options]
#
# Options:
#   --project PROJECT_ID    Firebase project ID
#   --site SITE_NAME        Hosting site name (for multi-site projects)
#   --channel CHANNEL_ID    Deploy to a preview channel instead of production
#   --only hosting          Restrict deploy to hosting (default behavior)
#   --target TARGET_NAME    Deploy target for multi-site hosting
#   --public-dir DIR        Public directory (creates/updates firebase.json)
#   --expires DURATION      Channel expiration (e.g., 1h, 3d, 7d). Only with --channel
#   --rollback              Roll back to the previous release
#   --message MSG           Deploy message tag
#
# Examples:
#   ./deploy-hosting.sh --project my-app
#   ./deploy-hosting.sh --project my-app --channel staging --expires 3d
#   ./deploy-hosting.sh --project my-app --target blog
#   ./deploy-hosting.sh --project my-app --rollback
#   ./deploy-hosting.sh --project my-app --public-dir dist

PROJECT=""
SITE=""
CHANNEL=""
TARGET=""
PUBLIC_DIR=""
EXPIRES=""
ROLLBACK=false
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --site)
      SITE="$2"
      shift 2
      ;;
    --channel)
      CHANNEL="$2"
      shift 2
      ;;
    --only)
      # Accepted for compatibility but hosting is always the target
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --public-dir)
      PUBLIC_DIR="$2"
      shift 2
      ;;
    --expires)
      EXPIRES="$2"
      shift 2
      ;;
    --rollback)
      ROLLBACK=true
      shift
      ;;
    --message|-m)
      MESSAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: ./deploy-hosting.sh --project PROJECT_ID [--channel CHANNEL] [--target TARGET] [--public-dir DIR] [--rollback]" >&2
      exit 1
      ;;
  esac
done

# ── Check firebase-tools is installed ──────────────────────────────────────────

if ! command -v firebase &>/dev/null; then
  echo "Error: firebase-tools is not installed." >&2
  echo "Install with: npm install -g firebase-tools" >&2
  echo "Or run: npx firebase-tools" >&2
  exit 1
fi

echo "Using firebase-tools $(firebase --version)"

# ── Ensure firebase.json exists ────────────────────────────────────────────────

if [ ! -f "firebase.json" ]; then
  echo "Warning: firebase.json not found in current directory."
  if [ -n "$PUBLIC_DIR" ]; then
    echo "Creating firebase.json with public directory: $PUBLIC_DIR"
    cat > firebase.json <<FIREBASE_JSON
{
  "hosting": {
    "public": "$PUBLIC_DIR",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "trailingSlash": false,
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
FIREBASE_JSON
    echo "Created firebase.json"
  else
    echo "Error: firebase.json not found. Run 'firebase init hosting' or pass --public-dir." >&2
    exit 1
  fi
elif [ -n "$PUBLIC_DIR" ]; then
  echo "Note: firebase.json exists. Ignoring --public-dir (edit firebase.json directly to change the public directory)."
fi

# ── Build project flags ────────────────────────────────────────────────────────

PROJECT_FLAG=""
if [ -n "$PROJECT" ]; then
  PROJECT_FLAG="--project $PROJECT"
fi

# ── Handle rollback ───────────────────────────────────────────────────────────

if [ "$ROLLBACK" = true ]; then
  echo "Rolling back to previous release..."
  ROLLBACK_CMD="firebase hosting:rollback $PROJECT_FLAG"
  if [ -n "$SITE" ]; then
    ROLLBACK_CMD="$ROLLBACK_CMD --site $SITE"
  fi
  echo "Running: $ROLLBACK_CMD"
  eval "$ROLLBACK_CMD"
  echo "Rollback complete."
  exit 0
fi

# ── Handle preview channel deploy ─────────────────────────────────────────────

if [ -n "$CHANNEL" ]; then
  echo "Deploying to preview channel: $CHANNEL"
  CHANNEL_CMD="firebase hosting:channel:deploy $CHANNEL $PROJECT_FLAG"
  if [ -n "$EXPIRES" ]; then
    CHANNEL_CMD="$CHANNEL_CMD --expires $EXPIRES"
  fi
  if [ -n "$SITE" ]; then
    CHANNEL_CMD="$CHANNEL_CMD --site $SITE"
  fi
  echo "Running: $CHANNEL_CMD"
  eval "$CHANNEL_CMD"
  echo ""
  echo "Preview channel '$CHANNEL' deployed."
  if [ -n "$PROJECT" ]; then
    echo "Channel URL: https://${PROJECT}--${CHANNEL}-*.web.app"
  fi
  exit 0
fi

# ── Handle production deploy ──────────────────────────────────────────────────

echo "Deploying to production..."

DEPLOY_CMD="firebase deploy --only hosting"

if [ -n "$TARGET" ]; then
  DEPLOY_CMD="firebase deploy --only hosting:$TARGET"
fi

DEPLOY_CMD="$DEPLOY_CMD $PROJECT_FLAG"

if [ -n "$MESSAGE" ]; then
  DEPLOY_CMD="$DEPLOY_CMD -m \"$MESSAGE\""
fi

echo "Running: $DEPLOY_CMD"
eval "$DEPLOY_CMD"

echo ""
echo "Deployment complete."
if [ -n "$PROJECT" ]; then
  echo "Hosting URL: https://${PROJECT}.web.app"
  if [ -n "$SITE" ]; then
    echo "Site URL: https://${SITE}.web.app"
  fi
fi
