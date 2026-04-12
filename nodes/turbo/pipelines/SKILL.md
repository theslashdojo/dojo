---
name: turbo-pipelines
description: Define and manage task dependency graphs in turbo.json — use when adding tasks, configuring dependsOn, outputs, inputs, or pipeline execution order
---

# Turborepo Task Pipelines

Define task dependency graphs and execution pipelines in turbo.json.

## When to Use

- Adding a new task (build, test, lint, deploy) to turbo.json
- Configuring task dependencies (dependsOn)
- Setting up output caching for build artifacts
- Defining input patterns for cache invalidation
- Configuring persistent tasks for dev servers
- Optimizing parallel execution

## Workflow

1. **Identify the task**: What package.json script should turbo orchestrate?
2. **Determine dependencies**: Does it need other tasks to complete first?
3. **Declare outputs**: What files does the task produce?
4. **Set inputs** (optional): What files affect cache validity?
5. **Configure env vars**: What environment variables affect the task?
6. **Add to turbo.json**: Insert the task configuration

## dependsOn Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `^task` | Run task in dependencies first | `"^build"` — build libraries before apps |
| `task` | Run task in same package first | `"build"` — build before test in each package |
| `pkg#task` | Run specific package's task | `"utils#build"` — build utils first |
| `[]` or omitted | No dependencies, run immediately | Independent tasks like lint |

## Common Pipeline Patterns

### Standard Build Pipeline

```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "lint": {},
    "typecheck": {
      "dependsOn": ["^build"]
    }
  }
}
```

### Full-Stack Dev Server

```json
{
  "tasks": {
    "dev": {
      "dependsOn": ["^build"],
      "with": ["api#dev"],
      "persistent": true,
      "cache": false
    }
  }
}
```

### Deploy Pipeline

```json
{
  "tasks": {
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "cache": false
    }
  }
}
```

### Next.js + Library Build

```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "web#build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**"]
    }
  }
}
```

## Output Patterns by Framework

| Framework | Output Pattern |
|-----------|---------------|
| Vite/Rollup | `["dist/**"]` |
| Next.js | `[".next/**", "!.next/cache/**"]` |
| TypeScript (tsc) | `["dist/**"]` or `["build/**"]` |
| Storybook | `["storybook-static/**"]` |
| Jest coverage | `["coverage/**"]` |
| Remix | `["build/**", "public/build/**"]` |

## Edge Cases

- **Circular dependencies**: Turborepo errors on circular task dependencies — restructure dependsOn
- **Missing scripts**: Tasks referencing non-existent package.json scripts are silently skipped
- **Persistent + dependsOn**: Other tasks cannot depend on persistent tasks (deadlock)
- **Empty outputs**: Task result (exit code, logs) is still cached even with no output files
- **$TURBO_DEFAULT$ in inputs**: Must be first element to restore default behavior before exclusions

## Script

Run `scripts/add-task.sh` to add or update a task in turbo.json with proper dependency configuration.
