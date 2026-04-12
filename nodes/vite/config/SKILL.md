---
name: config
description: Create and configure vite.config.ts — use when setting up a new Vite project, adding path aliases, configuring CSS modules, or customizing build/dev behavior
---

# Vite Configuration

Create, customize, and maintain `vite.config.ts` for any Vite project.

## When to Use This Skill

- Setting up a new Vite project config from scratch
- Adding `resolve.alias` path mappings (e.g., `@` -> `./src`)
- Configuring CSS Modules, Sass/Less/Stylus preprocessors, or PostCSS
- Using `define` for build-time global constant replacement
- Writing conditional config that differs between dev and build
- Reading `.env` variables inside the config file with `loadEnv`
- Choosing and adding the correct framework plugin

## Quick Reference

```typescript
// Minimal config
import { defineConfig } from 'vite';
export default defineConfig({
  plugins: [],
});

// With framework plugin (React example)
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
});

// Conditional config
import { defineConfig } from 'vite';
export default defineConfig(({ command, mode }) => ({
  define: { __DEV__: command === 'serve' },
}));
```

### Framework Plugin Cheat Sheet

| Framework | Package | Import |
|-----------|---------|--------|
| React | `@vitejs/plugin-react` | `import react from '@vitejs/plugin-react'` |
| React (SWC) | `@vitejs/plugin-react-swc` | `import react from '@vitejs/plugin-react-swc'` |
| Vue | `@vitejs/plugin-vue` | `import vue from '@vitejs/plugin-vue'` |
| Svelte | `@sveltejs/vite-plugin-svelte` | `import { svelte } from '@sveltejs/vite-plugin-svelte'` |
| Solid | `vite-plugin-solid` | `import solid from 'vite-plugin-solid'` |

## Workflow: Basic Setup

1. Ensure `vite` is installed (`npm i -D vite`)
2. Create `vite.config.ts` at the project root
3. Import `defineConfig` from `vite`
4. Import and add the framework plugin
5. Export the config

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': '/src',
    },
  },
});
```

If the project does not have `"type": "module"` in `package.json`, use `.mts` extension instead (`vite.config.mts`).

## Workflow: Conditional Config (Dev vs Build)

Use the function form of `defineConfig` when dev and build need different settings.

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ command, mode, isSsrBuild, isPreview }) => {
  const isDev = command === 'serve';

  return {
    plugins: [react()],
    define: {
      __DEV__: isDev,
      __APP_MODE__: JSON.stringify(mode),
    },
    server: isDev ? {
      port: 3000,
      open: true,
    } : undefined,
  };
});
```

- `command` is `'serve'` during `vite dev` and `'build'` during `vite build`
- `mode` defaults to `'development'` or `'production'`, overridable with `--mode`
- `isSsrBuild` is `true` when running `vite build --ssr`
- `isPreview` is `true` when running `vite preview`

## Workflow: loadEnv

`import.meta.env` is not available in the config file. Use `loadEnv` to read `.env` values.

```typescript
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  // Third arg '' loads ALL env vars, not just VITE_-prefixed
  const env = loadEnv(mode, process.cwd(), '');

  return {
    define: {
      __API_URL__: JSON.stringify(env.API_URL),
    },
    server: {
      proxy: {
        '/api': {
          target: env.API_BACKEND_URL,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, ''),
        },
      },
    },
  };
});
```

`loadEnv(mode, envDir, prefixes?)` loads files in this order: `.env`, `.env.local`, `.env.[mode]`, `.env.[mode].local`. The `prefixes` parameter filters which vars are returned:
- Omit or `'VITE_'` — only `VITE_`-prefixed vars
- `''` (empty string) — all vars
- `['VITE_', 'APP_']` — multiple prefixes

## Workflow: resolve.alias

Map short import paths to directories. Always use absolute paths.

