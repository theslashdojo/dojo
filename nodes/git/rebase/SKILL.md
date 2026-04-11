---
name: git-rebase
description: Rewrite commit history by replaying onto a new base — use for interactive rebase, squashing WIP commits, and linearizing branch history
---

# Git Rebase

Rewrite history by replaying commits onto a new base.

## When to Use

- Updating a feature branch with latest main
- Squashing WIP commits before pushing
- Reordering or editing past commits
- Cleaning up messy history before code review

## Workflow

1. Ensure clean working tree: `git status`
2. Rebase onto target: `git rebase main`
3. Resolve any conflicts per commit
4. Verify: `git log --oneline -10`
5. Force push if previously pushed: `git push --force-with-lease`

## Key Commands

```bash
# Basic rebase onto main
git rebase main

# Interactive rebase (last N commits)
git rebase -i HEAD~5

# Interactive rebase onto main
git rebase -i main

# Rebase with autosquash (handles fixup! commits)
git rebase -i --autosquash main

# Rebase --onto (transplant commits)
git rebase --onto release main feature

# Abort a conflicted rebase
git rebase --abort

# Continue after resolving conflicts
git add resolved-file.js
git rebase --continue

# Skip a problematic commit
git rebase --skip
```

## Interactive Rebase Commands

In the editor todo list:

| Command | Effect |
|---------|--------|
| `pick` / `p` | Keep commit as-is |
| `reword` / `r` | Edit the commit message |
| `edit` / `e` | Pause to amend the commit |
| `squash` / `s` | Meld into previous, combine messages |
| `fixup` / `f` | Meld into previous, discard message |
| `drop` / `d` | Remove commit |

## Autosquash Workflow

```bash
# During development, create fixup commits
git commit --fixup=abc1234

# Before pushing, autosquash
git rebase -i --autosquash main
```

## The Golden Rule

**Never rebase commits that have been pushed to a shared branch.**

Safe to rebase: local commits, personal feature branches.
Never rebase: main, develop, release branches, any shared branch.

## Safety Rules

1. **Check if branch is shared** before rebasing
2. **Use --force-with-lease** (not --force) when pushing after rebase
3. **Use --abort if confused** — always returns to pre-rebase state
4. **Reflog recovers bad rebases** — `git reflog` finds the pre-rebase HEAD
5. **Don't rebase merge commits** — use `--rebase-merges` if you must
