#!/usr/bin/env bash
set -euo pipefail

# Cloudflare R2 operations via Wrangler CLI
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
# Usage:
#   ./r2-ops.sh create-bucket <name>
#   ./r2-ops.sh upload <bucket/key> <local-file>
#   ./r2-ops.sh download <bucket/key> <local-file>
#   ./r2-ops.sh delete <bucket/key>
#   ./r2-ops.sh list <bucket> [prefix]
#   ./r2-ops.sh buckets

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

ACTION="${1:-help}"

case "$ACTION" in
  create-bucket)
    BUCKET="${2:?Usage: r2-ops.sh create-bucket <name>}"
    wrangler r2 bucket create "$BUCKET"
    ;;
  upload)
    BUCKET_KEY="${2:?Usage: r2-ops.sh upload <bucket/key> <local-file>}"
    LOCAL_FILE="${3:?Missing local file path}"
    if [ ! -f "$LOCAL_FILE" ]; then
      echo "Error: File not found: $LOCAL_FILE" >&2
      exit 1
    fi
    wrangler r2 object put "$BUCKET_KEY" --file "$LOCAL_FILE"
    echo "Uploaded: $LOCAL_FILE -> $BUCKET_KEY"
    ;;
  download)
    BUCKET_KEY="${2:?Usage: r2-ops.sh download <bucket/key> <local-file>}"
    LOCAL_FILE="${3:?Missing local file path}"
    wrangler r2 object get "$BUCKET_KEY" --file "$LOCAL_FILE"
    echo "Downloaded: $BUCKET_KEY -> $LOCAL_FILE"
    ;;
  delete)
    BUCKET_KEY="${2:?Usage: r2-ops.sh delete <bucket/key>}"
    wrangler r2 object delete "$BUCKET_KEY"
    echo "Deleted: $BUCKET_KEY"
    ;;
  list)
    BUCKET="${2:?Usage: r2-ops.sh list <bucket> [prefix]}"
    PREFIX="${3:-}"
    if [ -n "$PREFIX" ]; then
      wrangler r2 object list "$BUCKET" --prefix "$PREFIX"
    else
      wrangler r2 object list "$BUCKET"
    fi
    ;;
  buckets)
    wrangler r2 bucket list
    ;;
  *)
    echo "Usage: r2-ops.sh <create-bucket|upload|download|delete|list|buckets> [args...]"
    echo ""
    echo "Commands:"
    echo "  create-bucket <name>              Create an R2 bucket"
    echo "  upload <bucket/key> <local-file>  Upload a file to R2"
    echo "  download <bucket/key> <local-file> Download a file from R2"
    echo "  delete <bucket/key>               Delete an object"
    echo "  list <bucket> [prefix]            List objects (optional prefix)"
    echo "  buckets                           List all buckets"
    exit 1
    ;;
esac
