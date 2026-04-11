---
name: git-merge
description: Combine branches using merge, squash merge, or fast-forward, and resolve merge conflicts — use when integrating feature work into main or combining branches
---

# Git Merge

Integrate changes from one branch into another.

## When to Use

- Merging a feature branch into main
- Integrating upstream changes
- Resolving merge conflicts
- Squash-merging a PR branch

## Workflow

1. Switch to target branch: `git checkout main && git pull`
2. Merge the source: `git merge feature-branch`
3. If conflicts: resolve, `git add`, `git commit`
4. Verify: `git log --oneline --graph -5`
5. Delete source branch: `git branch -d feature-branch`

## Key Commands

```bash
# Fast-forward merge (default when possible)
git merge feature-branch

# Force merge commit (preserve branch history)
git merge --no-ff feature-branch

# Squash merge (flatten into one commit)
git merge --squash feature-branch
git commit -m "feat(auth): add OAuth2 support (#42)"

# Merge with custom message
git merge feature-branch -m "Merge feature-branch: add auth"

# Abort a conflicted merge
git merge --abort

# Check for conflicts without merging
git merge --no-commit --no-ff feature-branch
git merge --abort  # clean up after check
```

## Resolving Conflicts

1. `git status` — see conflicted files
2. Open each file, find `<<<<<<<` markers
3. Choose correct code, remove markers
4. `git add <resolved-file>`
5. `git commit` — completes the merge

```bash
# Accept incoming version for a file
git checkout --theirs src/auth.js

# Keep current version for a file
git checkout --ours src/auth.js

# Auto-resolve all conflicts favoring one side
git merge -X theirs feature-branch
```

## Safety Rules

1. **Always pull before merging** — ensures you have latest changes
2. **Don't blindly accept --ours or --theirs** — review each conflict
3. **Test after merging** — run the test suite
4. **Delete merged branches** — keep the branch list clean
5. **Use --no-ff for feature merges** — preserves topology in git log

## Edge Cases

- Squash merge doesn't create merge link — delete source branch after
- Merge commit with two parents — use `-m 1` when reverting
- Recursive merge strategy fails — try `git merge -s ort` (git 2.34+)
