#!/usr/bin/env bash
set -euo pipefail

REMOTE="${1:-origin}"
BRANCH=$(git branch --show-current)

echo "Syncing $BRANCH with $REMOTE/$BRANCH"

# Fetch latest
git fetch "$REMOTE"

# Check if remote branch exists
if ! git rev-parse --verify "$REMOTE/$BRANCH" >/dev/null 2>&1; then
  echo "Remote branch $REMOTE/$BRANCH does not exist."
  echo "Push with: git push -u $REMOTE $BRANCH"
  exit 0
fi

# Count ahead/behind
LOCAL=$(git rev-parse HEAD)
REMOTE_HEAD=$(git rev-parse "$REMOTE/$BRANCH")
BASE=$(git merge-base HEAD "$REMOTE/$BRANCH")

if [ "$LOCAL" = "$REMOTE_HEAD" ]; then
  echo "Already up to date."
elif [ "$LOCAL" = "$BASE" ]; then
  BEHIND=$(git rev-list --count HEAD.."$REMOTE/$BRANCH")
  echo "Behind by $BEHIND commit(s). Pulling..."
  git pull --rebase "$REMOTE" "$BRANCH"
elif [ "$REMOTE_HEAD" = "$BASE" ]; then
  AHEAD=$(git rev-list --count "$REMOTE/$BRANCH"..HEAD)
  echo "Ahead by $AHEAD commit(s). Pushing..."
  git push "$REMOTE" "$BRANCH"
else
  AHEAD=$(git rev-list --count "$REMOTE/$BRANCH"..HEAD)
  BEHIND=$(git rev-list --count HEAD.."$REMOTE/$BRANCH")
  echo "Diverged: $AHEAD ahead, $BEHIND behind."
  echo "Recommend: git pull --rebase $REMOTE $BRANCH && git push"
fi
