---
name: build
description: Build production bundles with Vite — use when creating optimized builds, configuring code splitting, building libraries, setting up SSR, or customizing minification
---

# Vite Build — Production Bundles

Vite's `vite build` command bundles your project for production using Rolldown, producing optimized, tree-shaken, code-split output with hashed filenames.

## When to Use

- Building a Vite project for production deployment
- Configuring build targets for specific browsers or ES versions
- Creating a distributable npm library with Vite (library mode)
- Setting up server-side rendering (SSR) builds
- Customizing minification, sourcemaps, or chunk splitting
- Generating a build manifest for backend integration (Rails, Laravel, Django)
- Previewing a production build locally before deploying

## When NOT to Use

- Development iteration -- use `vite dev` (the dev server) instead
- Non-Vite projects -- use the project's own build tool (webpack, esbuild, etc.)
- Type checking -- Vite only transpiles TypeScript; use `tsc` for type checking
- E2E testing of the built app -- use Playwright or Cypress against the preview server

## Quick Reference CLI

```bash
# Standard production build
vite build

# With source maps
vite build --sourcemap

# Custom mode (loads .env.staging)
vite build --mode staging

# Custom output directory
vite build --outDir build

# Watch mode (rebuild on changes)
vite build --watch

# SSR server bundle
vite build --ssr src/entry-server.ts

# Preview the production build locally
vite preview
vite preview --port 8080
vite preview --host 0.0.0.0
```

## Workflow: Basic Application Build

1. Ensure `vite.config.ts` exists with your plugins and build options
2. Run `vite build` -- outputs to `dist/` by default
3. Verify with `vite preview` -- serves `dist/` on port 4173
4. Deploy the contents of `dist/` to your hosting provider

```bash
npm run build        # or: npx vite build
npx vite preview     # verify locally
```

Output structure:

```
dist/
  index.html
  assets/
    main-BkH2gR4a.js        # Hashed JS bundle
    main-DiwrgTda.css        # Extracted CSS
    vendor-C7BkSa0T.js       # Vendor chunk (if code-split)
    logo-a1b2c3d4.svg        # Hashed static assets
  favicon.ico                # Copied from public/
```

## Workflow: Library Build

Build a reusable npm package instead of an application.

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'src/index.ts'),
      name: 'MyLib',                  // Global name for UMD/IIFE
      formats: ['es', 'cjs', 'umd'],
      fileName: (format) => `my-lib.${format}.js`,
    },
    rollupOptions: {
      // Do not bundle peer dependencies
      external: ['react', 'react-dom'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
        },
      },
    },
  },
});
```

Configure package.json for dual publishing:

```json
{
  "name": "my-lib",
  "type": "module",
  "main": "dist/my-lib.cjs.js",
  "module": "dist/my-lib.es.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/my-lib.es.js",
      "require": "./dist/my-lib.cjs.js"
    }
  },
  "files": ["dist"]
}
```

Generate type declarations separately:

```bash
tsc --emitDeclarationOnly --declaration --outDir dist
```

## Workflow: SSR Build

Produce both client and server bundles for server-side rendering.

```bash
# 1. Build client bundle
vite build --outDir dist/client

# 2. Build server bundle
vite build --outDir dist/server --ssr src/entry-server.ts
```

SSR config:

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    target: 'node20',
    ssrManifest: true,     // Module-to-preload mapping
    manifest: true,        // Asset hashing manifest
  },
});
```

The SSR manifest maps modules to their preload directives so the server can inject `<link rel="modulepreload">` tags into the HTML response.

## Workflow: Custom Build Targets

Control the JavaScript syntax level of the output.

```typescript
export default defineConfig({
  build: {
    // Default: broadly supported modern features
    target: 'baseline-widely-available',

    // Specific ES version
    target: 'es2020',

    // Target specific browsers
    target: ['chrome100', 'firefox115', 'safari16'],

    // Bleed-edge (no downleveling)
    target: 'esnext',
  },
});
```

For browsers that need polyfills (IE11, old mobile Safari):

```bash
npm install -D @vitejs/plugin-legacy
```

```typescript
import legacy from '@vitejs/plugin-legacy';

export default defineConfig({
  plugins: [
    legacy({
      targets: ['defaults', 'not IE 11'],
    }),
  ],
});
```

## Build Configuration Reference

### Minification

```typescript
export default defineConfig({
  build: {
    // 'oxc' — default, Rust-based, 30-90x faster than terser
    minify: 'oxc',

    // 'terser' — maximum compression, requires: npm i -D terser
    minify: 'terser',

    // 'esbuild' — fast Go-based minifier (former default)
    minify: 'esbuild',

    // false — skip minification entirely
    minify: false,

    // CSS minification (separate from JS)
    cssMinify: 'lightningcss',   // default, fast Rust-based
    cssMinify: 'esbuild',        // alternative
    cssMinify: false,             // disable
  },
});
```

