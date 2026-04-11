---
name: git-diff
description: Compare changes between working tree, staging area, commits, and branches — use when reviewing code changes before committing or comparing branches
---

# Git Diff

Show exact line-by-line changes between any two states in git.

## When to Use

- Reviewing changes before committing
- Comparing what's staged vs unstaged
- Comparing two branches or commits
- Generating patch files
- Verifying merge or rebase results

## The Three Comparisons

```
Working Tree  ↔  Index (Staging)  ↔  HEAD (Last Commit)
    git diff      git diff --staged
    └──────── git diff HEAD ─────────┘
```

## Key Commands

```bash
# Unstaged changes (working tree vs index)
git diff

# Staged changes (what will be committed)
git diff --staged

# All uncommitted changes (vs HEAD)
git diff HEAD

# Between two commits
git diff abc1234 def5678

# Between two branches
git diff main feature-branch

# What a branch added since diverging
git diff main...feature-branch

# Last commit diff
git show HEAD

# Specific file only
git diff -- src/auth.js
git diff HEAD -- src/auth.js

# Exclude paths
git diff -- . ':!node_modules/' ':!vendor/'

# Stat summary
git diff --stat

# File names only
git diff --name-only

# Names with status (A/M/D)
git diff --name-status

# Word-level diff
git diff --word-diff

# Check for whitespace errors and conflict markers
git diff --check

# Generate patch
git diff > changes.patch
git apply changes.patch
```

## Reading Diff Output

```diff
--- a/src/auth.js     (old version)
+++ b/src/auth.js     (new version)
@@ -10,4 +10,6 @@   (line numbers)
 context line
-removed line
+added line
+added line
 context line
```

## Safety Rules

1. **Always `git diff --staged` before committing** — verify what you're committing
2. **Use `--stat` first for large diffs** — get the overview before details
3. **Use triple-dot for branch comparison** — `main...feature` not `main..feature`
4. **Run `git diff --check` before committing** — catches conflict markers and whitespace issues
