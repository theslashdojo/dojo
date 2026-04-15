---
name: deploy
description: >
  Produce a portable deployment directory from a pnpm workspace package. Use
  when you need to ship one app from a monorepo into Docker, a server, or a
  build artifact without copying the whole repository.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# pnpm Deploy

Use this skill when a pnpm workspace package must be turned into a self-contained output directory.

## When to Use

- Build a production bundle for one workspace package
- Copy only files that should ship from a monorepo
- Prepare a deployment layer after `pnpm fetch`
- Support older workspaces with `--legacy`

## Workflow

1. Pick the package with `--filter`
2. Install and build the workspace first if the artifact is not already ready
3. Deploy to a target directory with `pnpm deploy`
4. Use `--prod` for runtime-only output or `--dev` for build-time tooling
5. If the repo does not use injected workspace packages, fall back to `--legacy`

## Common Commands

```bash
pnpm --filter @acme/web --prod deploy ./out
pnpm --filter @acme/worker deploy ./out --legacy
pnpm fetch --prod
pnpm install --offline --frozen-lockfile
```

## Deployment Notes

- `pnpm deploy` is workspace-oriented; it is not a generic pack command
- The included files follow package packing rules unless `deployAllFiles` is enabled
- Docker builds often use `fetch` first, then `install --offline`, then `deploy`

## Edge Cases

- No filter: deploy may be ambiguous in a workspace, so require one
- Missing workspace injection: `--legacy` avoids newer deploy assumptions
- Empty output after build: check the package `files` field or `publishConfig.directory`
