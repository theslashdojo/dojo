---
name: config
description: Initialize and configure ESLint flat config for JavaScript/TypeScript projects. Use when setting up ESLint from scratch, adding ESLint to an existing project, or creating eslint.config.mjs with rules, plugins, and ignores.
---

# ESLint Configuration

Create and configure ESLint flat config files for any JavaScript or TypeScript project.

## When to Use

- Setting up ESLint in a new project
- Adding ESLint to an existing project that has none
- Restructuring ESLint configuration
- Converting a project from eslintrc to flat config
- Adding TypeScript or React support to ESLint config

## Workflow

1. Detect project type (check for tsconfig.json, React deps, Node.js vs browser)
2. Install ESLint and required packages
3. Create `eslint.config.mjs` with appropriate config
4. Add standard ignores (dist, build, node_modules, coverage)
5. Verify config works: `npx eslint --print-config src/index.js`
6. Run initial lint: `npx eslint .`

## Quick Reference

### Minimal JavaScript Config

```javascript
// eslint.config.mjs
import js from "@eslint/js";

export default [
  js.configs.recommended,
  { ignores: ["dist/", "node_modules/"] },
];
```

### TypeScript Config

```javascript
// eslint.config.mjs
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/", "node_modules/"] },
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
);
```

### React + TypeScript Config

```javascript
// eslint.config.mjs
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/", "build/", "node_modules/"] },
  {
    files: ["src/**/*.{ts,tsx}"],
    plugins: { react, "react-hooks": reactHooks },
    languageOptions: {
      globals: { ...globals.browser },
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react/react-in-jsx-scope": "off",
    },
    settings: { react: { version: "detect" } },
  },
);
```

### Node.js Config

```javascript
// eslint.config.mjs
import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  { ignores: ["dist/", "node_modules/"] },
  {
    files: ["src/**/*.js"],
    languageOptions: {
      globals: { ...globals.node },
      sourceType: "module",
    },
    rules: {
      "no-console": "off",
      "no-process-exit": "off",
    },
  },
];
```

## Detection Logic

When deciding what config to create, check for:

| Signal | Meaning |
|--------|---------|
| `tsconfig.json` exists | Add typescript-eslint |
| `react` in package.json deps | Add eslint-plugin-react + hooks |
| `next` in package.json deps | Add @next/eslint-plugin-next |
| `vue` in package.json deps | Add eslint-plugin-vue |
| No `type: "module"` in package.json | Use `.cjs` extension or CommonJS |
| `.prettierrc` exists | Add eslint-config-prettier |

## Edge Cases

- If both `.eslintrc.*` and `eslint.config.*` exist, ESLint uses flat config and warns about legacy file — remove the legacy file
- Global ignores must be a standalone object with ONLY the `ignores` key
- The `globals` npm package must be installed separately for browser/node globals
- For `import.meta.dirname`, Node.js 20.11+ is required — use `fileURLToPath` fallback for older versions
- If the project uses CommonJS (`require`), use `eslint.config.cjs` with `module.exports`
