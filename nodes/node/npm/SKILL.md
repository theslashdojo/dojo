---
name: npm
description: Manage Node.js packages with npm — use when installing dependencies, publishing packages, configuring package.json, or running project scripts
---

# npm — Node Package Manager

Manage packages, dependencies, and project configuration for Node.js projects.

## When to Use

- Initializing a new Node.js project with package.json
- Installing, updating, or removing dependencies
- Publishing packages to the npm registry
- Running project scripts (build, test, lint, start)
- Managing monorepo workspaces
- Configuring registry authentication or scoped registries

## Workflow

1. Initialize: `npm init -y` (defaults) or `npm init` (interactive)
2. Install production deps: `npm install express`
3. Install dev deps: `npm install -D typescript`
4. Run scripts: `npm run build`, `npm test`, `npm start`
5. Audit: `npm audit` to check for vulnerabilities
6. Publish: `npm version patch && npm publish`

## Key Commands

```bash
# Initialize a project
npm init -y                       # defaults
npm init                          # interactive
npm init --scope=@myorg           # scoped package
npm init @vitejs/app my-app       # use an initializer

# Install dependencies
npm install                       # install all from package.json
npm install express               # add to dependencies
npm install -D typescript         # add to devDependencies
npm install -E lodash@4.17.21     # pin exact version
npm install -g tsx                # install globally

# Clean install for CI
npm ci                            # strict, fast, reproducible
npm ci --omit=dev                 # skip devDependencies

# Update and audit
npm update                        # update within semver ranges
npm outdated                      # check for outdated packages
npm audit                         # vulnerability check
npm audit fix                     # auto-fix vulnerabilities

# Run scripts
npm run build
npm test                          # shorthand for npm run test
npm start                         # shorthand for npm run start
npm run test -- --watch           # pass arguments

# Execute packages without installing
npx create-react-app my-app
npx tsx script.ts

# Publishing
npm login
npm version patch                 # bump version
npm pack --dry-run                # preview published files
npm publish                       # publish to registry
npm publish --access public       # scoped packages

# Information
npm ls --depth=0                  # list installed packages
npm info <package>                # package metadata
npm search <query>                # search registry

# Workspaces
npm run build -w packages/core    # run in one workspace
npm run build --workspaces        # run in all workspaces
npm install lodash -w packages/utils  # add dep to workspace
```

## package.json Essentials

```json
{
  "name": "@scope/my-package",
  "version": "1.0.0",
  "type": "module",
  "main": "./dist/index.cjs",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.cjs",
      "types": "./dist/index.d.ts"
    }
  },
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "test": "vitest",
    "lint": "eslint src/",
    "prepublishOnly": "npm run build && npm test"
  },
  "dependencies": {},
  "devDependencies": {},
  "engines": { "node": ">=20" },
  "files": ["dist"]
}
```

## Semver Ranges

- `^1.2.3` — compatible with 1.x.x (>=1.2.3 <2.0.0)
- `~1.2.3` — patch-level only (>=1.2.3 <1.3.0)
- `1.2.3` — exact version
- `*` — any version
- `>=1.0.0 <2.0.0` — explicit range

## .npmrc Configuration

```ini
# Project-level .npmrc
registry=https://registry.npmjs.org/
@myorg:registry=https://npm.pkg.github.com/
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
save-exact=true
engine-strict=true
```

Precedence: CLI flags > env vars > project .npmrc > user ~/.npmrc > global /etc/npmrc

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `NPM_TOKEN` | Registry authentication token |
| `NPM_CONFIG_REGISTRY` | Override default registry |
| `NODE_ENV` | `production` skips devDependencies |
| `npm_package_name` | Current package name (in scripts) |
| `npm_package_version` | Current package version (in scripts) |

## Safety Rules

1. **Always commit package-lock.json** — it ensures deterministic installs
2. **Use npm ci in CI pipelines** — never `npm install` in automated builds
3. **Never use sudo with npm** — fix your npm prefix instead
4. **Pin critical dependencies** — use `-E` for exact versions on important packages
5. **Run npm audit regularly** — check for known vulnerabilities
6. **Never commit auth tokens** — use environment variable interpolation in .npmrc
7. **Use the files field** — whitelist published files rather than relying on .npmignore
8. **Review before publishing** — always run `npm pack --dry-run` first

## Edge Cases

- **Peer dependency conflicts**: use `--legacy-peer-deps` to bypass; only `--force` as last resort
- **Lock file merge conflicts**: delete `package-lock.json` and `node_modules`, then `npm install`
- **Permission errors**: never use `sudo npm install -g` — configure npm prefix to a user directory
- **Registry auth failures**: check `.npmrc` token interpolation and ensure env vars are set
- **Phantom dependencies**: code may import hoisted packages it does not declare — always declare all imports
- **ERESOLVE errors**: conflicting peer dependencies — use `npm ls <package>` to trace the conflict
