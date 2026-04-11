#!/usr/bin/env bash
set -euo pipefail

# Usage: commit-staged.sh <type> <scope> <message> [files...]
# Example: commit-staged.sh feat auth "add JWT validation" src/auth.js test/auth.test.js

TYPE="${1:?Usage: commit-staged.sh <type> <scope> <message> [files...]}"
SCOPE="${2:?Missing scope}"
MSG="${3:?Missing message}"
shift 3

if [ $# -eq 0 ]; then
  echo "Error: No files specified. Stage files explicitly."
  exit 1
fi

# Stage specified files
for f in "$@"; do
  if [ ! -e "$f" ]; then
    echo "Warning: $f does not exist, skipping"
    continue
  fi
  git add "$f"
done

# Verify something is staged
if git diff --cached --quiet; then
  echo "Nothing staged to commit."
  exit 1
fi

# Show what will be committed
echo "=== Staged changes ==="
git diff --cached --stat
echo

# Commit
if [ -n "$SCOPE" ] && [ "$SCOPE" != "-" ]; then
  git commit -m "${TYPE}(${SCOPE}): ${MSG}"
else
  git commit -m "${TYPE}: ${MSG}"
fi

echo
git log --oneline -1
