#!/usr/bin/env bash
set -euo pipefail

# Cloudflare KV operations via Wrangler CLI
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
# Usage:
#   ./kv-ops.sh create <namespace-name>
#   ./kv-ops.sh put <namespace-id> <key> <value>
#   ./kv-ops.sh get <namespace-id> <key>
#   ./kv-ops.sh delete <namespace-id> <key>
#   ./kv-ops.sh list <namespace-id> [prefix]
#   ./kv-ops.sh namespaces

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "Error: CLOUDFLARE_ACCOUNT_ID is not set" >&2
  exit 1
fi

ACTION="${1:-help}"

case "$ACTION" in
  create)
    NAMESPACE_NAME="${2:?Usage: kv-ops.sh create <namespace-name>}"
    wrangler kv namespace create "$NAMESPACE_NAME"
    ;;
  put)
    NS_ID="${2:?Usage: kv-ops.sh put <namespace-id> <key> <value>}"
    KEY="${3:?Missing key}"
    VALUE="${4:?Missing value}"
    wrangler kv key put --namespace-id "$NS_ID" "$KEY" "$VALUE"
    echo "Written: $KEY"
    ;;
  get)
    NS_ID="${2:?Usage: kv-ops.sh get <namespace-id> <key>}"
    KEY="${3:?Missing key}"
    wrangler kv key get --namespace-id "$NS_ID" "$KEY"
    ;;
  delete)
    NS_ID="${2:?Usage: kv-ops.sh delete <namespace-id> <key>}"
    KEY="${3:?Missing key}"
    wrangler kv key delete --namespace-id "$NS_ID" "$KEY"
    echo "Deleted: $KEY"
    ;;
  list)
    NS_ID="${2:?Usage: kv-ops.sh list <namespace-id> [prefix]}"
    PREFIX="${3:-}"
    if [ -n "$PREFIX" ]; then
      wrangler kv key list --namespace-id "$NS_ID" --prefix "$PREFIX"
    else
      wrangler kv key list --namespace-id "$NS_ID"
    fi
    ;;
  namespaces)
    wrangler kv namespace list
    ;;
  *)
    echo "Usage: kv-ops.sh <create|put|get|delete|list|namespaces> [args...]"
    echo ""
    echo "Commands:"
    echo "  create <name>              Create a KV namespace"
    echo "  put <ns-id> <key> <value>  Write a key-value pair"
    echo "  get <ns-id> <key>          Read a value"
    echo "  delete <ns-id> <key>       Delete a key"
    echo "  list <ns-id> [prefix]      List keys (optional prefix filter)"
    echo "  namespaces                 List all namespaces"
    exit 1
    ;;
esac
