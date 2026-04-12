---
name: pages
description: >
  Deploy static sites and full-stack applications to Cloudflare Pages. Use when deploying
  web applications built with Next.js, Astro, SvelteKit, Vite, or any static site
  generator, with automatic preview deployments and Git integration.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-deploy
---

# Cloudflare Pages

Deploy static and full-stack web applications to the edge.

## When to Use

- Deploying any web application (static or full-stack)
- Need automatic preview deployments per branch/PR
- Want Git-integrated continuous deployment
- Deploying Next.js, Astro, SvelteKit, Nuxt, Remix, Hugo, or Vite apps

## Prerequisites

- Wrangler CLI installed
- `CLOUDFLARE_API_TOKEN` with Cloudflare Pages:Edit permission
- `CLOUDFLARE_ACCOUNT_ID`
- Built output directory (e.g., `./dist`, `./build`, `./out`)

## Workflow

### 1. Build Your App

```bash
npm run build
```

### 2. Deploy via CLI

```bash
# First deployment creates the project
wrangler pages deploy ./dist --project-name my-site

# Subsequent deployments
wrangler pages deploy ./dist --project-name my-site
```

### 3. Or Connect Git (Dashboard)

1. Cloudflare Dashboard > Workers & Pages > Create
2. Connect GitHub or GitLab
3. Select repository
4. Configure build command and output directory
5. Deploy

### 4. Add Server-Side Functions

```typescript
// functions/api/data.ts
export const onRequestGet: PagesFunction = async (context) => {
  return Response.json({ message: 'Hello from the edge!' });
};
```

### 5. Add Bindings

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "xxx"
```

## Framework Presets

| Framework | Build Command | Output |
|-----------|--------------|--------|
| Vite/React | `npm run build` | `dist` |
| Next.js | `npx @cloudflare/next-on-pages` | `.vercel/output/static` |
| Astro | `npm run build` | `dist` |
| SvelteKit | `npm run build` | `.svelte-kit/cloudflare` |
| Hugo | `hugo` | `public` |

## Functions Routing

```
functions/
├── api/
│   ├── hello.ts         → /api/hello
│   ├── users/
│   │   ├── index.ts     → /api/users
│   │   └── [id].ts      → /api/users/:id
│   └── [[path]].ts      → /api/* (catch-all)
└── _middleware.ts        → Runs before all routes
```

## Limits

| Resource | Free | Pro |
|----------|------|-----|
| Sites | Unlimited | Unlimited |
| Requests | Unlimited | Unlimited |
| Bandwidth | Unlimited | Unlimited |
| Builds/month | 500 | 5,000 |
| Concurrent builds | 1 | 5 |
| Max file size | 25MB | 25MB |

## Edge Cases

- Preview URLs: `<hash>.<project>.pages.dev` and `<branch>.<project>.pages.dev`.
- `_redirects` and `_headers` files in output directory for custom rules.
- Pages Functions share the same runtime constraints as Workers.
- Next.js requires `@cloudflare/next-on-pages` adapter for full compatibility.
- Environment variables set via `wrangler pages secret put` or dashboard.
