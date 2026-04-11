---
name: git-branch
description: Create, switch, rename, delete, and list git branches — use when managing parallel development workflows or feature branches
---

# Git Branch

Manage branches for parallel development.

## When to Use

- Creating a feature or fix branch
- Switching between branches
- Cleaning up merged branches
- Listing and inspecting branch state

## Workflow

1. Ensure you're on the latest main: `git checkout main && git pull`
2. Create and switch: `git switch -c feature/my-feature`
3. Do your work, commit
4. Push with tracking: `git push -u origin feature/my-feature`
5. After merge, delete: `git branch -d feature/my-feature`

## Key Commands

```bash
# Create and switch to new branch
git switch -c feature/add-auth
git checkout -b feature/add-auth  # older syntax

# Create from a specific base
git switch -c hotfix/login-bug origin/main

# Switch branches
git switch main
git switch -  # previous branch

# List branches
git branch          # local
git branch -a       # all (local + remote)
git branch -vv      # with tracking info
git branch --merged # merged into current

# Rename
git branch -m old-name new-name

# Delete
git branch -d merged-branch     # safe (refuses if unmerged)
git branch -D abandoned-branch  # force

# Delete remote branch
git push origin --delete feature/done

# Prune stale remote refs
git fetch --prune
```

## Naming Conventions

- `feature/<name>` — new functionality
- `fix/<name>` — bug fixes
- `hotfix/<name>` — urgent production fixes
- `chore/<name>` — maintenance, deps, tooling
- `release/<version>` — release preparation

## Safety Rules

1. **Always branch from latest main** — `git switch -c feature main` after pulling
2. **Use `-d` not `-D`** — safe delete catches unmerged work
3. **Never delete main/master**
4. **Clean up after merge** — delete feature branches promptly
5. **Stash or commit before switching** — dirty switches can fail or carry changes