```typescript
import { defineConfig } from 'vite';
import path from 'node:path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@hooks': path.resolve(__dirname, 'src/hooks'),
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@assets': path.resolve(__dirname, 'src/assets'),
    },
  },
});
```

For TypeScript, mirror aliases in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@components/*": ["src/components/*"],
      "@hooks/*": ["src/hooks/*"],
      "@utils/*": ["src/utils/*"],
      "@assets/*": ["src/assets/*"]
    }
  }
}
```

Alternative: install `vite-tsconfig-paths` to auto-read tsconfig paths instead of duplicating.

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
});
```

## Workflow: CSS Configuration

### CSS Modules

Files named `*.module.css` (or `.module.scss`/`.module.less`) are treated as CSS Modules automatically. Configure naming:

```typescript
import { defineConfig } from 'vite';

export default defineConfig({
  css: {
    modules: {
      localsConvention: 'camelCaseOnly',
      generateScopedName: '[name]__[local]___[hash:base64:5]',
    },
  },
});
```

Usage in components:

```tsx
import styles from './Button.module.css';
// With camelCaseOnly: styles.primaryButton (from .primary-button class)
export const Button = () => <button className={styles.primaryButton}>Click</button>;
```

### Preprocessors (Sass, Less, Stylus)

Install the preprocessor, then configure global options:

```bash
npm i -D sass        # for .scss/.sass
npm i -D less        # for .less
npm i -D stylus      # for .styl
```

```typescript
import { defineConfig } from 'vite';

export default defineConfig({
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@use "@/styles/variables" as *;`,
        api: 'modern-compiler',
      },
      less: {
        math: 'always',
        globalVars: {
          primaryColor: '#4f46e5',
        },
      },
    },
  },
});
```

`additionalData` prepends content to every processed file — useful for injecting shared variables and mixins without manual imports.

## Workflow: define for Global Constants

Replace identifiers at build time with constant values.

```typescript
import { defineConfig } from 'vite';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync('./package.json', 'utf-8'));

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
    __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
    __DEV__: JSON.stringify(process.env.NODE_ENV !== 'production'),
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
  },
});
```

Declare types for TypeScript:

```typescript
// src/env.d.ts
declare const __APP_VERSION__: string;
declare const __BUILD_TIME__: string;
declare const __DEV__: boolean;
```

String values MUST be wrapped in `JSON.stringify()`. Without it, `define: { __VERSION__: '1.0' }` produces the literal code `1.0` (a number), not the string `"1.0"`.

## Edge Cases

- **`__dirname` not available in ESM**: Use `import.meta.dirname` (Node 20.11+) or `new URL('.', import.meta.url).pathname` for `resolve.alias` absolute paths when using `.mts` config.
- **Config changes require restart**: Unlike source files, `vite.config.ts` changes are not hot-reloaded. Restart the dev server after editing.
- **Plugin order matters**: Plugins run in array order. Framework plugins (react, vue) should generally be first. Plugins with `enforce: 'pre'` or `enforce: 'post'` override this.
- **Duplicate alias and tsconfig paths**: If aliases are defined in both `resolve.alias` and `tsconfig.json` `paths`, they must match. Use `vite-tsconfig-paths` to avoid drift.
- **CSS Modules + TypeScript**: To get typed CSS module imports, install `typescript-plugin-css-modules` or generate `.d.ts` files with `typed-css-modules`.
- **`define` does full token replacement**: `define: { ENV: '"prod"' }` replaces all occurrences of the token `ENV` in your code, including in variable names. Use distinctive names like `__ENV__` to avoid collisions.
- **Sass `additionalData` must end with semicolon or newline**: Missing trailing semicolons in `additionalData` cause parse errors in the first line of every `.scss` file.
- **Empty config is valid**: `export default defineConfig({})` is a valid config that uses all defaults. Useful for vanilla JS projects.
- **Multiple config files**: Use `--config path/to/config.ts` for non-standard locations. Vite only loads one config file.
