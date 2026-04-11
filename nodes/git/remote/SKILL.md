---
name: git-remote
description: Manage remote repositories — fetch, pull, push, clone, and configure origin/upstream — use when syncing with remote repos or managing remote connections
---

# Git Remote

Manage connections to remote repositories and sync code.

## When to Use

- Cloning a repository
- Pushing local commits to remote
- Pulling latest changes
- Adding an upstream remote for fork workflows
- Changing remote URLs

## Workflow

### Daily Sync
```bash
git fetch origin
git pull --rebase origin main
# ... work ...
git push origin feature-branch
```

### Fork Workflow
```bash
git remote add upstream https://github.com/original/repo.git
git fetch upstream
git rebase upstream/main
git push origin main
```

## Key Commands

```bash
# Clone
git clone https://github.com/owner/repo.git
git clone --depth 1 https://github.com/owner/repo.git  # shallow

# List remotes
git remote -v

# Add remote
git remote add upstream https://github.com/original/repo.git

# Change URL
git remote set-url origin git@github.com:owner/repo.git

# Remove remote
git remote remove old-remote

# Fetch
git fetch origin              # from origin
git fetch --all               # all remotes
git fetch --prune             # clean stale refs

# Pull
git pull                      # tracking branch
git pull --rebase             # rebase instead of merge
git pull --autostash          # auto-stash dirty tree

# Push
git push                      # tracking remote
git push -u origin branch     # first push, set tracking
git push --tags               # push all tags
git push origin --delete branch  # delete remote branch

# Force push (CAREFUL)
git push --force-with-lease   # safe force push
```

## Safety Rules

1. **Always fetch before push** — avoids overwriting remote changes
2. **Use `--force-with-lease` not `--force`** — prevents overwriting others' work
3. **Never force-push main/master** — coordinate with team first
4. **Use `-u` on first push** — sets tracking for future push/pull
5. **Use SSH for automation** — more reliable than token auth for scripts
6. **Shallow clone for CI** — `--depth 1` is much faster

## Edge Cases

- Push rejected (non-fast-forward): pull/rebase first, then push
- Remote URL changed: `git remote set-url origin <new-url>`
- Multiple remotes: always specify `git push <remote> <branch>` explicitly
