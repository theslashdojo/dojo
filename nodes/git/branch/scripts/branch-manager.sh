#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?Usage: branch-manager.sh <create|list|delete|cleanup> [args...]}"
shift

case "$ACTION" in
  create)
    NAME="${1:?Branch name required}"
    BASE="${2:-HEAD}"
    git switch -c "$NAME" "$BASE"
    echo "Created and switched to branch: $NAME (from $BASE)"
    git log --oneline -1
    ;;
  list)
    echo "=== Local branches ==="
    git branch -vv
    echo
    echo "=== Remote branches ==="
    git branch -r
    ;;
  delete)
    NAME="${1:?Branch name required}"
    CURRENT=$(git branch --show-current)
    if [ "$NAME" = "$CURRENT" ]; then
      echo "Error: Cannot delete the current branch. Switch first."
      exit 1
    fi
    if [ "$NAME" = "main" ] || [ "$NAME" = "master" ]; then
      echo "Error: Refusing to delete $NAME"
      exit 1
    fi
    git branch -d "$NAME"
    echo "Deleted branch: $NAME"
    ;;
  cleanup)
    echo "Branches merged into $(git branch --show-current):"
    git branch --merged | grep -v '\*\|main\|master' || echo "(none)"
    echo
    echo "Run 'git branch -d <name>' to delete merged branches."
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: branch-manager.sh <create|list|delete|cleanup> [args...]"
    exit 1
    ;;
esac
