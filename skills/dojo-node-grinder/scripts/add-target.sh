#!/usr/bin/env bash
# add-target.sh — Add a new ecosystem target to grind-targets.json
#
# Usage:
#   ./add-target.sh --ecosystem "newapi" --priority 2 --reason "Why agents need this" \
#     --nodes "newapi:ecosystem newapi/auth:context newapi/query:skill"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS_FILE="$SCRIPT_DIR/../../scripts/grind-targets.json"

ECOSYSTEM=""
PRIORITY=2
REASON=""
NODES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ecosystem) ECOSYSTEM="$2"; shift 2 ;;
    --priority)  PRIORITY="$2"; shift 2 ;;
    --reason)    REASON="$2"; shift 2 ;;
    --nodes)     NODES="$2"; shift 2 ;;
    *)           echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ECOSYSTEM" ]] || [[ -z "$REASON" ]] || [[ -z "$NODES" ]]; then
  echo "Usage: add-target.sh --ecosystem NAME --reason 'why' --nodes 'uri:type uri:type ...'"
  exit 1
fi

# Check if ecosystem already exists
if jq -e --arg e "$ECOSYSTEM" '.targets[] | select(.ecosystem == $e)' "$TARGETS_FILE" >/dev/null 2>&1; then
  echo "ERROR: Ecosystem '$ECOSYSTEM' already exists in targets."
  exit 1
fi

# Build the tree array from space-separated "uri:type" pairs
tree_json="["
first=true
for pair in $NODES; do
  uri="${pair%%:*}"
  type="${pair##*:}"
  if [[ "$first" == true ]]; then
    first=false
  else
    tree_json+=","
  fi
  tree_json+="{ \"uri\": \"$uri\", \"type\": \"$type\" }"
done
tree_json+="]"

# Add the new target using jq
tmp=$(mktemp)
jq --arg eco "$ECOSYSTEM" \
   --argjson pri "$PRIORITY" \
   --arg reason "$REASON" \
   --argjson tree "$tree_json" \
   '.targets += [{ ecosystem: $eco, priority: $pri, reason: $reason, tree: $tree }]' \
   "$TARGETS_FILE" > "$tmp"
mv "$tmp" "$TARGETS_FILE"

echo "Added '$ECOSYSTEM' (priority $PRIORITY) with $(echo "$NODES" | wc -w | tr -d ' ') nodes."
echo "Run: ./scripts/dojo-grind.sh --ecosystem $ECOSYSTEM"
