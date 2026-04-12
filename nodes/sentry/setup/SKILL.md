---
name: setup
description: Install and initialize the Sentry SDK for error tracking in browser or Node.js applications. Use when adding Sentry to a new project, switching platforms, or troubleshooting initialization.
---

# Sentry Setup

Initialize Sentry error tracking for your application. This skill installs the correct SDK package and creates an initialization file for your target platform.

## Prerequisites

- A Sentry account and project (free tier available at sentry.io)
- The project's DSN from Settings → Client Keys (DSN)
- Node.js 18+ for server-side, or any modern browser

## Workflow

1. **Identify the platform** — browser, Node.js, React, Next.js, Vue, Angular, or SvelteKit
2. **Install the SDK package** — `@sentry/browser`, `@sentry/node`, `@sentry/react`, `@sentry/nextjs`, etc.
3. **Create the instrument file** — call `Sentry.init()` with DSN, release, environment, and sample rates
4. **Wire it into the app** — import the instrument file first (before all other code)
5. **Verify** — trigger a test error and confirm it appears in the Sentry dashboard

## Platform-Specific Instructions

### Browser (Vanilla JS)

```bash
npm install @sentry/browser
```

```javascript
// src/instrument.js
import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: process.env.SENTRY_RELEASE || "my-app@1.0.0",
  environment: process.env.SENTRY_ENVIRONMENT || "production",
  tracesSampleRate: 0.2,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  replaysOnErrorSampleRate: 1.0,
});
```

Import this file first in your entry point:

```javascript
import "./instrument";
import { createApp } from "./app";
```

### Node.js

```bash
npm install @sentry/node
```

```javascript
// instrument.js
const Sentry = require("@sentry/node");

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: process.env.SENTRY_RELEASE,
  environment: process.env.SENTRY_ENVIRONMENT || "production",
  tracesSampleRate: 0.2,
  sendDefaultPii: true,
});
```

**CommonJS** — require the instrument file first:

```javascript
require("./instrument");
const express = require("express");
```

**ESM** — use the `--import` flag:

```bash
node --import ./instrument.mjs app.mjs
```

### React

```bash
npm install @sentry/react
```

```javascript
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: process.env.REACT_APP_SENTRY_DSN,
  release: process.env.REACT_APP_SENTRY_RELEASE,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  tracesSampleRate: 0.2,
  replaysOnErrorSampleRate: 1.0,
});
```

Wrap your app with the Error Boundary:

```jsx
<Sentry.ErrorBoundary fallback={<p>Something went wrong</p>}>
  <App />
</Sentry.ErrorBoundary>
```

### Next.js

Use the wizard for automatic setup:

```bash
npx @sentry/wizard@latest -i nextjs
```

Or manually install and create three config files:

```bash
npm install @sentry/nextjs
```

- `sentry.client.config.ts` — browser SDK init
- `sentry.server.config.ts` — Node.js SDK init
- `sentry.edge.config.ts` — edge runtime SDK init

Wrap `next.config.js` with `withSentryConfig()`.

## Verification

After setup, trigger a test error:

```javascript
Sentry.captureException(new Error("Sentry test — delete me"));
```

Check the Sentry Issues page within 30 seconds. If the event doesn't appear:

1. Verify the DSN is correct
2. Enable `debug: true` in `Sentry.init()` for verbose console output
3. Check the browser network tab for requests to `ingest.sentry.io`
4. Ensure `Sentry.init()` runs before the test error

## Edge Cases

- **Ad blockers** may block requests to `ingest.sentry.io` — configure a `tunnel` endpoint to proxy events through your server
- **SSR frameworks** need both client and server SDK initialization
- **Monorepos** — use the same DSN for related packages or create separate projects per deployable
- **Serverless** (AWS Lambda, Vercel Functions) — wrap handlers with `Sentry.wrapHandler()` or use framework-specific integrations
- **Node.js ESM** requires `--import` flag (Node 18.19.0+), `require()` does not work for ESM

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SENTRY_DSN` | Data Source Name for your project |
| `SENTRY_RELEASE` | Release version (e.g., `my-app@1.2.3`) |
| `SENTRY_ENVIRONMENT` | Environment name (`production`, `staging`) |
