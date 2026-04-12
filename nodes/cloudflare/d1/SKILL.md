---
name: d1
description: >
  Manage Cloudflare D1 serverless SQLite databases — create databases, run migrations,
  execute SQL queries. Use when building applications that need relational data storage
  at the edge with full SQL support.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-database
---

# Cloudflare D1

Serverless SQLite at the edge with automatic replication and migration support.

## When to Use

- Storing relational data for Workers applications
- User accounts, application state, content management
- Any use case requiring SQL queries, joins, and transactions
- Edge-native data storage with low-latency reads

## When NOT to Use

- Simple key-value lookups (use KV instead)
- Large file storage (use R2)
- Applications requiring Postgres/MySQL-specific features

## Prerequisites

- Wrangler CLI installed
- `CLOUDFLARE_API_TOKEN` with D1 Edit permission
- `CLOUDFLARE_ACCOUNT_ID`

## Workflow

### 1. Create Database

```bash
wrangler d1 create my-app-db
```

### 2. Add Binding

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-app-db"
database_id = "from-create-output"
```

### 3. Create Migration

```bash
wrangler d1 migrations create my-app-db init
```

```sql
-- migrations/0001_init.sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX idx_users_email ON users(email);
```

### 4. Apply Migration

```bash
# Local (development)
wrangler d1 migrations apply my-app-db --local

# Remote (production)
wrangler d1 migrations apply my-app-db --remote
```

### 5. Query in Worker

```typescript
export interface Env { DB: D1Database; }

export default {
  async fetch(request: Request, env: Env) {
    // Select all
    const { results } = await env.DB.prepare(
      'SELECT * FROM users ORDER BY created_at DESC LIMIT ?'
    ).bind(50).all();

    // Select one
    const user = await env.DB.prepare(
      'SELECT * FROM users WHERE id = ?'
    ).bind(1).first();

    // Insert
    const { meta } = await env.DB.prepare(
      'INSERT INTO users (email, name) VALUES (?, ?)'
    ).bind('alice@example.com', 'Alice').run();

    // Batch (transaction)
    await env.DB.batch([
      env.DB.prepare('INSERT INTO users (email, name) VALUES (?, ?)').bind('a@b.com', 'A'),
      env.DB.prepare('INSERT INTO users (email, name) VALUES (?, ?)').bind('c@d.com', 'B'),
    ]);

    return Response.json(results);
  },
};
```

### 6. CLI Queries

```bash
wrangler d1 execute my-app-db --remote --command "SELECT count(*) FROM users"
wrangler d1 execute my-app-db --remote --file ./seed.sql
```

## API Methods

| Method | Returns | Use |
|--------|---------|-----|
| `.all()` | `{ results, meta }` | All matching rows |
| `.first()` | Row object or null | Single row |
| `.first('col')` | Column value | Single value |
| `.run()` | `{ meta }` | INSERT/UPDATE/DELETE |
| `.raw()` | Array of arrays | Raw row data |
| `.batch([])` | Array of results | Transaction |

## Limits

| Resource | Free | Paid |
|----------|------|------|
| Database size | 500MB | 10GB |
| Rows read/day | 5M | $0.001/M |
| Rows written/day | 100K | $1.00/M |
| Databases/account | 50 | 50,000 |

## Edge Cases

- Always use parameterized queries (`.bind()`) — never string concatenation.
- `batch()` is the only way to get transactions in D1.
- D1 uses SQLite semantics — `INTEGER PRIMARY KEY` is the rowid alias.
- `datetime('now')` returns UTC timestamp as ISO string.
- Migrations are applied in filename order — prefix with sequential numbers.
- Use `--local` during development to avoid hitting production data.
