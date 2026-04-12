---
name: fix
description: Auto-fix ESLint violations using --fix, --fix-dry-run, and the programmatic API. Use when asked to fix lint errors, clean up code style, or integrate auto-fixing into CI/pre-commit hooks.
---

# ESLint Auto-Fix

Run ESLint's auto-fix to correct fixable violations in-place or preview changes.

## When to Use

- Fixing all lint errors in a project or file
- Previewing what ESLint would fix before applying
- Integrating auto-fix into pre-commit hooks
- Fixing only specific types of issues (layout, problems, suggestions)
- Building programmatic fixing into custom tooling

## Workflow

1. Run `npx eslint .` to see current violations
2. Run `npx eslint --fix-dry-run .` to preview fixes
3. Run `npx eslint --fix .` to apply fixes
4. Review remaining (unfixable) violations
5. Manually fix unfixable issues or adjust rules

## Quick Reference

### Basic Commands

```bash
# Fix everything fixable
npx eslint --fix .

# Fix specific files
npx eslint --fix src/index.js src/utils.js

# Fix with glob pattern
npx eslint --fix "src/**/*.{js,ts,jsx,tsx}"

# Preview fixes without writing
npx eslint --fix-dry-run .

# Fix with caching (faster reruns)
npx eslint --fix --cache .
```

### Selective Fixing

```bash
# Only fix formatting (quotes, semicolons, indentation)
npx eslint --fix --fix-type layout .

# Only fix code problems
npx eslint --fix --fix-type problem .

# Only fix suggestions
npx eslint --fix --fix-type suggestion .

# Combine types
npx eslint --fix --fix-type problem --fix-type suggestion .
```

### Pre-Commit Hook Setup

```bash
npm install --save-dev lint-staged husky
npx husky init
echo 'npx lint-staged' > .husky/pre-commit
```

```json
{
  "lint-staged": {
    "*.{js,ts,jsx,tsx}": ["eslint --fix"]
  }
}
```

### Programmatic API

```javascript
import { ESLint } from "eslint";

const eslint = new ESLint({ fix: true });
const results = await eslint.lintFiles(["src/**/*.js"]);
await ESLint.outputFixes(results);

const formatter = await eslint.loadFormatter("stylish");
const output = await formatter.format(results);
if (output) console.log(output);
```

## Key Facts

- `--fix` modifies files in-place — commit or stash first
- Not all rules are fixable: `no-unused-vars`, `no-console`, `no-undef` require manual fixes
- `--fix-dry-run` shows what would change without writing
- Exit code 1 means unfixable errors remain after fixing
- `--cache` stores results in `.eslintcache` — delete when config changes

## Edge Cases

- `--fix` + `--fix-dry-run` together: `--fix-dry-run` wins (no files written)
- Running `--fix` on stdin: use `--fix-dry-run --stdin` — fix output goes to stdout
- `--fix` respects `.eslintcache` — clear cache after config changes
- Some rules conflict: fixing one rule may introduce violations of another
- Always run `eslint .` after `eslint --fix .` to verify no remaining issues
