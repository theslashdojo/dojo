---
name: kv
description: >
  Manage Cloudflare Workers KV key-value storage — create namespaces, read, write, list,
  and delete keys. Use when storing configuration, feature flags, cached data, or any
  key-value data that Workers need to access globally.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-storage
---

# Workers KV

Globally distributed, eventually consistent key-value storage for Cloudflare Workers.

## When to Use

- Storing configuration or feature flags
- Caching API responses or computed data
- Serving static assets or content
- Session data with TTL expiration
- Any read-heavy key-value workload

## When NOT to Use

- Counters or increments (use Durable Objects)
- Real-time collaboration state
- Data requiring strong consistency
- Large objects > 25MB (use R2)

## Prerequisites

- Wrangler CLI installed
- `CLOUDFLARE_API_TOKEN` with Workers KV Storage:Edit permission
- `CLOUDFLARE_ACCOUNT_ID`

## Workflow

### 1. Create a Namespace

```bash
wrangler kv namespace create MY_KV
# Copy the output binding to wrangler.toml
```

### 2. Add Binding to wrangler.toml

```toml
[[kv_namespaces]]
binding = "MY_KV"
id = "output-id-here"
```

### 3. Use in Worker

```typescript
export interface Env { MY_KV: KVNamespace; }

export default {
  async fetch(request: Request, env: Env) {
    // Write
    await env.MY_KV.put('user:123', JSON.stringify({ name: 'Alice' }));

    // Read
    const user = await env.MY_KV.get('user:123', 'json');

    // Write with TTL (auto-expire in 1 hour)
    await env.MY_KV.put('session:abc', 'token', { expirationTtl: 3600 });

    // Delete
    await env.MY_KV.delete('session:abc');

    // List keys by prefix
    const { keys } = await env.MY_KV.list({ prefix: 'user:' });

    return Response.json({ user, keys: keys.map(k => k.name) });
  },
};
```

### 4. CLI Operations

```bash
# Write
wrangler kv key put --namespace-id <id> "key" "value"

# Read
wrangler kv key get --namespace-id <id> "key"

# List
wrangler kv key list --namespace-id <id> --prefix "user:"

# Bulk write
wrangler kv bulk put --namespace-id <id> data.json
```

## Limits

| Resource | Free | Paid |
|----------|------|------|
| Reads/day | 100,000 | $0.50/million |
| Writes/day | 1,000 | $5.00/million |
| Max value size | 25MB | 25MB |
| Max key size | 512 bytes | 512 bytes |
| Metadata size | 1KB | 1KB |
| Namespaces/account | 100 | 100 |

## Edge Cases

- Writes take up to 60 seconds to propagate globally (eventually consistent).
- Same-location reads after writes are immediately consistent.
- `list()` returns max 1000 keys per call — use cursor for pagination.
- `getWithMetadata()` returns both value and metadata in one call.
- Metadata is free to read (included in list results without reading values).
