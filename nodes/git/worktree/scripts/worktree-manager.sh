#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?Usage: worktree-manager.sh <create|list|remove|cleanup> [args...]}"
shift

# Worktrees go in sibling directory by convention
REPO_ROOT=$(git rev-parse --show-toplevel)
PARENT=$(dirname "$REPO_ROOT")
REPO_NAME=$(basename "$REPO_ROOT")

case "$ACTION" in
  create)
    BRANCH="${1:?Branch name required}"
    BASE="${2:-HEAD}"
    WTPATH="$PARENT/${REPO_NAME}-wt-${BRANCH//\//-}"
    if [ -d "$WTPATH" ]; then
      echo "Worktree already exists at $WTPATH"
      exit 1
    fi
    # Check if branch exists
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
      git worktree add "$WTPATH" "$BRANCH"
    else
      echo "Creating new branch $BRANCH from $BASE"
      git worktree add -b "$BRANCH" "$WTPATH" "$BASE"
    fi
    echo "Worktree created at: $WTPATH"
    echo "cd $WTPATH"
    ;;
  list)
    git worktree list
    ;;
  remove)
    BRANCH="${1:?Branch name required}"
    WTPATH="$PARENT/${REPO_NAME}-wt-${BRANCH//\//-}"
    if [ ! -d "$WTPATH" ]; then
      echo "No worktree at $WTPATH"
      echo "Current worktrees:"
      git worktree list
      exit 1
    fi
    git worktree remove "$WTPATH"
    echo "Removed worktree: $WTPATH"
    ;;
  cleanup)
    echo "Pruning stale worktree references..."
    git worktree prune -v
    echo
    echo "Current worktrees:"
    git worktree list
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: worktree-manager.sh <create|list|remove|cleanup> [args...]"
    exit 1
    ;;
esac
