---
name: plugins
description: Add, configure, and author Vite plugins — use when adding framework support (React/Vue/Svelte), enabling legacy browser support, or writing custom build transforms
---

# Vite Plugins

Extend Vite with plugins for framework support, code transforms, virtual modules, and build customization.

## When to Use

- Adding framework support (React, Vue, Svelte, Solid) to a Vite project
- Enabling legacy browser support for older browsers without ESM
- Writing a custom transform plugin (e.g., code injection, macro expansion)
- Creating virtual modules for build-time code generation
- Controlling plugin execution order with `enforce`
- Restricting a plugin to dev-only or build-only with `apply`
- Integrating Rollup plugins into a Vite project

## Official Plugin Quick Reference

| Plugin | Package | Install | Purpose |
|--------|---------|---------|---------|
| React | `@vitejs/plugin-react` | `npm i -D @vitejs/plugin-react` | JSX/TSX via Oxc Transformer + Fast Refresh |
| React SWC | `@vitejs/plugin-react-swc` | `npm i -D @vitejs/plugin-react-swc` | JSX/TSX via SWC + Fast Refresh (faster) |
| Vue 3 | `@vitejs/plugin-vue` | `npm i -D @vitejs/plugin-vue` | Single File Component (.vue) compilation |
| Vue JSX | `@vitejs/plugin-vue-jsx` | `npm i -D @vitejs/plugin-vue-jsx` | Vue 3 JSX/TSX support |
| Legacy | `@vitejs/plugin-legacy` | `npm i -D @vitejs/plugin-legacy terser` | Legacy browser chunks via Babel + SystemJS |
| RSC | `@vitejs/plugin-rsc` | `npm i -D @vitejs/plugin-rsc` | Experimental React Server Components |

## Workflow: Adding a Plugin

1. **Install the package:**

```bash
npm install -D @vitejs/plugin-react
```

2. **Import and register in vite.config.ts:**

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [
    react(),
  ],
});
```

3. **Pass options if needed:**

```typescript
react({
  babel: {
    plugins: ['babel-plugin-styled-components'],
  },
})
```

4. **Verify:** Run `npx vite` and confirm the dev server starts without errors.

## Adding Multiple Plugins

The `plugins` array is flattened, so nested arrays and falsy values are ignored. This enables conditional plugins:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import legacy from '@vitejs/plugin-legacy';

const needsLegacy = process.env.SUPPORT_LEGACY === 'true';

export default defineConfig({
  plugins: [
    react(),
    needsLegacy && legacy({
      targets: ['defaults', 'not IE 11'],
    }),
  ],
});
```

## Plugin Ordering with `enforce`

Vite runs plugins in this order:

1. Alias resolution (Vite internal)
2. Plugins with `enforce: 'pre'`
3. Vite core plugins (esbuild transforms, CSS, etc.)
4. Plugins without `enforce` (normal)
5. Vite build plugins
6. Plugins with `enforce: 'post'`
7. Vite post-build plugins (minify, manifest, reporting)

Example — run a plugin before Vite core:

```typescript
import type { Plugin } from 'vite';

function rawSourceLogger(): Plugin {
  return {
    name: 'raw-source-logger',
    enforce: 'pre',
    transform(code, id) {
      if (id.endsWith('.vue')) {
        console.log(`[pre] Transforming: ${id} (${code.length} chars)`);
      }
    },
  };
}
```

## Conditional Application with `apply`

Restrict a plugin to only dev or only build:

```typescript
function devLoggerPlugin(): Plugin {
  return {
    name: 'dev-logger',
    apply: 'serve',  // Only runs during `vite dev`
    configureServer(server) {
      server.middlewares.use((req, _res, next) => {
        console.log(`[dev] ${req.method} ${req.url}`);
        next();
      });
    },
  };
}

function buildAnalyzerPlugin(): Plugin {
  return {
    name: 'build-analyzer',
    apply: 'build',  // Only runs during `vite build`
    generateBundle(_options, bundle) {
      const sizes = Object.entries(bundle).map(([name, chunk]) => ({
        name,
        size: 'code' in chunk ? chunk.code.length : 0,
      }));
      console.table(sizes);
    },
  };
}
```

For fine-grained control, `apply` can be a function:

```typescript
apply(config, { command }) {
  // Only apply during non-SSR builds
  return command === 'build' && !config.build?.ssr;
}
```

## Writing a Custom Plugin

A Vite plugin is a factory function that returns an object with a `name` and hook methods.

### Simple Transform Plugin

```typescript
import type { Plugin } from 'vite';

function timestampPlugin(): Plugin {
  return {
    name: 'vite-plugin-timestamp',
    transform(code, id) {
      if (!id.endsWith('.ts') && !id.endsWith('.tsx')) return;

      const transformed = code.replace(
        /__BUILD_TIMESTAMP__/g,
        JSON.stringify(new Date().toISOString())
      );

      if (transformed === code) return; // No changes

      return {
        code: transformed,
        map: null,  // Return null if you cannot produce a sourcemap
      };
    },
  };
}

export default timestampPlugin;
```

### HTML Injection Plugin

