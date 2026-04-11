---
name: npm-install
description: Install, update, and remove npm packages — use when adding dependencies, running clean installs in CI, resolving peer conflicts, or auditing vulnerabilities
---

# npm install

Install, update, and remove packages for Node.js projects.

## When to Use

- Adding a new dependency to a project
- Running a clean install in CI/CD pipelines
- Updating packages to latest compatible versions
- Removing unused dependencies
- Fixing corrupted node_modules
- Resolving peer dependency conflicts
- Auditing for security vulnerabilities

## Workflow

1. Add dependencies: `npm install <package>` for production, `npm install -D <package>` for dev
2. Commit lock file: always commit `package-lock.json` alongside `package.json`
3. CI builds: use `npm ci` for strict reproducible installs
4. Update: `npm outdated` to check, `npm update` to apply
5. Audit: `npm audit` to check, `npm audit fix` to patch
6. Clean up: `npm prune` to remove extraneous packages

## Key Commands

```bash
# Install all from package.json
npm install

# Add production dependency
npm install express

# Add dev dependency
npm install -D typescript
npm install --save-dev eslint

# Pin exact version (no ^ prefix)
npm install -E lodash@4.17.21

# Install globally
npm install -g tsx

# Clean install for CI (strict, fast, reproducible)
npm ci
npm ci --omit=dev                  # skip devDependencies

# Update within semver ranges
npm update
npm update express                 # update one package

# Check for outdated packages
npm outdated

# Remove a package
npm uninstall express
npm uninstall -D typescript

# Remove packages not in package.json
npm prune
npm prune --omit=dev               # also remove devDependencies

# Security audit
npm audit
npm audit fix
npm audit fix --force              # allow major version bumps
npm audit --omit=dev               # audit production only
```

## npm ci vs npm install

| Behavior | `npm install` | `npm ci` |
|----------|---------------|----------|
| Modifies lock file | Yes, if needed | Never |
| Deletes node_modules | No | Yes (fresh start) |
| Requires lock file | No | Yes |
| Fails on mismatch | No | Yes |
| Speed | Slower | Faster |
| Use case | Development | CI/CD |

**Rule**: always use `npm ci` in CI pipelines and Docker builds.

## Flags Reference

| Flag | Short | Effect |
|------|-------|--------|
| `--save-dev` | `-D` | Add to devDependencies |
| `--save-exact` | `-E` | Pin exact version |
| `--save-optional` | `-O` | Add to optionalDependencies |
| `--no-save` | | Install without modifying package.json |
| `--global` | `-g` | Install globally |
| `--legacy-peer-deps` | | Ignore peer dependency conflicts |
| `--force` | `-f` | Force install despite conflicts |
| `--omit=dev` | | Skip devDependencies |
| `--dry-run` | | Show what would be installed |

## Peer Dependencies

Peer dependencies declare a package expects the consumer to provide a compatible version:

```json
{
  "peerDependencies": { "react": "^18.0.0" },
  "peerDependenciesMeta": { "react-dom": { "optional": true } }
}
```

When conflicts arise:
1. Use `npm ls <package>` to trace the conflict tree
2. Try `--legacy-peer-deps` to bypass auto-resolution
3. Use `--force` only as a last resort
4. Use the `overrides` field for permanent resolution

## Overrides

Force transitive dependency versions in package.json:

```json
{
  "overrides": {
    "lodash": "4.17.21",
    "express": { "qs": "6.11.0" }
  }
}
```

## Safety Rules

1. **Always commit package-lock.json** to version control
2. **Use npm ci in CI environments** — never `npm install` in automated builds
3. **Never delete package-lock.json** without good reason
4. **Never use sudo with npm** — fix your npm prefix instead
5. **Pin exact versions** for critical dependencies with `-E`
6. **Run npm audit regularly** to check for vulnerabilities
7. **Declare all imports** — do not rely on hoisted phantom dependencies

## Edge Cases

- **Peer dependency conflicts**: use `--legacy-peer-deps` to bypass. Only use `--force` as a last resort.
- **Optional deps failing**: normal on some platforms (e.g., `fsevents` on Linux). npm continues the install.
- **Corrupted cache**: run `npm cache clean --force` then retry.
- **Lock file conflicts during merge**: delete `package-lock.json` and `node_modules`, run `npm install`, commit the regenerated lock file.
- **ERESOLVE errors**: conflicting peer deps. Use `npm ls <package>` to understand the conflict tree.
- **Slow installs**: check if you have a `.npmrc` pointing to a slow registry; try `npm cache verify`.
