---
name: compiler
description: Compile, type-check, and build TypeScript projects with tsc — use when running the TypeScript compiler, diagnosing type errors, configuring build pipelines, or generating declaration files
---

# TypeScript Compiler (tsc)

The `tsc` CLI is the official TypeScript compiler. It parses `.ts`/`.tsx` files, validates types, and emits JavaScript plus optional declaration files and source maps.

## When to Use This Skill

- Type-checking a TypeScript project (`tsc --noEmit`)
- Compiling TypeScript to JavaScript for distribution
- Setting up watch mode for development
- Building multi-project workspaces with project references
- Diagnosing and fixing type errors
- Generating `.d.ts` declaration files for libraries
- Profiling slow compilations

## Quick Reference

```bash
# Type-check only (most common CI usage)
npx tsc --noEmit

# Compile to dist/
npx tsc --outDir dist

# Watch mode during development
npx tsc --watch --noEmit

# Build project references
npx tsc --build

# Show effective config
npx tsc --showConfig

# Explain why files are included
npx tsc --explainFiles

# Incremental for faster re-checks
npx tsc --noEmit --incremental
```

## Workflow

### 1. Type-Check Only (CI/Pre-commit)

The most common agent workflow — validate types without emitting files:

```bash
npx tsc --noEmit
```

Exit code 0 means no errors. Non-zero means type errors exist. Parse stderr for error details.

### 2. Full Compilation

Compile and emit JavaScript:

```bash
# Using tsconfig.json defaults
npx tsc

# Explicit output directory
npx tsc --outDir dist

# Skip emit on errors
npx tsc --noEmitOnError
```

### 3. Watch Mode

For development — recompile on file changes:

```bash
npx tsc --watch
npx tsc -w --noEmit
npx tsc -b --watch  # build mode with watch
```

### 4. Build Mode (Monorepos)

For projects with `references` in tsconfig.json:

```bash
npx tsc --build
npx tsc -b --verbose
npx tsc -b --force    # ignore cache
npx tsc -b --clean    # delete outputs
```

### 5. Generate Declarations

For library authors:

```bash
# Declarations alongside JS
npx tsc --declaration

# Declarations only (bundler handles JS)
npx tsc --emitDeclarationOnly --declaration

# With source maps for go-to-definition
npx tsc --declaration --declarationMap
```

## Reading tsc Error Output

tsc errors follow this format:

```
src/index.ts(15,3): error TS2322: Type 'string' is not assignable to type 'number'.
```

Format: `file(line,col): error TScode: message`

### Common Errors and Fixes

| Code | Meaning | Fix |
|------|---------|-----|
| TS2307 | Cannot find module | Install `@types/pkg` or add declaration |
| TS2339 | Property doesn't exist on type | Add to interface or narrow type |
| TS2345 | Argument type mismatch | Fix type or add assertion |
| TS2322 | Assignment type mismatch | Align types or widen target |
| TS7006 | Implicit `any` parameter | Add type annotation |
| TS1259 | Default import needs esModuleInterop | Set `esModuleInterop: true` |
| TS18046 | Value is `unknown` | Narrow with `typeof`/`instanceof` |

## Combining tsc with Fast Transpilers

Use tsc for type checking only, and a fast tool for the actual build:

```bash
# Check types, then build with esbuild
npx tsc --noEmit && npx esbuild src/index.ts --bundle --outdir=dist --platform=node

# Check types, then build with swc
npx tsc --noEmit && npx swc src -d dist
```

## Diagnostics

When something is wrong with the build:

```bash
# What config is tsc actually using?
npx tsc --showConfig

# Why is this file being compiled?
npx tsc --explainFiles 2>&1 | grep "unexpected-file"

# What files will be compiled?
npx tsc --listFiles

# How long does each phase take?
npx tsc --extendedDiagnostics

# Full performance trace (open in chrome://tracing)
npx tsc --generateTrace ./trace-output
```

## Edge Cases

- **`tsc` with file arguments ignores tsconfig.json** — if you pass `tsc foo.ts`, it won't read tsconfig. Use `tsc -p tsconfig.json` instead.
- **`--incremental` needs `--tsBuildInfoFile`** in CI if the build directory is cleaned between runs.
- **`--isolatedModules`** is required when using Babel, swc, or esbuild for transpilation — it ensures each file can be compiled independently.
- **`--skipLibCheck`** skips type checking `.d.ts` files — speeds up compilation but can miss errors in dependencies' type definitions.
- **Watch mode in Docker** — mount volumes with polling: set `TSC_WATCHFILE=DynamicPriorityPolling`.
