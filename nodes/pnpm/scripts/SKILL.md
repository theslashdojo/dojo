---
name: scripts
description: >
  Run pnpm scripts, execute local binaries, and hot-load one-off CLIs with
  `run`, `exec`, and `dlx`. Use when a pnpm project needs task execution in one
  package or across a workspace.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# pnpm Scripts

Use this skill when the job is execution rather than dependency mutation.

## When to Use

- Run a package script from `package.json`
- Execute a local binary in `node_modules/.bin`
- Start a one-off generator with `pnpm dlx`
- Run commands recursively with filters and parallel mode
- Resume a failed recursive exec from a named package

## Workflow

1. Choose the execution surface:
   `run` for scripts, `exec` for local binaries, `dlx` for temporary tools
2. Add `-r` only when you want workspace fan-out
3. Add `--filter` before recursive execution to narrow the blast radius
4. Use `--parallel` only when ordering does not matter
5. For shell pipelines, add `--shell-mode`

## Common Commands

```bash
pnpm run build
pnpm -r --filter @acme/* run lint
pnpm exec tsc --noEmit
pnpm -rc exec 'echo $PNPM_PACKAGE_NAME'
pnpm dlx create-vue my-app
pnpm --package yo --package generator-webapp dlx yo webapp
```

## Rules of Thumb

- `pnpm run` knows about package scripts and pre/post hooks
- `pnpm exec` is for binaries already available to the project
- `pnpm dlx` is for temporary CLIs you do not want in dependencies
- `--report-summary` is useful for machine-readable recursive output

## Edge Cases

- Missing `node_modules`: use [[pnpm/install]] or enable `verifyDepsBeforeRun`
- Shell quoting differs by platform; prefer `--shell-mode` when using pipes or env expansion
- Recursive execution with no matches can silently do nothing unless `--fail-if-no-match` is used
