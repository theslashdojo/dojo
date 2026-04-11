---
name: git-commit
description: Stage files and create git commits with conventional commit messages — use when committing code changes, crafting commit messages, or staging files selectively
---

# Git Commit

Stage changes and create commits with well-structured messages.

## When to Use

- After making code changes that need to be saved
- When you need to selectively stage files
- When crafting a commit message for a changeset
- When amending the last commit

## Workflow

1. Review changes: `git status` and `git diff`
2. Stage specific files: `git add <paths>` (never `git add -A` blindly)
3. Verify staged content: `git diff --staged`
4. Commit with conventional format: `git commit -m "type(scope): description"`

## Conventional Commits

Format: `type(scope): description`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `revert`

```bash
git commit -m "feat(auth): add JWT token validation"
git commit -m "fix(api): handle null response from payment gateway"
git commit -m "chore: update dependencies to latest"
```

## Key Commands

```bash
# Stage specific files
git add src/feature.js test/feature.test.js

# Stage parts of files interactively
git add -p

# Unstage a file
git restore --staged src/file.js

# Commit with message
git commit -m "feat(auth): add login endpoint"

# Multi-line message
git commit -m "fix(api): handle timeout" -m "Added 30s timeout to upstream calls."

# Amend last commit (local only!)
git commit --amend --no-edit
git commit --amend -m "fix(api): better message"

# Empty commit (trigger CI)
git commit --allow-empty -m "ci: trigger rebuild"
```

## Safety Rules

1. **Always stage specific files** — never `git add -A` without reviewing
2. **Always `git diff --staged` before committing** — verify intent
3. **Never amend pushed commits** — use `git revert` instead
4. **One logical change per commit** — don't mix features with refactoring
5. **Never commit secrets** — check for `.env`, credentials, API keys

## Edge Cases

- Pre-commit hook fails: fix the issue and retry (don't use `--no-verify`)
- Forgot a file: `git add file && git commit --amend --no-edit` (if not pushed)
- Wrong message: `git commit --amend -m "correct message"` (if not pushed)
- Want to split a commit: use `git reset HEAD~1` then stage and commit separately
