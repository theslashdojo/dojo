---
name: wrangler
description: >
  Install and use the Wrangler CLI for Cloudflare development — init, dev, deploy, tail,
  and manage Workers, KV, R2, D1, and Pages. Use when performing any Cloudflare development
  or deployment task from the command line.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-cli
---

# Wrangler CLI

The official Cloudflare CLI for the developer platform.

## When to Use

- Any Cloudflare development, testing, or deployment task
- Local Worker development with hot reload
- Managing KV, R2, D1, and Pages from the command line
- Streaming production logs
- Managing secrets and environment variables

## Prerequisites

- Node.js >= 18
- `npm install -g wrangler` or `npm install --save-dev wrangler`
- `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`

## Core Commands

### Setup

```bash
npm install -g wrangler
wrangler login            # OAuth browser flow
wrangler whoami           # Verify authentication

# Or use env vars (CI/CD, agents)
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
```

### Workers

```bash
npm create cloudflare@latest my-worker   # Scaffold project
wrangler dev                              # Local dev server
wrangler dev --remote                     # Dev with remote bindings
wrangler deploy                           # Deploy to production
wrangler deploy --env staging             # Deploy to named environment
wrangler tail my-worker                   # Stream live logs
wrangler tail my-worker --status error    # Filter error logs
wrangler secret put API_KEY               # Set encrypted secret
wrangler rollback                         # Rollback to previous version
```

### KV

```bash
wrangler kv namespace create MY_KV
wrangler kv key put --namespace-id <id> "key" "value"
wrangler kv key get --namespace-id <id> "key"
wrangler kv key list --namespace-id <id>
wrangler kv bulk put --namespace-id <id> data.json
```

### R2

```bash
wrangler r2 bucket create my-bucket
wrangler r2 object put my-bucket/file.txt --file ./file.txt
wrangler r2 object get my-bucket/file.txt --file ./out.txt
wrangler r2 object list my-bucket
```

### D1

```bash
wrangler d1 create my-db
wrangler d1 migrations create my-db init
wrangler d1 migrations apply my-db --remote
wrangler d1 execute my-db --remote --command "SELECT * FROM users"
```

### Pages

```bash
wrangler pages deploy ./dist --project-name my-site
wrangler pages project create my-site
wrangler pages secret put DB_URL --project-name my-site
```

## Configuration (wrangler.toml)

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]
account_id = "your-account-id"

[vars]
ENVIRONMENT = "production"

[[kv_namespaces]]
binding = "KV"
id = "namespace-id"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "db-id"

[triggers]
crons = ["0 * * * *"]
```

## Edge Cases

- `wrangler dev` uses Miniflare for local simulation — state in `.wrangler/state/`.
- `--remote` flag on `wrangler dev` uses actual cloud resources (KV, R2, D1).
- Secrets are per-environment — set them per `--env` if using named environments.
- `wrangler.toml` is NOT uploaded with the Worker — it's build-time configuration.
- Multiple `wrangler.toml` environments share the same file with `[env.name]` sections.
