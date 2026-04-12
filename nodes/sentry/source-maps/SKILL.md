---
name: source-maps
description: Upload source maps to Sentry for readable production stack traces using build plugins or sentry-cli. Use when stack traces are minified, setting up CI source map uploads, or configuring build tool plugins.
---

# Sentry Source Maps

Upload source maps to Sentry so minified production stack traces resolve to readable original source code.

## Prerequisites

- Sentry SDK initialized with a `release` identifier (see sentry/setup)
- A Sentry auth token with **Project: Read & Write** and **Release: Admin** scopes
- Organization and project slugs from your Sentry dashboard
- A build process that generates source maps

## Workflow

1. **Choose upload method** — build plugin (recommended) or sentry-cli
2. **Configure auth** — set `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`
3. **Enable source map generation** — `sourcemap: "hidden"` in build config
4. **Upload during build** — plugin uploads automatically; CLI runs in CI
5. **Delete source maps from deployment** — prevent exposing original source
6. **Verify** — trigger an error and confirm the stack trace is readable

## Method 1: Build Plugins (Recommended)

### Vite

```bash
npm install @sentry/vite-plugin --save-dev
```

```javascript
// vite.config.js
import { defineConfig } from "vite";
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default defineConfig({
  build: {
    sourcemap: "hidden",
  },
  plugins: [
    // MUST be the LAST plugin
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
      sourcemaps: {
        filesToDeleteAfterUpload: ["./**/*.map"],
      },
    }),
  ],
});
```

### Webpack

```bash
npm install @sentry/webpack-plugin --save-dev
```

```javascript
const { sentryWebpackPlugin } = require("@sentry/webpack-plugin");

module.exports = {
  devtool: "source-map",
  plugins: [
    sentryWebpackPlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
    }),
  ],
};
```

### Rollup / esbuild

Same pattern — install `@sentry/rollup-plugin` or `@sentry/esbuild-plugin` and add to plugins array with `org`, `project`, `authToken`.

## Method 2: sentry-cli

For CI pipelines or unsupported build tools:

```bash
npm install @sentry/cli --save-dev

export SENTRY_AUTH_TOKEN="sntrys_..."
export SENTRY_ORG="my-org"
export SENTRY_PROJECT="my-project"

# Inject Debug IDs into source files and maps
sentry-cli sourcemaps inject ./dist

# Upload source maps
sentry-cli sourcemaps upload ./dist
```

Full release flow:

```bash
VERSION=$(sentry-cli releases propose-version)
sentry-cli releases new "$VERSION"
sentry-cli releases set-commits "$VERSION" --auto
sentry-cli sourcemaps inject ./dist
sentry-cli sourcemaps upload --release="$VERSION" ./dist
sentry-cli releases finalize "$VERSION"
sentry-cli deploys new --release="$VERSION" -e production
```

## Method 3: Sentry Wizard

Auto-detects your build tool and configures everything:

```bash
npx @sentry/wizard@latest -i sourcemaps
```

## Auth Token Setup

Create a token at `sentry.io/settings/auth-tokens/` with:
- **Project: Read & Write**
- **Release: Admin**

Store as `SENTRY_AUTH_TOKEN` in CI secrets. Build plugins also accept a `.env.sentry-build-plugin` file (never commit this).

## Security

Source maps contain your original source code. After uploading:

1. Delete `.map` files from your deployment (`filesToDeleteAfterUpload`)
2. Use `sourcemap: "hidden"` to avoid `//# sourceMappingURL` references
3. Verify `https://your-app.com/assets/main.js.map` returns 404

## Edge Cases

- **Release mismatch** — the `release` in `Sentry.init()` must exactly match the release used during upload
- **Debug IDs missing** — always run `sentry-cli sourcemaps inject` before `upload`
- **Plugin ordering** — Sentry build plugins must be last in the plugins array
- **Dev mode** — plugins skip uploads during development/watch mode; test with production builds
- **Monorepos** — upload source maps per deployable package, not once for the entire repo
- **Next.js** — `withSentryConfig()` handles source map uploads automatically

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Minified stack traces | Verify source maps are uploaded (Settings → Source Maps) |
| "Authentication failed" | Regenerate token at sentry.io/settings/auth-tokens/ |
| "No source maps found" | Check that `./dist` contains `.map` files |
| Maps uploaded, still minified | Ensure `release` in init matches upload release |
| Debug IDs not found | Run `sentry-cli sourcemaps inject` before upload |
