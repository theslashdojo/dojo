#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?Usage: history-search.sh <recent|file|search|author|graph> [args...]}"
shift

case "$MODE" in
  recent)
    N="${1:-10}"
    git log --oneline -"$N"
    ;;
  file)
    FILE="${1:?File path required}"
    echo "History for $FILE:"
    git log --oneline --follow -- "$FILE"
    ;;
  search)
    TERM="${1:?Search term required}"
    echo "Commits matching: $TERM"
    git log --oneline --grep="$TERM"
    ;;
  author)
    AUTHOR="${1:?Author name/email required}"
    echo "Commits by $AUTHOR:"
    git log --oneline --author="$AUTHOR"
    ;;
  graph)
    git log --oneline --graph --all --decorate -20
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: history-search.sh <recent|file|search|author|graph> [args...]"
    exit 1
    ;;
esac
