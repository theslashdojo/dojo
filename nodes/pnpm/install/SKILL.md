---
name: install
description: >
  Install, add, update, remove, and prefetch dependencies with pnpm. Use when a
  repository uses pnpm and you need deterministic lockfile-driven dependency
  management locally, in CI, or inside a workspace.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# pnpm Install

Use this skill when the job is dependency management, not package publishing or runtime execution.

## When to Use

- Install from `pnpm-lock.yaml` with `pnpm install` or `pnpm install --frozen-lockfile`
- Add or remove packages in one workspace with `pnpm add --filter <pkg>` or `pnpm remove`
- Refresh versions with `pnpm update`
- Pre-warm a Docker or CI cache with `pnpm fetch`
- Inspect stale dependencies with `pnpm outdated`

## Workflow

1. Confirm the project is actually using pnpm: `packageManager`, `pnpm-lock.yaml`, or `pnpm-workspace.yaml`
2. Prefer lockfile-respecting installs in automation: `pnpm install --frozen-lockfile`
3. For monorepos, scope changes with `--filter` or `-w`
4. Use `pnpm fetch` before Docker builds when only the lockfile is available
5. Re-run targeted scripts only after the dependency graph is in sync

## Common Commands

```bash
pnpm install
pnpm install --frozen-lockfile
pnpm add zod
pnpm add -D typescript vitest
pnpm add react --filter @acme/web
pnpm remove eslint
pnpm update -r
pnpm outdated -r
pnpm fetch --prod
```

## Notes

- `pnpm add --workspace` only succeeds if the dependency exists in the workspace.
- `pnpm add --allow-build=<pkg>` records build-script approval for packages like `esbuild`.
- `pnpm fetch` reads the lockfile and fills the store without creating project `node_modules`.
- In CI, a dirty lockfile should fail fast instead of being rewritten.

## Edge Cases

- Root add in a workspace: use `-w` or `--workspace-root`
- No lockfile: `--frozen-lockfile` and `fetch` should fail by design
- Filter matched nothing: add `--fail-if-no-match` if the absence should be fatal
- Postinstall blocked: check [[pnpm/security]] for `approve-builds`, `allowBuilds`, and related settings
