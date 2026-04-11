#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?Usage: smart-diff.sh <staged|unstaged|all|branch|commit> [args...]}"
shift

case "$MODE" in
  staged)
    echo "=== Staged changes (will be committed) ==="
    git diff --staged --stat
    echo
    git diff --staged
    ;;
  unstaged)
    echo "=== Unstaged changes ==="
    git diff --stat
    echo
    git diff
    ;;
  all)
    echo "=== All uncommitted changes ==="
    git diff HEAD --stat
    echo
    git diff HEAD
    ;;
  branch)
    TARGET="${1:?Target branch required (e.g. main)}"
    echo "=== Changes since diverging from $TARGET ==="
    git diff "$TARGET"...HEAD --stat
    echo
    git diff "$TARGET"...HEAD
    ;;
  commit)
    REF="${1:-HEAD}"
    echo "=== Changes in commit $REF ==="
    git show --stat "$REF"
    echo
    git show "$REF"
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: smart-diff.sh <staged|unstaged|all|branch|commit> [args...]"
    exit 1
    ;;
esac
