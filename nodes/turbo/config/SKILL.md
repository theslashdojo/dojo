---
name: turbo-config
description: Initialize and configure turbo.json for Turborepo monorepos — use when setting up turbo.json, configuring remote caching, env modes, or per-workspace overrides
---

# Turborepo Configuration

Initialize and manage `turbo.json` configuration files for Turborepo monorepos.

## When to Use

- Setting up a new Turborepo project
- Adding turbo.json to an existing monorepo
- Configuring remote caching for CI
- Setting environment variable modes (strict/loose)
- Creating per-workspace turbo.json overrides
- Tuning concurrency and cache settings

## Workflow

1. **Check for existing config**: Look for `turbo.json` at repo root
2. **Detect package manager**: Check for pnpm-workspace.yaml, package-lock.json, yarn.lock, or bun.lockb
3. **Detect workspaces**: Read workspace patterns from package manager config
4. **Create/update turbo.json**: Generate config with appropriate defaults
5. **Set up remote cache** (optional): Configure TURBO_TOKEN and TURBO_TEAM

## Root turbo.json Template

```json
{
  "$schema": "https://turborepo.dev/schema.json",
  "globalDependencies": [".env"],
  "globalEnv": ["NODE_ENV", "CI"],
  "envMode": "strict",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "persistent": true,
      "cache": false
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    }
  }
}
```

## Per-Workspace Override Template

Create `turbo.json` in a workspace directory:

```json
{
  "extends": ["//"],
  "tasks": {
    "build": {
      "outputs": [".next/**", "!.next/cache/**"]
    }
  }
}
```

## Global Options

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `globalDependencies` | `string[]` | `[]` | Files that invalidate ALL caches when changed |
| `globalEnv` | `string[]` | `[]` | Env vars in every task hash |
| `globalPassThroughEnv` | `string[]` | `null` | Env vars available but not hashed |
| `envMode` | `"strict"\|"loose"` | `"strict"` | Env var availability mode |
| `concurrency` | `number\|string` | `10` | Max parallel tasks |
| `cacheDir` | `string` | `".turbo/cache"` | Local cache location |
| `cacheMaxAge` | `string` | `"0"` | Cache entry TTL (e.g., "7d") |
| `cacheMaxSize` | `string` | `"0"` | Max cache size (e.g., "10GB") |
| `ui` | `"tui"\|"stream"` | `"stream"` | Terminal UI mode |

## Remote Cache Setup

### Vercel (default)

```bash
npx turbo login
npx turbo link
```

### CI Environment Variables

```bash
TURBO_TOKEN=your-token
TURBO_TEAM=your-team
```

### Self-Hosted

```json
{
  "remoteCache": {
    "enabled": true,
    "signature": true,
    "timeout": 30,
    "uploadTimeout": 60,
    "apiUrl": "https://your-cache-server.example.com"
  }
}
```

## Environment Variable Patterns

```json
{
  "env": ["API_URL", "DATABASE_*", "!DATABASE_PASSWORD"],
  "passThroughEnv": ["AWS_SECRET_ACCESS_KEY"]
}
```

- `*` wildcard matches any suffix
- `!` prefix excludes a variable
- `env` vars are hashed (affect cache key)
- `passThroughEnv` vars are available but not hashed

## Edge Cases

- **Missing turbo.json**: turbo will refuse to run — always create one at root
- **Workspace turbo.json without extends**: Invalid — must include `"extends": ["//"]`
- **globalDependencies with absolute paths**: Not supported — use paths relative to repo root
- **envMode loose in CI**: Dangerous — undeclared env vars can cause phantom cache hits
- **cacheDir with git worktrees**: Custom cacheDir disables automatic worktree cache sharing

## Script

Run `scripts/init-config.sh` to initialize turbo.json with interactive detection of your monorepo setup.
