#!/usr/bin/env bash
# Create a new Dojo node with proper directory structure and skeleton node.json.
# Usage: ./create-node.sh <type> <uri> [--context "description"]
#
# Arguments:
#   type    - ecosystem, standard, skill, context, or sub
#   uri     - Full URI path (e.g., github/actions/workflows)
#   --context - Optional one-line context for the node
#
# Creates:
#   nodes/<uri>/node.json           - skeleton manifest
#   nodes/<uri>/SKILL.md            - Agent Skills file (skill/sub only)
#   nodes/<uri>/scripts/            - scripts directory (skill/sub only)

set -euo pipefail

TYPE="${1:?Usage: create-node.sh <type> <uri> [--context \"description\"]}"
URI="${2:?Usage: create-node.sh <type> <uri> [--context \"description\"]}"
shift 2

CONTEXT="TODO: one-line description under 200 chars"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) CONTEXT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate type
case "$TYPE" in
  ecosystem|standard|skill|context|sub) ;;
  *) echo "Error: type must be ecosystem, standard, skill, context, or sub" >&2; exit 1 ;;
esac

# Derive name and parent from URI
NAME=$(basename "$URI")
if [[ "$URI" == */* ]]; then
  PARENT=$(dirname "$URI" | tr '/' '/')
else
  PARENT="null"
fi

# Validate name format
if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
  echo "Error: name must be lowercase alphanumeric with optional hyphens" >&2
  exit 1
fi

DOJO_ROOT="${DOJO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
NODE_DIR="$DOJO_ROOT/nodes/$URI"
TODAY=$(date -u +%Y-%m-%dT00:00:00Z)
TODAY_SHORT=$(date -u +%Y-%m-%d)

# Check if node already exists
if [[ -f "$NODE_DIR/node.json" ]]; then
  echo "Error: node already exists at $NODE_DIR/node.json" >&2
  exit 1
fi

# Create directory
mkdir -p "$NODE_DIR"

# Build the parent field
if [[ "$PARENT" == "null" ]]; then
  PARENT_JSON="null"
else
  PARENT_JSON="\"$PARENT\""
fi

# Generate node.json based on type
if [[ "$TYPE" == "skill" || "$TYPE" == "sub" ]]; then
  cat > "$NODE_DIR/node.json" <<NODEJSON
{
  "name": "$NAME",
  "version": "1.0.0",
  "uri": "$URI",
  "type": "$TYPE",
  "context": "$CONTEXT",
  "info": "TODO: dense paragraph with scope, execution surface, and why it matters",
  "parent": $PARENT_JSON,
  "tags": ["$NAME"],
  "aliases": [],
  "triggers": [],
  "body": "",
  "sections": [],
  "links": [],
  "related": [],
  "scripts": [
    {
      "id": "$NAME-script",
      "name": "TODO: Script Name",
      "description": "TODO: what this script does",
      "lang": "bash",
      "runtime": "bash>=4",
      "entry": "./scripts/TODO.sh",
      "env": {},
      "packages": []
    }
  ],
  "schema": {
    "input": { "type": "object", "properties": {}, "required": [] },
    "output": { "type": "object", "properties": {} }
  },
  "depends": [],
  "author": "dojo-community",
  "license": "MIT",
  "created": "$TODAY",
  "updated": "$TODAY",
  "status": "draft"
}
NODEJSON

  # Create SKILL.md
  cat > "$NODE_DIR/SKILL.md" <<SKILLMD
---
name: $NAME
description: >
  TODO: What this skill does and when to use it.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# $(echo "$NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

TODO: Describe the skill, when to use it, and the workflow.
SKILLMD

  # Create scripts directory
  mkdir -p "$NODE_DIR/scripts"
  echo "Created skill node: $NODE_DIR"
  echo "  - node.json (skeleton)"
  echo "  - SKILL.md (skeleton)"
  echo "  - scripts/ (empty)"

elif [[ "$TYPE" == "context" ]]; then
  cat > "$NODE_DIR/node.json" <<NODEJSON
{
  "name": "$NAME",
  "version": "1.0.0",
  "uri": "$URI",
  "type": "context",
  "content_type": "guide",
  "context": "$CONTEXT",
  "info": "TODO: dense paragraph with scope and why this reference matters",
  "parent": $PARENT_JSON,
  "tags": ["$NAME"],
  "aliases": [],
  "triggers": [],
  "body": "",
  "sections": [],
  "links": [],
  "related": [],
  "frontmatter": {
    "created": "$TODAY_SHORT",
    "updated": "$TODAY_SHORT",
    "author": "dojo-community",
    "audience": "TODO",
    "estimated_reading_time": "TODO min",
    "status": "living",
    "confidence": "high"
  },
  "author": "dojo-community",
  "license": "MIT",
  "created": "$TODAY",
  "updated": "$TODAY",
  "status": "draft"
}
NODEJSON

  echo "Created context node: $NODE_DIR"
  echo "  - node.json (skeleton)"

else
  # ecosystem or standard
  cat > "$NODE_DIR/node.json" <<NODEJSON
{
  "name": "$NAME",
  "version": "1.0.0",
  "uri": "$URI",
  "type": "$TYPE",
  "context": "$CONTEXT",
  "info": "TODO: dense paragraph with scope, execution surface, and why it matters",
  "parent": $PARENT_JSON,
  "tags": ["$NAME"],
  "aliases": [],
  "triggers": [],
  "body": "",
  "sections": [],
  "links": [],
  "related": [],
  "more": {
    "docs": "TODO: official docs URL",
    "repo": "TODO: source repo URL"
  },
  "frontmatter": {
    "created": "$TODAY_SHORT",
    "updated": "$TODAY_SHORT",
    "author": "dojo-community",
    "audience": "TODO",
    "status": "living",
    "confidence": "high"
  },
  "author": "dojo-community",
  "license": "MIT",
  "created": "$TODAY",
  "updated": "$TODAY",
  "status": "draft"
}
NODEJSON

  echo "Created $TYPE node: $NODE_DIR"
  echo "  - node.json (skeleton)"
fi

echo ""
echo "Next steps:"
echo "  1. Fill in TODO placeholders in node.json"
echo "  2. Add aliases, triggers, body, sections, links, related"
if [[ "$TYPE" == "skill" || "$TYPE" == "sub" ]]; then
  echo "  3. Write real scripts in scripts/"
  echo "  4. Update schema with actual input/output"
fi
echo "  Run: dojo validate $NODE_DIR/node.json"
