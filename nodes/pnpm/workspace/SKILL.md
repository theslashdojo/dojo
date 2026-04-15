---
name: workspace
description: >
  Manage pnpm workspaces, workspace protocol dependencies, filters, and
  recursive operations. Use when working in a pnpm monorepo and you need to
  target one package, many packages, or the dependency graph safely.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# pnpm Workspace

Use this skill when the repo has `pnpm-workspace.yaml` and the job depends on package boundaries.

## When to Use

- Validate that a repo is a pnpm workspace
- Add one workspace package to another with `workspace:*`
- Run a script across matching packages with `-r` and `--filter`
- Trace why a dependency exists with `pnpm why`
- List packages or resume a recursive run from a specific package

## Workflow

1. Read `pnpm-workspace.yaml` to find workspace globs
2. Prefer the `workspace:` protocol for local package dependencies
3. Scope every change with `--filter` when you do not mean “all packages”
4. Use recursive commands only when the task is intentionally multi-package
5. If peer behavior is surprising, inspect `dependenciesMeta.*.injected`

## Common Commands

```bash
pnpm -r list --depth -1
pnpm --filter @acme/web add @acme/ui@workspace:*
pnpm --filter @acme/web... test
pnpm --filter ...@acme/ui build
pnpm why react
pnpm -r run build
```

## Filter Shortcuts

- `foo...` includes `foo` and its dependencies
- `...foo` includes `foo` and its dependents
- `{packages/**}` scopes by directory
- `"[origin/main]"` scopes by changed packages since a ref

## Edge Cases

- Without `workspace:`, pnpm may fall back to the registry if the local range does not match
- `--parallel` ignores topological ordering; use it only for long-running or independent tasks
- Injected workspace dependencies behave like hard-linked copies and may require rebuild/install refreshes
