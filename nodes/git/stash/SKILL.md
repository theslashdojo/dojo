---
name: git-stash
description: Temporarily shelve uncommitted changes and restore them later — use when you need to switch context without committing
---

# Git Stash

Save uncommitted work temporarily without creating a commit.

## When to Use

- Switching branches with uncommitted changes
- Pulling remote changes onto a dirty tree
- Setting aside work-in-progress temporarily
- Testing something on a clean working tree

## Workflow

1. Save work: `git stash push -u -m "WIP: description"`
2. Do other work (switch branches, pull, etc.)
3. Return and restore: `git stash pop`

## Key Commands

```bash
# Stash all changes (tracked files)
git stash

# Stash with message (always do this)
git stash push -m "WIP: auth refactoring"

# Include untracked files
git stash -u

# Include everything (untracked + ignored)
git stash -a

# Stash only specific files
git stash push -m "stash auth" src/auth.js

# Stash only staged changes
git stash push --staged

# List stashes
git stash list

# Show stash contents
git stash show -p          # latest
git stash show -p stash@{2}  # specific

# Apply and remove from stack
git stash pop

# Apply and keep in stack
git stash apply

# Apply specific stash
git stash pop stash@{2}

# Drop a stash
git stash drop stash@{0}

# Clear all stashes
git stash clear

# Create branch from stash (avoids conflicts)
git stash branch new-branch
```

## Safety Rules

1. **Always use `-m` message** — naked stashes are impossible to identify later
2. **Use `-u` to include untracked** — new files are silently left behind otherwise
3. **Prefer commits for long-lived work** — stashes are easy to forget
4. **Don't stash clear without listing first**
5. **On conflict, pop doesn't drop** — resolve then manually `git stash drop`

## Edge Cases

- Stash conflicts: use `git stash branch <name>` to apply on original commit
- Lost stash: `git fsck --no-reflog | grep commit` may find it
- Stash across branches: `git stash apply` works on any branch
