#!/usr/bin/env bash
# Search the Dojo registry for nodes matching a query.
# Usage: ./search-nodes.sh <query> [--tag TAG] [--type TYPE] [--limit N]
#
# Operates in two modes:
#   Online: queries DOJO_URL if set and reachable
#   Local:  greps node.json files under DOJO_ROOT/nodes/

set -euo pipefail

QUERY="${1:?Usage: search-nodes.sh <query> [--tag TAG] [--type TYPE] [--limit N]}"
shift

TAG=""
TYPE=""
LIMIT="10"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)  TAG="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DOJO_URL="${DOJO_URL:-}"
DOJO_ROOT="${DOJO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"

# --- Online mode: query the server ---
if [[ -n "$DOJO_URL" ]]; then
  PARAMS="q=$(printf '%s' "$QUERY" | jq -sRr @uri)&limit=$LIMIT"
  [[ -n "$TAG" ]] && PARAMS="$PARAMS&tags=$TAG"
  [[ -n "$TYPE" ]] && PARAMS="$PARAMS&type=$TYPE"

  RESPONSE=$(curl -sf "$DOJO_URL/v1/search?$PARAMS" 2>/dev/null) || {
    echo "Server at $DOJO_URL not reachable, falling back to local mode" >&2
    DOJO_URL=""
  }

  if [[ -n "$DOJO_URL" ]]; then
    echo "$RESPONSE" | jq -r '.results[] | "\(.score | tostring | .[0:4])  \(.type | .[0:5])  \(.uri)\n       \(.context)"'
    TOTAL=$(echo "$RESPONSE" | jq -r '.total')
    echo ""
    echo "Found $TOTAL result(s) for \"$QUERY\""
    exit 0
  fi
fi

# --- Local mode: search node.json files on disk ---
NODES_DIR="$DOJO_ROOT/nodes"
if [[ ! -d "$NODES_DIR" ]]; then
  echo "Error: nodes directory not found at $NODES_DIR" >&2
  echo "Set DOJO_ROOT to the dojo repository root" >&2
  exit 1
fi

QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Search across multiple fields and score by field weight
find "$NODES_DIR" -name "node.json" -print0 | while IFS= read -r -d '' file; do
  # Read the node manifest
  NODE=$(cat "$file")

  # Apply type filter
  if [[ -n "$TYPE" ]]; then
    NODE_TYPE=$(echo "$NODE" | jq -r '.type // empty')
    [[ "$NODE_TYPE" != "$TYPE" ]] && continue
  fi

  # Apply tag filter
  if [[ -n "$TAG" ]]; then
    HAS_TAG=$(echo "$NODE" | jq -r --arg tag "$TAG" '.tags // [] | map(select(. == $tag)) | length')
    [[ "$HAS_TAG" == "0" ]] && continue
  fi

  # Score by field weight
  SCORE=0
  URI=$(echo "$NODE" | jq -r '.uri // empty')
  NAME=$(echo "$NODE" | jq -r '.name // empty')
  CONTEXT=$(echo "$NODE" | jq -r '.context // empty')
  NODE_TYPE=$(echo "$NODE" | jq -r '.type // empty')

  # Check triggers (weight 1.0)
  TRIGGER_MATCH=$(echo "$NODE" | jq -r --arg q "$QUERY_LOWER" '
    .triggers // [] | map(ascii_downcase) | map(select(contains($q))) | length')
  [[ "$TRIGGER_MATCH" -gt 0 ]] && SCORE=100

  # Check aliases (weight 0.9)
  if [[ "$SCORE" -eq 0 ]]; then
    ALIAS_MATCH=$(echo "$NODE" | jq -r --arg q "$QUERY_LOWER" '
      .aliases // [] | map(ascii_downcase) | map(select(contains($q))) | length')
    [[ "$ALIAS_MATCH" -gt 0 ]] && SCORE=90
  fi

  # Check name (weight 0.85)
  if [[ "$SCORE" -eq 0 ]]; then
    NAME_LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
    [[ "$NAME_LOWER" == *"$QUERY_LOWER"* ]] && SCORE=85
  fi

  # Check context (weight 0.8)
  if [[ "$SCORE" -eq 0 ]]; then
    CONTEXT_LOWER=$(echo "$CONTEXT" | tr '[:upper:]' '[:lower:]')
    [[ "$CONTEXT_LOWER" == *"$QUERY_LOWER"* ]] && SCORE=80
  fi

  # Check tags (weight 0.7)
  if [[ "$SCORE" -eq 0 ]]; then
    TAG_MATCH=$(echo "$NODE" | jq -r --arg q "$QUERY_LOWER" '
      .tags // [] | map(select(contains($q))) | length')
    [[ "$TAG_MATCH" -gt 0 ]] && SCORE=70
  fi

  # Check info (weight 0.5)
  if [[ "$SCORE" -eq 0 ]]; then
    INFO_LOWER=$(echo "$NODE" | jq -r '.info // empty' | tr '[:upper:]' '[:lower:]')
    [[ "$INFO_LOWER" == *"$QUERY_LOWER"* ]] && SCORE=50
  fi

  if [[ "$SCORE" -gt 0 ]]; then
    printf '%03d\t%s\t%s\t%s\n' "$SCORE" "$NODE_TYPE" "$URI" "$CONTEXT"
  fi
done | sort -rn | head -n "$LIMIT" | while IFS=$'\t' read -r score type uri context; do
  DISPLAY_SCORE=$(echo "scale=2; $score / 100" | bc)
  printf '%s  %-8s %s\n       %s\n' "$DISPLAY_SCORE" "$type" "$uri" "$context"
done

echo ""
echo "Local search for \"$QUERY\" complete"
