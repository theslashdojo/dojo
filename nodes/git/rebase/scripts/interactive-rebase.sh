#!/usr/bin/env bash
set -euo pipefail

BASE="${1:?Usage: interactive-rebase.sh <base> [--autosquash]}"
AUTOSQUASH=""

if [ "${2:-}" = "--autosquash" ]; then
  AUTOSQUASH="--autosquash"
fi

# Show what will be rebased
COMMIT_COUNT=$(git rev-list --count "$BASE"..HEAD)
echo "Rebasing $COMMIT_COUNT commits onto $BASE"
echo
git log --oneline "$BASE"..HEAD
echo

if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "Nothing to rebase — HEAD is already on or behind $BASE"
  exit 0
fi

# Check for fixup commits
FIXUPS=$(git log --oneline "$BASE"..HEAD | grep -c '^[a-f0-9]* fixup!' || true)
if [ "$FIXUPS" -gt 0 ] && [ -z "$AUTOSQUASH" ]; then
  echo "Found $FIXUPS fixup commit(s). Consider using --autosquash."
fi

git rebase -i $AUTOSQUASH "$BASE"
