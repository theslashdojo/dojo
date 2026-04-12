#!/usr/bin/env bash
# Scaffold a new Dojo node from a type template.
# This is a convenience wrapper around the parent create-node.sh script
# that also handles batch scaffolding for ecosystem trees.
#
# Usage:
#   ./scaffold-node.sh <type> <uri>
#   ./scaffold-node.sh --batch <file>
#
# The --batch flag reads a file with one "type uri" pair per line and
# scaffolds all nodes in order (parents before children).

set -euo pipefail

DOJO_ROOT="${DOJO_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
CREATE_SCRIPT="$DOJO_ROOT/nodes/dojo/authoring/scripts/create-node.sh"

if [[ ! -f "$CREATE_SCRIPT" ]]; then
  echo "Error: create-node.sh not found at $CREATE_SCRIPT" >&2
  exit 1
fi

if [[ "${1:-}" == "--batch" ]]; then
  BATCH_FILE="${2:?Usage: scaffold-node.sh --batch <file>}"
  if [[ ! -f "$BATCH_FILE" ]]; then
    echo "Error: batch file not found: $BATCH_FILE" >&2
    exit 1
  fi

  COUNT=0
  while IFS=' ' read -r type uri; do
    # Skip comments and empty lines
    [[ -z "$type" || "$type" == "#"* ]] && continue

    echo "--- Scaffolding $type: $uri ---"
    bash "$CREATE_SCRIPT" "$type" "$uri" || {
      echo "Warning: failed to scaffold $uri, continuing..." >&2
    }
    COUNT=$((COUNT + 1))
  done < "$BATCH_FILE"

  echo ""
  echo "Scaffolded $COUNT nodes from $BATCH_FILE"
else
  TYPE="${1:?Usage: scaffold-node.sh <type> <uri>}"
  URI="${2:?Usage: scaffold-node.sh <type> <uri>}"
  bash "$CREATE_SCRIPT" "$TYPE" "$URI"
fi
