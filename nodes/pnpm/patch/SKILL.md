---
name: patch
description: >
  Create, commit, and remove pnpm dependency patches. Use when a registry
  package must be fixed locally without waiting for upstream, especially for
  broken transitive dependencies or urgent unblockers.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# pnpm Patch

Use this skill when overrides are not enough and you need to change package contents.

## When to Use

- Patch a direct or transitive dependency locally
- Commit a patch file into the repository for repeatable installs
- Remove obsolete patches after an upstream release lands

## Workflow

1. Start from an exact package version: `pnpm patch foo@1.2.3`
2. Edit the extracted directory
3. Commit the patch with `pnpm patch-commit <dir>`
4. Verify `patchedDependencies` and the patch file are present
5. Remove the patch later with `pnpm patch-remove foo@1.2.3`

## Common Commands

```bash
pnpm patch left-pad@1.3.0
pnpm patch --edit-dir ./.patches/tmp/esbuild esbuild@0.25.1
pnpm patch-commit ./.patches/tmp/esbuild
pnpm patch-remove esbuild@0.25.1
```

## Use Patch vs Override

- Use `overrides` when only the resolved version must change
- Use `patch` when the shipped files themselves must change
- Use [[pnpm/security]] controls if the issue is build-script trust, not code behavior

## Edge Cases

- Patch specs should be exact versions, not loose ranges
- A patch is repository state; commit the patch file and manifest changes together
- Rebase conflicts are common when multiple branches patch the same dependency
