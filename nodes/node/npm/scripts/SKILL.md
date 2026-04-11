---
name: npm-scripts
description: Run npm scripts, lifecycle hooks, and npx commands — use when executing build, test, or lint scripts, composing script pipelines, or running packages temporarily
---

# npm scripts

Define and run project commands via the `scripts` field in package.json.

## When to Use

- Running project build, test, lint, or dev scripts
- Setting up automatic pre/post hooks for scripts
- Using npx to run packages without global installation
- Composing multiple scripts into a pipeline
- Passing arguments to npm scripts
- Making scripts work cross-platform (Windows + Unix)

## Workflow

1. Define scripts in `package.json` under the `scripts` field
2. Run with `npm run <name>` or shortcuts (`npm test`, `npm start`)
3. Pass arguments after `--`: `npm run test -- --watch`
4. Add `pre<name>` and `post<name>` scripts for automatic hooks
5. Use `npx` for one-off package execution

## Key Commands

```bash
# Run a named script
npm run build
npm run lint
npm run dev

# Built-in shortcuts
npm test            # runs "test" script
npm start           # runs "start" script
npm stop            # runs "stop" script

# Pass arguments to a script
npm run test -- --watch --coverage
npm run build -- --outdir=dist

# List all available scripts
npm run

# Run with npx (no global install needed)
npx eslint --init
npx create-next-app@latest my-app
npx tsx script.ts

# Skip npx confirmation prompt
npx --yes degit user/repo my-project

# npm exec equivalent
npm exec -- eslint --init
```

## Defining Scripts

```json
{
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "dev": "tsx watch src/index.ts",
    "test": "vitest",
    "test:watch": "vitest --watch",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix",
    "typecheck": "tsc --noEmit",
    "clean": "rm -rf dist",
    "prepublishOnly": "npm run build && npm test"
  }
}
```

## Lifecycle Scripts

Scripts that run automatically:

**Install**: `preinstall` -> `install` -> `postinstall` -> `prepare`
**Publish**: `prepublishOnly` -> `prepack` -> `postpack` -> `publish` -> `postpublish`
**Version**: `preversion` -> `version` -> `postversion`

## Pre and Post Hooks

Any script gets automatic `pre` and `post` hooks:

```json
{
  "scripts": {
    "prebuild": "npm run clean",
    "build": "tsup src/index.ts",
    "postbuild": "echo 'Build complete'",
    "pretest": "npm run lint",
    "test": "vitest run",
    "posttest": "echo 'Tests passed'"
  }
}
```

Running `npm run build` executes: `prebuild` -> `build` -> `postbuild`

## Script Environment

Inside scripts, these are available:

| Variable | Value |
|----------|-------|
| `npm_package_name` | Package name |
| `npm_package_version` | Package version |
| `npm_lifecycle_event` | Currently running script name |
| `PATH` | Prepended with `node_modules/.bin` |

Because `node_modules/.bin` is on PATH, locally installed binaries work directly:
```json
{ "scripts": { "lint": "eslint src/" } }
```

## Composing Scripts

```json
{
  "scripts": {
    "check": "npm run lint && npm run typecheck && npm run test",
    "build:all": "npm run clean && npm run build:client && npm run build:server"
  }
}
```

For parallel execution, use `npm-run-all`:
```json
{
  "scripts": {
    "check": "run-p lint typecheck test",
    "build:all": "run-s clean build:*"
  }
}
```

## Cross-Platform Compatibility

```bash
# cross-env for environment variables
npm install -D cross-env
```
```json
{ "scripts": { "build": "cross-env NODE_ENV=production webpack" } }
```

```bash
# shx for Unix commands on Windows
npm install -D shx
```
```json
{ "scripts": { "clean": "shx rm -rf dist" } }
```

## Safety Rules

1. **Never run untrusted postinstall scripts** — audit dependencies that include install hooks
2. **Use `--ignore-scripts`** when installing untrusted packages: `npm install --ignore-scripts`
3. **Always use `--`** to separate npm arguments from script arguments
4. **Prefer local installs over global** — use npx or npm exec for one-off commands
5. **Pin npx versions** — use `npx pkg@version` to avoid stale cached versions
6. **Use cross-env for portability** — bare `NODE_ENV=production` breaks on Windows

## Edge Cases

- **Script not found**: `npm run` lists all available scripts. Check spelling and case.
- **Arguments not forwarded**: must use `--` separator: `npm run test -- --watch`
- **Pre-hook failure stops execution**: if `pretest` fails, `test` does not run
- **npx uses cached version**: specify `@latest` to force fresh download
- **Windows path issues**: use forward slashes or `shx` for cross-platform compatibility
- **Concurrent script failure**: `run-p` continues by default; use `run-p --race` to stop on first failure