### Source Maps

```typescript
export default defineConfig({
  build: {
    sourcemap: false,     // No maps (default, smallest output)
    sourcemap: true,      // Separate .map files
    sourcemap: 'inline',  // Embedded in JS (large, debug only)
    sourcemap: 'hidden',  // .map files without URL reference
                          // Best for Sentry/Datadog upload
  },
});
```

### Code Splitting

```typescript
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        // Object form: named chunks
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          ui: ['@radix-ui/react-dialog', '@radix-ui/react-popover'],
        },

        // Function form: dynamic chunking
        manualChunks(id) {
          if (id.includes('node_modules')) {
            return 'vendor';
          }
        },
      },
    },
    chunkSizeWarningLimit: 500,  // Warn on chunks > 500kB
    cssCodeSplit: true,          // Separate CSS per async chunk
  },
});
```

### Build Manifest

```typescript
export default defineConfig({
  build: {
    manifest: true,   // .vite/manifest.json
  },
});
```

The manifest maps source paths to hashed output:

```json
{
  "src/main.tsx": {
    "file": "assets/main-BkH2gR4a.js",
    "src": "src/main.tsx",
    "isEntry": true,
    "css": ["assets/main-DiwrgTda.css"]
  }
}
```

Backend templates use this to inject the correct `<script>` and `<link>` tags.

### Asset Handling

```typescript
export default defineConfig({
  build: {
    assetsDir: 'assets',          // Subdirectory for assets
    assetsInlineLimit: 4096,      // Inline assets < 4kB as base64
    copyPublicDir: true,          // Copy public/ to outDir root
  },
});
```

## Build Output Analysis

After building, check output size:

```bash
# Vite prints a size summary after build
npx vite build

# Analyze bundle visually with rollup-plugin-visualizer
npm install -D rollup-plugin-visualizer
```

```typescript
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    visualizer({
      open: true,
      filename: 'stats.html',
      gzipSize: true,
    }),
  ],
});
```

Disable compressed size reporting for faster builds on large projects:

```typescript
export default defineConfig({
  build: {
    reportCompressedSize: false,
  },
});
```

## package.json Scripts

```json
{
  "scripts": {
    "build": "vite build",
    "build:staging": "vite build --mode staging",
    "build:analyze": "vite build && npx vite-bundle-visualizer",
    "preview": "vite preview",
    "build:ssr:client": "vite build --outDir dist/client",
    "build:ssr:server": "vite build --outDir dist/server --ssr src/entry-server.ts"
  }
}
```

## Edge Cases and Gotchas

- **Empty dist/ on rebuild**: `emptyOutDir` defaults to `true` only when `outDir` is inside the project root. If `outDir` is outside the root Vite refuses to empty it unless you explicitly set `emptyOutDir: true`.
- **Library mode externals**: Forgetting to externalize peer dependencies (React, Vue) bundles them into your library, causing duplicate framework instances for consumers.
- **Library mode and CSS**: By default library builds do not extract CSS into a separate file. Consumers must import the CSS entry or you need to configure CSS injection.
- **UMD global name**: The `name` field in `build.lib` is required for UMD and IIFE formats. It becomes the global variable name (e.g., `window.MyLib`).
- **Terser not installed**: Setting `minify: 'terser'` without installing the terser package causes a build error. Install it: `npm i -D terser`.
- **Source maps in production**: Enabling `sourcemap: true` exposes source code to anyone with browser devtools. Use `'hidden'` to generate maps for error tracking without client exposure.
- **manualChunks circular dependency**: A `manualChunks` function that assigns the same module to multiple chunks causes build errors. Each module can belong to only one chunk.
- **SSR external modules**: In SSR mode Vite externalizes bare module imports by default. If an SSR dependency ships untranspiled ESM that uses browser APIs, you may need to add it to `ssr.noExternal`.
- **reportCompressedSize slows builds**: On large projects the gzip size calculation adds noticeable build time. Set `reportCompressedSize: false` for faster CI builds.
- **Public directory not processed**: Files in `public/` are copied verbatim -- they are not processed, hashed, or tree-shaken. Do not import from `public/`; use `src/assets/` for processed assets.
- **Watch mode and CI**: `build.watch` keeps the process alive. Never enable it in CI pipelines or it will hang indefinitely.
- **Multi-page apps**: For multi-page apps pass multiple HTML entry points via `build.rollupOptions.input` as an object mapping names to HTML file paths.
