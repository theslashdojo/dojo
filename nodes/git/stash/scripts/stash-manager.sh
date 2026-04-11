#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?Usage: stash-manager.sh <save|pop|list|show|drop> [args...]}"
shift

case "$ACTION" in
  save)
    MSG="${1:-WIP: $(date +%Y-%m-%d_%H:%M)}"
    if git diff --quiet && git diff --cached --quiet; then
      echo "Nothing to stash — working tree is clean."
      exit 0
    fi
    git stash push -u -m "$MSG"
    echo "Stashed: $MSG"
    ;;
  pop)
    COUNT=$(git stash list | wc -l)
    if [ "$COUNT" -eq 0 ]; then
      echo "Stash is empty — nothing to pop."
      exit 0
    fi
    REF="${1:-stash@{0}}"
    echo "Popping $REF:"
    git stash show "$REF" --stat
    echo
    git stash pop "$REF"
    ;;
  list)
    COUNT=$(git stash list | wc -l)
    if [ "$COUNT" -eq 0 ]; then
      echo "Stash is empty."
    else
      echo "$COUNT stash entries:"
      git stash list
    fi
    ;;
  show)
    REF="${1:-stash@{0}}"
    git stash show -p "$REF"
    ;;
  drop)
    REF="${1:-stash@{0}}"
    echo "Dropping $REF:"
    git stash show "$REF" --stat
    git stash drop "$REF"
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: stash-manager.sh <save|pop|list|show|drop> [args...]"
    exit 1
    ;;
esac
