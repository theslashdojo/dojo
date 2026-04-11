#!/usr/bin/env bash
set -euo pipefail

SOURCE="${1:?Usage: safe-merge.sh <source-branch> [--squash] [--no-ff] [--dry-run]}"
shift

SQUASH=""
NOFF=""
DRYRUN=false

for arg in "$@"; do
  case "$arg" in
    --squash) SQUASH="--squash" ;;
    --no-ff) NOFF="--no-ff" ;;
    --dry-run) DRYRUN=true ;;
  esac
done

CURRENT=$(git branch --show-current)
echo "Merging $SOURCE into $CURRENT"

# Check if source branch exists
if ! git rev-parse --verify "$SOURCE" >/dev/null 2>&1; then
  echo "Error: Branch '$SOURCE' does not exist"
  exit 1
fi

# Dry run — check for conflicts without merging
if $DRYRUN; then
  echo "=== Dry run: checking for conflicts ==="
  if git merge --no-commit --no-ff "$SOURCE" >/dev/null 2>&1; then
    echo "No conflicts detected. Merge would succeed."
    git merge --abort 2>/dev/null || true
  else
    echo "Conflicts detected in:"
    git diff --name-only --diff-filter=U
    git merge --abort
  fi
  exit 0
fi

# Perform the merge
git merge $SQUASH $NOFF "$SOURCE"

if [ -n "$SQUASH" ]; then
  echo "Squash merge staged. Review and commit:"
  git diff --cached --stat
else
  echo "Merge complete:"
  git log --oneline --graph -5
fi
