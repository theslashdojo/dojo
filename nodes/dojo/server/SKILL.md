---
name: server
description: >
  Run and configure the Dojo registry server that serves the API, search, and
  graph endpoints. Use when starting a local Dojo instance or deploying to
  production.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-runtime
allowed-tools: Bash Read
---

# Dojo Server

Start and configure the Dojo registry server.

## When to Use

- Starting a local Dojo instance for development or testing
- Deploying the Dojo registry to production
- Debugging server startup or configuration issues
- Need the API running for SDK or CLI online mode

## Quick Start

```bash
cd server
npm install
npm run dev
# Server starts on http://localhost:3000
```

Verify:
```bash
curl http://localhost:3000/health
# → { "status": "ok", "nodes": 450, "uptime": 0 }
```

## Configuration

All configuration via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | HTTP port |
| `DOJO_NODES_DIR` | `../nodes` | Path to nodes directory |
| `DOJO_ENV` | `development` | development or production |
| `DOJO_LOG_LEVEL` | `info` | debug, info, warn, error |
| `DOJO_CORS_ORIGIN` | `*` | CORS allowed origins |
| `DOJO_AUTH_SECRET` | _(none)_ | JWT secret for publish endpoints |

## Modes

### Development
```bash
DOJO_ENV=development npm run dev
```
- Hot-reloads on node.json changes
- Verbose logging
- CORS open to all origins

### Production
```bash
DOJO_ENV=production npm start
```
- No hot-reload
- Optimized for throughput
- Set CORS and auth for security

## Startup Sequence

1. Load all node.json files from nodes directory
2. Build parent-child hierarchy
3. Index searchable fields (aliases, triggers, tags, content)
4. Build graph edges from links, related, and wiki-links
5. Compute backlinks by reversing all forward edges
6. Start HTTP listener

## Troubleshooting

- **Port in use**: Set `PORT` to a different value
- **No nodes loaded**: Check `DOJO_NODES_DIR` path is correct
- **Slow startup**: Large node trees take time to index — normal for 500+ nodes
- **Hot-reload not working**: Ensure `DOJO_ENV=development`