```typescript
function analyticsPlugin(trackingId: string): Plugin {
  return {
    name: 'vite-plugin-analytics',
    transformIndexHtml(html) {
      return {
        html,
        tags: [
          {
            tag: 'script',
            attrs: { src: `https://analytics.example.com/${trackingId}.js`, defer: true },
            injectTo: 'head',
          },
        ],
      };
    },
  };
}
```

### Dev Server Middleware Plugin

```typescript
function apiMockPlugin(): Plugin {
  return {
    name: 'vite-plugin-api-mock',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use('/api/health', (_req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ status: 'ok' }));
      });
    },
  };
}
```

## Virtual Modules

Virtual modules serve synthetic content that does not exist on disk. Convention: prefix IDs with `virtual:` and resolve with `\0`.

```typescript
function envPlugin(vars: Record<string, string>): Plugin {
  const virtualId = 'virtual:env';
  const resolvedId = '\0' + virtualId;

  return {
    name: 'vite-plugin-env',
    resolveId(id) {
      if (id === virtualId) return resolvedId;
    },
    load(id) {
      if (id === resolvedId) {
        const entries = Object.entries(vars)
          .map(([k, v]) => `export const ${k} = ${JSON.stringify(v)};`)
          .join('\n');
        return entries;
      }
    },
  };
}
```

Consume in application code:

```typescript
import { API_URL, APP_NAME } from 'virtual:env';
```

Declare types in `env.d.ts` or `vite-env.d.ts`:

```typescript
declare module 'virtual:env' {
  export const API_URL: string;
  export const APP_NAME: string;
}
```

## Hook Reference

| Hook | Stage | Signature | Return |
|------|-------|-----------|--------|
| `config` | config | `(config, env) => UserConfig \| void` | Merge partial config |
| `configResolved` | config | `(resolvedConfig) => void` | Read-only final config |
| `configureServer` | dev | `(server) => void \| (() => void)` | Add middleware (return fn for post-middleware) |
| `transformIndexHtml` | both | `(html, ctx) => string \| HtmlTagDescriptor[]` | Modified HTML or tag descriptors |
| `resolveId` | both | `(source, importer, opts) => string \| null` | Resolved ID or null to defer |
| `load` | both | `(id) => string \| null` | Module source or null to defer |
| `transform` | both | `(code, id) => TransformResult \| null` | `{ code, map }` or null to skip |
| `handleHotUpdate` | dev | `(ctx) => Module[] \| void` | Custom HMR boundary modules |
| `buildStart` | build | `(options) => void` | Setup before build |
| `generateBundle` | build | `(options, bundle) => void` | Post-process or emit files |
| `closeBundle` | build | `() => void` | Cleanup after write |

## Rollup Plugin Compatibility

Rollup plugins work directly in Vite's `plugins` array if they only use these hooks:
`buildStart`, `resolveId`, `load`, `transform`, `buildEnd`, `generateBundle`, `closeBundle`.

Plugins using Rollup-only hooks (`moduleParsed`, `renderChunk`, `augmentChunkHash`, etc.) must go in `build.rollupOptions.plugins`:

```typescript
import commonjs from '@rollup/plugin-commonjs';

export default defineConfig({
  build: {
    rollupOptions: {
      plugins: [
        commonjs(),  // Uses Rollup-only hooks
      ],
    },
  },
});
```

Check compatibility: [vite-rollup-plugins.patak.dev](https://vite-rollup-plugins.patak.dev/).

## Community Plugin Registry

Browse at [registry.vite.dev/plugins](https://registry.vite.dev/plugins).

Popular community plugins:

| Plugin | Purpose |
|--------|---------|
| `vite-plugin-pwa` | Progressive Web App with service worker |
| `unplugin-auto-import` | Auto-import APIs (Vue Composition, React hooks) |
| `unplugin-vue-components` | Auto-register Vue components |
| `vite-plugin-svgr` | Import SVGs as React components |
| `vite-plugin-dts` | Emit `.d.ts` for library mode |
| `vite-plugin-checker` | TypeScript / ESLint checking in worker thread |
| `vite-plugin-pages` | File-system based routing |
| `vite-plugin-compression` | gzip/brotli compression for build output |

## Edge Cases

- **Plugin name must be unique** — duplicate names cause warnings and unpredictable hook ordering.
- **Always call the factory** — `plugins: [react]` is wrong; use `plugins: [react()]`.
- **`transform` must return `{ code, map }`** — returning just a string silently drops sourcemaps. Return `map: null` if you cannot produce one.
- **Virtual module `\0` prefix** — the `\0` prefix in `resolveId` return is required to signal "virtual" to the pipeline. Without it, other plugins may try to resolve the ID as a file path.
- **`configureServer` return value** — returning a function from `configureServer` registers it as post-internal-middleware (runs after Vite's own static file serving).
- **HMR in plugins** — `handleHotUpdate` receives the changed modules; return a filtered array to narrow the HMR boundary, or an empty array to suppress the update entirely.
- **Async hooks** — all hooks can be async. Return a Promise and Vite will await it.
- **Plugin in monorepo** — if authoring a plugin as a separate package, ensure it is linked or published before Vite resolves it.
- **`enforce: 'pre'` + `transform`** — your transform receives the raw source before Vite's built-in transforms (TypeScript, JSX). The code may still contain TypeScript syntax.
