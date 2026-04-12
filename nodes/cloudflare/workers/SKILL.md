---
name: workers
description: >
  Deploy and manage Cloudflare Workers — edge compute functions running JavaScript/TypeScript
  in V8 isolates. Use when creating API endpoints, proxies, cron jobs, or any serverless
  function that should run at the edge with sub-millisecond cold starts.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-compute
---

# Cloudflare Workers

Deploy serverless functions to Cloudflare's global edge network (300+ data centers).

## When to Use

- Deploying an API endpoint or webhook handler
- Building a proxy or middleware layer
- Running scheduled tasks (cron)
- Processing queue messages
- Serving dynamic content at the edge

## Prerequisites

- Node.js >= 18
- Wrangler CLI (`npm install -g wrangler`)
- Cloudflare account with API token (`CLOUDFLARE_API_TOKEN`)
- Account ID (`CLOUDFLARE_ACCOUNT_ID`)

## Workflow

### 1. Create a Worker Project

```bash
npm create cloudflare@latest my-worker
cd my-worker
```

### 2. Write the Worker

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/api/health') {
      return Response.json({ status: 'ok', timestamp: Date.now() });
    }

    return new Response('Not Found', { status: 404 });
  },
};
```

### 3. Configure wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]
```

### 4. Develop Locally

```bash
wrangler dev
# Worker running at http://localhost:8787
```

### 5. Deploy

```bash
wrangler deploy
# Published my-worker (https://my-worker.<subdomain>.workers.dev)
```

### 6. Monitor

```bash
wrangler tail my-worker
```

## Key Patterns

### JSON API Handler

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    const body = await request.json();
    const result = await processRequest(body, env);
    return Response.json(result);
  },
};
```

### Cron Worker

```toml
[triggers]
crons = ["0 */6 * * *"]
```

```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runJob(env));
  },
};
```

### Worker with Bindings

```toml
[[kv_namespaces]]
binding = "CACHE"
id = "namespace-id"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "db-id"
```

```typescript
export interface Env {
  CACHE: KVNamespace;
  DB: D1Database;
  API_KEY: string;
}
```

## Runtime Constraints

| Limit | Free | Paid |
|-------|------|------|
| CPU time | 10ms | 30s |
| Memory | 128MB | 128MB |
| Script size | 1MB | 10MB |
| Subrequests | 50 | 1,000 |
| Requests/day | 100K | 10M+ |

## Edge Cases

- Workers use Web Standards APIs, not Node.js. Add `nodejs_compat` flag for polyfills.
- `request.cf` provides geo data (country, city, colo) — only available in production, not `wrangler dev`.
- `ctx.waitUntil(promise)` extends Worker lifetime for background work after the response is sent.
- Secrets must be set with `wrangler secret put`, not in `wrangler.toml`.
- Local dev state persists in `.wrangler/state/` — delete to reset.

## Troubleshooting

- **Script too large**: Tree-shake dependencies, use `--minify`, move data to KV/R2.
- **CPU time exceeded**: Offload computation, cache results in KV, use `waitUntil()`.
- **Binding not found**: Check `wrangler.toml` binding names match code references.
- **Auth error**: Verify `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
