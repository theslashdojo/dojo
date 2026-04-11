---
name: npm-publish
description: Publish packages to the npm registry — use when releasing packages, bumping versions, managing access control, or configuring provenance
---

# npm publish

Publish packages to the npm registry with proper versioning, access control, and security.

## When to Use

- Releasing a new version of a package to the npm registry
- Bumping package versions (patch, minor, major, pre-release)
- Publishing scoped or private packages
- Setting up prepublishOnly safety checks
- Configuring provenance for supply chain security
- Deprecating old versions

## Workflow

1. Build: ensure your package is ready (`npm run build`)
2. Test: run your test suite (`npm test`)
3. Preview: verify published files (`npm pack --dry-run`)
4. Version: bump the version (`npm version patch|minor|major`)
5. Publish: push to the registry (`npm publish`)
6. Verify: check the registry page and `npm info <pkg>`

## Key Commands

```bash
# Login to npm
npm login
npm whoami                            # verify login

# Bump version (creates git commit + tag)
npm version patch                     # 1.0.0 -> 1.0.1
npm version minor                     # 1.0.0 -> 1.1.0
npm version major                     # 1.0.0 -> 2.0.0
npm version prerelease --preid=beta   # 1.0.0 -> 1.0.1-beta.0
npm version 2.0.0-rc.1               # explicit version

# Version without git commit/tag
npm version patch --no-git-tag-version

# Preview what gets published
npm pack --dry-run

# Publish
npm publish                           # unscoped packages
npm publish --access public           # scoped packages (first time)
npm publish --tag beta                # publish to a dist tag
npm publish --dry-run                 # simulate without publishing
npm publish --provenance              # with provenance (CI only)

# Dist tags
npm dist-tag ls @scope/pkg
npm dist-tag add @scope/pkg@1.0.0-beta.1 beta
npm dist-tag rm @scope/pkg beta

# Deprecation (preferred over unpublish)
npm deprecate @scope/pkg@1.0.0 "Use v2 instead"

# Unpublish (within 72 hours only)
npm unpublish @scope/pkg@1.0.0
```

## Controlling Published Files

**files field** (whitelist — recommended):
```json
{
  "files": ["dist", "README.md", "LICENSE"]
}
```

**.npmignore** (blacklist):
```
src/
test/
*.test.js
.github/
.env
```

Always included: `package.json`, `README`, `LICENSE`, `CHANGELOG`.
Always excluded: `.git`, `node_modules`, `.npmrc`, `.gitignore`.

## prepublishOnly Hook

Run build and test automatically before every publish:

```json
{
  "scripts": {
    "prepublishOnly": "npm run build && npm test"
  }
}
```

Lifecycle order: `prepublishOnly` -> `prepack` -> `postpack` -> `publish` -> `postpublish`

## Scoped Packages

```bash
# Initialize a scoped package
npm init --scope=@myorg

# First publish must declare access
npm publish --access public

# Change access later
npm access public @myorg/my-pkg
npm access restricted @myorg/my-pkg
```

## Provenance

Link published packages to source code and build systems:

```bash
# Must run in supported CI (GitHub Actions, GitLab CI)
npm publish --provenance
```

Requires: public repository, OIDC token support, supported CI environment.

## 2FA for Publishing

```bash
# Require 2FA for publishing and access changes
npm profile enable-2fa auth-and-writes

# Require 2FA for auth only
npm profile enable-2fa auth-only

# Pass OTP inline when 2FA is enabled
npm publish --otp=123456
```

## Safety Rules

1. **Always run `npm pack --dry-run`** before publishing to verify included files
2. **Use prepublishOnly** to enforce build and test before publish
3. **Never publish with secrets** — check `npm pack --dry-run` output for .env or credentials
4. **Prefer `npm deprecate` over `npm unpublish`** for old versions
5. **Use provenance in CI** for supply chain security
6. **Enable 2FA for auth-and-writes** on your npm account
7. **Use the `files` field** rather than `.npmignore` to control published content
8. **Tag pre-releases explicitly** — `npm publish --tag beta` prevents users from getting pre-release via `npm install`

## Edge Cases

- **Scoped package first publish**: must use `--access public` or it defaults to restricted (paid feature)
- **Version already exists**: npm rejects duplicate version numbers. Bump the version and retry.
- **Unpublish window**: packages can only be unpublished within 72 hours and only if no other packages depend on them
- **Large package size**: check `npm pack --dry-run` for unexpected files. Use the `files` field to whitelist.
- **OTP required**: if 2FA is enabled, pass `--otp=<code>` or npm will prompt interactively
- **Provenance fails locally**: provenance only works in supported CI environments with OIDC tokens
