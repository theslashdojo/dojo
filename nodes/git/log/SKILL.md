---
name: git-log
description: Inspect commit history with filtering, formatting, graph visualization, blame, and bisect — use when investigating code history or tracking changes
---

# Git Log

Navigate and search commit history.

## When to Use

- Reviewing recent changes before pushing
- Finding who changed a file and when
- Searching for when a string was added/removed
- Visualizing branch topology
- Binary-searching for a bug-introducing commit

## Key Commands

```bash
# Compact history
git log --oneline -10

# Full graph with all branches
git log --oneline --graph --all --decorate

# History of a specific file
git log --oneline --follow -- src/auth.js

# Commits by author
git log --author="Alice" --oneline

# Commits in date range
git log --since="2026-01-01" --until="2026-03-01" --oneline

# Search commit messages
git log --grep="fix auth" --oneline

# Find when a string was added/removed (pickaxe)
git log -S "functionName" --oneline

# Commits on feature not on main
git log main..feature --oneline

# Last commit with full diff
git log -p -1

# Who changed each line
git blame src/auth.js
git blame -L 10,20 src/auth.js

# Binary search for a bug
git bisect start
git bisect bad HEAD
git bisect good v1.0
# test each checkout, mark good/bad
git bisect reset

# Automated bisect
git bisect start HEAD v1.0
git bisect run npm test
```

## Output Formats

```bash
# Summary stats
git log --stat -5

# Custom format
git log --pretty=format:"%h %an %ar %s" -10

# Shortlog grouped by author
git shortlog -sn

# Changelog between tags
git log --pretty=format:"- %s (%h)" v1.0..v2.0
```

## Safety Rules

1. **Use --follow for renamed files** — `git log --follow -- path`
2. **Use triple-dot for branch comparison** — `main...feature` shows divergence
3. **Use -S for archaeology** — find when code was introduced
4. **Always bisect reset** — don't leave bisect state active
