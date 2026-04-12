#!/usr/bin/env bash
# Dojo CLI command dispatcher.
# Usage: ./dojo-commands.sh <command> [args...]
#
# Commands:
#   search <query> [--tag TAG] [--type TYPE] [--limit N]
#   inspect <uri> [--field FIELD] [--json]
#   validate <path> [--schema-only] [--knowledge-only]
#   scaffold <type> <uri>
#   learn <uri>[#section]
#
# Environment variables:
#   DOJO_URL  - Server URL for online mode (optional)
#   DOJO_ROOT - Path to dojo repository root (auto-detected)

set -euo pipefail

DOJO_ROOT="${DOJO_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
COMMAND="${1:?Usage: dojo-commands.sh <search|inspect|validate|scaffold|learn> [args...]}"
shift

case "$COMMAND" in

  search)
    QUERY="${1:?Usage: dojo search <query> [--tag TAG] [--type TYPE] [--limit N]}"
    shift
    bash "$DOJO_ROOT/nodes/dojo/search/scripts/search-nodes.sh" "$QUERY" "$@"
    ;;

  inspect)
    URI="${1:?Usage: dojo inspect <uri> [--field FIELD] [--json]}"
    shift
    FIELD=""
    JSON_OUT=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --field) FIELD="$2"; shift 2 ;;
        --json) JSON_OUT=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done

    NODE_FILE="$DOJO_ROOT/nodes/$URI/node.json"
    if [[ ! -f "$NODE_FILE" ]]; then
      echo "Error: node not found at $URI" >&2
      exit 1
    fi

    if [[ -n "$FIELD" ]]; then
      jq -r ".$FIELD" "$NODE_FILE"
    elif [[ "$JSON_OUT" == true ]]; then
      cat "$NODE_FILE"
    else
      # Pretty-print key fields
      jq -r '"URI:     \(.uri)\nType:    \(.type)\nVersion: \(.version)\nStatus:  \(.status // "unknown")\n\nContext: \(.context)\n\nInfo:    \(.info)\n\nTags:    \(.tags | join(", "))\nAliases: \(.aliases // [] | join(", "))"' "$NODE_FILE"
    fi
    ;;

  validate)
    TARGET="${1:?Usage: dojo validate <path> [--schema-only] [--knowledge-only]}"
    shift
    VALIDATE_SCRIPT="$DOJO_ROOT/nodes/dojo/validate/scripts/validate-node.js"
    if [[ -f "$VALIDATE_SCRIPT" ]]; then
      node "$VALIDATE_SCRIPT" "$TARGET" "$@"
    else
      # Fallback: basic JSON validation
      if [[ -d "$TARGET" ]]; then
        ERRORS=0
        find "$TARGET" -name "node.json" | while read -r f; do
          if ! jq empty "$f" 2>/dev/null; then
            echo "INVALID JSON: $f"
            ERRORS=$((ERRORS + 1))
          else
            NAME=$(jq -r '.name // "?"' "$f")
            URI=$(jq -r '.uri // "?"' "$f")
            TYPE=$(jq -r '.type // "?"' "$f")
            echo "OK: $URI ($TYPE) - $NAME"
          fi
        done
        [[ $ERRORS -gt 0 ]] && exit 1
      else
        if jq empty "$TARGET" 2>/dev/null; then
          echo "Valid JSON: $TARGET"
          jq -r '"  URI:  \(.uri)\n  Type: \(.type)\n  Name: \(.name)"' "$TARGET"
        else
          echo "INVALID JSON: $TARGET" >&2
          exit 1
        fi
      fi
    fi
    ;;

  scaffold)
    TYPE="${1:?Usage: dojo scaffold <type> <uri>}"
    URI="${2:?Usage: dojo scaffold <type> <uri>}"
    bash "$DOJO_ROOT/nodes/dojo/authoring/scripts/create-node.sh" "$TYPE" "$URI"
    ;;

  learn)
    URI_WITH_SECTION="${1:?Usage: dojo learn <uri>[#section]}"

    # Split URI and section
    URI="${URI_WITH_SECTION%%#*}"
    SECTION=""
    if [[ "$URI_WITH_SECTION" == *"#"* ]]; then
      SECTION="${URI_WITH_SECTION#*#}"
    fi

    NODE_FILE="$DOJO_ROOT/nodes/$URI/node.json"
    if [[ ! -f "$NODE_FILE" ]]; then
      echo "Error: node not found at $URI" >&2
      exit 1
    fi

    if [[ -n "$SECTION" ]]; then
      # Show specific section
      jq -r --arg sid "$SECTION" '
        .sections // [] | map(select(.id == $sid)) | .[0] //
        {title: "Section not found", body: "No section with id: \($sid)"} |
        "## \(.title)\n\n\(.body)"
      ' "$NODE_FILE"
    else
      # Show context + body + sections
      echo ""
      jq -r '"# \(.name) (\(.type))\n\n> \(.context)\n"' "$NODE_FILE"
      BODY=$(jq -r '.body // ""' "$NODE_FILE")
      if [[ -n "$BODY" ]]; then
        echo "$BODY"
        echo ""
      fi
      jq -r '.sections // [] | .[] | "## \(.title)\n\n\(.body)\n"' "$NODE_FILE"
    fi
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Available: search, inspect, validate, scaffold, learn" >&2
    exit 1
    ;;
esac
