---
name: git-worktree
description: Work on multiple branches simultaneously using linked worktrees — use when you need parallel checkouts without stashing or context switching
---

# Git Worktree

Check out multiple branches at the same time in separate directories.

## When to Use

- Working on a hotfix while mid-feature
- Reviewing a PR without leaving your current work
- Running tests on one branch while developing on another
- Agent parallelism — spawn sub-agents in separate worktrees

## Workflow

1. Create worktree: `git worktree add ../hotfix hotfix-branch`
2. Work in the new directory: `cd ../hotfix`
3. Commit, push as normal
4. Remove when done: `git worktree remove ../hotfix`

## Key Commands

```bash
# Create worktree for existing branch
git worktree add ../review-dir review-branch

# Create worktree with new branch
git worktree add -b hotfix ../hotfix-dir main

# Detached HEAD worktree (for a tag)
git worktree add --detach ../release-check v2.0

# List all worktrees
git worktree list

# Remove a worktree
git worktree remove ../review-dir

# Force remove (dirty worktree)
git worktree remove --force ../abandoned-dir

# Clean up stale references
git worktree prune
```

## Common Patterns

### Hotfix While Developing
```bash
git worktree add -b hotfix/urgent ../hotfix main
cd ../hotfix
# fix, commit, push
cd ../project
git worktree remove ../hotfix
```

### Review a PR
```bash
git fetch origin
git worktree add ../review origin/pr-branch
cd ../review && npm test
cd ../project
git worktree remove ../review
```

## Constraints

- Each branch can only be in one worktree at a time
- Worktrees share the object database and refs
- No nested worktrees

## Safety Rules

1. **Place worktrees as siblings** — `../name` convention
2. **Remove when done** — don't leave lingering worktrees
3. **Prune regularly** — `git worktree prune` cleans up deleted dirs
4. **Name descriptively** — `../hotfix-login` not `../tmp`
