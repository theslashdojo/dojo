---
name: mongosh
description: >
  Connect to MongoDB with mongosh and run interactive shell work, inline expressions, or reusable script files when you need direct inspection or shell-side automation.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# mongosh Skill

Use this skill when the fastest path is the official MongoDB shell instead of a longer Node.js program.

## When to Use

- Inspect live data or indexes before writing automation
- Reproduce a production issue directly against the shell
- Run a one-off or reusable JavaScript file with `--file`
- Execute a short expression with `--eval` in CI or a terminal step

## Required Inputs

- `MONGODB_URI` for normal connections
- `MONGOSH_EVAL` or `MONGOSH_FILE` to choose the execution mode
- `MONGOSH_NODB=1` only when the script handles `connect()` itself

## Quick Examples

```bash
export MONGODB_URI="mongodb+srv://user:pass@cluster0.example.mongodb.net/app?retryWrites=true&w=majority"
export MONGOSH_EVAL='db.getSiblingDB("app").users.countDocuments({ active: true })'
./scripts/run-command.sh
```

```bash
export MONGODB_URI="mongodb://user:pass@localhost:27017/admin?authSource=admin"
export MONGOSH_FILE="./audit-users.js"
./scripts/run-command.sh
```

## Workflow

1. Confirm the URI, auth source, and network path using [[mongodb/auth]].
2. Decide whether the task is inline (`--eval`) or script-based (`--file`).
3. Use `--nodb` only when the file itself calls `connect()`.
4. If the task becomes structured or needs JSON contracts, switch to [[mongodb/crud]] or another driver-based skill.

## Edge Cases

- If the shell times out, the problem is often Atlas access-list or private-network configuration rather than bad credentials.
- Avoid echoing `MONGODB_URI`; wrapper scripts should treat it as secret material.
- Keep shell scripts idempotent when they may be re-run by an agent or CI job.
