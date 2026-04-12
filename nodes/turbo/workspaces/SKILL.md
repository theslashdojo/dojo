---
name: turbo-workspaces
description: Structure and manage Turborepo monorepo workspaces — use when creating workspaces, adding packages, structuring apps/packages, or pruning for deployment
---

# Turborepo Workspace Management

Create, structure, and manage workspaces in a Turborepo monorepo.

## When to Use

- Setting up a new Turborepo monorepo structure
- Adding a new app or package to an existing monorepo
- Creating shared internal libraries
- Configuring workspace dependencies
- Pruning the monorepo for Docker/deployment
- Listing or validating existing workspaces

## Workflow

1. **Check existing structure**: Look for apps/ and packages/ directories
2. **Detect package manager**: Check for pnpm-workspace.yaml, package-lock.json, yarn.lock
3. **Create workspace directory**: mkdir in apps/ or packages/
4. **Initialize package.json**: Set name, exports, scripts
5. **Install dependencies**: Run package manager install from root
6. **Verify**: Run `turbo build --filter=<new-workspace>` to validate

## Monorepo Structure

```
my-monorepo/
├── apps/           # Deployable applications
│   ├── web/        # Frontend app
│   └── api/        # Backend service
├── packages/       # Shared libraries
│   ├── ui/         # Component library
│   ├── utils/      # Utility functions
│   └── config/     # Shared configuration
├── package.json    # Root with workspaces
├── turbo.json      # Task configuration
└── pnpm-workspace.yaml  # (pnpm)
```

## Internal Package Template

```json
{
  "name": "@repo/my-lib",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./src/index.ts"
  },
  "scripts": {
    "build": "tsup src/index.ts --format esm,cjs --dts",
    "dev": "tsup src/index.ts --format esm,cjs --dts --watch",
    "lint": "eslint src/",
    "typecheck": "tsc --noEmit"
  }
}
```

## Consuming Internal Packages

```json
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/utils": "workspace:*"
  }
}
```

## Workspace Configuration by Package Manager

### pnpm
```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"
```

### npm / yarn / bun
```json
{
  "workspaces": ["apps/*", "packages/*"]
}
```

## Filtering Workspaces

```bash
turbo build --filter=web            # By name
turbo build --filter=@repo/ui       # By scoped name
turbo build --filter={./apps/*}     # By directory
turbo build --filter=web...         # With dependencies
turbo build --filter=...web         # With dependents
turbo build --filter=[HEAD^1]       # Changed since commit
turbo build --affected              # Changed on branch
```

## turbo prune for Docker

```bash
turbo prune web --docker
# Creates out/json/ and out/full/ for layered Docker builds
```

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY . .
RUN npx turbo prune web --docker

FROM node:20-alpine AS installer
WORKDIR /app
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
RUN pnpm install --frozen-lockfile

COPY --from=builder /app/out/full/ .
RUN pnpm turbo build --filter=web
```

## Edge Cases

- **Nested globs not supported**: Use `apps/*` not `apps/**`
- **No relative imports across packages**: Always use installed dependencies
- **Workspace names must be unique**: Across the entire monorepo
- **Missing lockfile**: turbo may fail or produce incorrect dependency graphs
- **pnpm strict mode**: May need `.npmrc` with `shamefully-hoist=true` for some packages

## Script

Run `scripts/manage-workspaces.sh` to create, list, or validate workspaces.
