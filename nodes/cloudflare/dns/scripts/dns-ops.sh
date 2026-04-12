#!/usr/bin/env bash
set -euo pipefail

# Cloudflare DNS operations via REST API
# Required env: CLOUDFLARE_API_TOKEN, ZONE_ID
# Usage:
#   ./dns-ops.sh list [type]
#   ./dns-ops.sh create <type> <name> <content> [proxied]
#   ./dns-ops.sh update <record-id> <content>
#   ./dns-ops.sh delete <record-id>
#   ./dns-ops.sh find-zone <domain>

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

ACTION="${1:-help}"

case "$ACTION" in
  find-zone)
    DOMAIN="${2:?Usage: dns-ops.sh find-zone <domain>}"
    curl -s "$API_BASE/zones?name=$DOMAIN" \
      -H "$AUTH_HEADER" | jq '.result[] | {id, name, status}'
    ;;
  list)
    if [ -z "${ZONE_ID:-}" ]; then
      echo "Error: ZONE_ID is not set" >&2
      exit 1
    fi
    TYPE_FILTER="${2:-}"
    URL="$API_BASE/zones/$ZONE_ID/dns_records"
    if [ -n "$TYPE_FILTER" ]; then
      URL="$URL?type=$TYPE_FILTER"
    fi
    curl -s "$URL" -H "$AUTH_HEADER" | jq '.result[] | {id, type, name, content, proxied, ttl}'
    ;;
  create)
    if [ -z "${ZONE_ID:-}" ]; then
      echo "Error: ZONE_ID is not set" >&2
      exit 1
    fi
    TYPE="${2:?Usage: dns-ops.sh create <type> <name> <content> [proxied]}"
    NAME="${3:?Missing record name}"
    CONTENT="${4:?Missing record content}"
    PROXIED="${5:-false}"
    curl -s -X POST "$API_BASE/zones/$ZONE_ID/dns_records" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$TYPE\",\"name\":\"$NAME\",\"content\":\"$CONTENT\",\"ttl\":1,\"proxied\":$PROXIED}" \
      | jq '.result | {id, type, name, content, proxied}'
    ;;
  update)
    if [ -z "${ZONE_ID:-}" ]; then
      echo "Error: ZONE_ID is not set" >&2
      exit 1
    fi
    RECORD_ID="${2:?Usage: dns-ops.sh update <record-id> <content>}"
    CONTENT="${3:?Missing new content}"
    curl -s -X PATCH "$API_BASE/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      --data "{\"content\":\"$CONTENT\"}" \
      | jq '.result | {id, type, name, content}'
    ;;
  delete)
    if [ -z "${ZONE_ID:-}" ]; then
      echo "Error: ZONE_ID is not set" >&2
      exit 1
    fi
    RECORD_ID="${2:?Usage: dns-ops.sh delete <record-id>}"
    curl -s -X DELETE "$API_BASE/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "$AUTH_HEADER" | jq '.success'
    echo "Deleted: $RECORD_ID"
    ;;
  *)
    echo "Usage: dns-ops.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  find-zone <domain>                    Find zone ID for a domain"
    echo "  list [type]                           List DNS records (optional type filter)"
    echo "  create <type> <name> <content> [proxied] Create a DNS record"
    echo "  update <record-id> <content>          Update record content"
    echo "  delete <record-id>                    Delete a DNS record"
    echo ""
    echo "Environment:"
    echo "  CLOUDFLARE_API_TOKEN  API token (required)"
    echo "  ZONE_ID               Zone ID (required for list/create/update/delete)"
    exit 1
    ;;
esac
