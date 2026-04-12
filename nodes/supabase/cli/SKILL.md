---
name: cli
description: Manage Supabase projects via CLI — init, local dev, migrations, edge function deployment, and type generation. Use when scaffolding projects, running local Supabase, pushing migrations, deploying functions, or generating TypeScript types.
---

# Supabase CLI

## When to Use
- Setting up a new Supabase project (local or linked to remote)
- Running local development with Docker
- Creating and applying database migrations
- Generating TypeScript types from the database schema
- Deploying edge functions
- Managing secrets for edge functions

## Prerequisites
- Node.js 18+ or Homebrew
- Docker (for `supabase start`)
- `SUPABASE_ACCESS_TOKEN` for remote operations

## Workflow

### New Project
```bash
# 1. Install CLI
npm install -g supabase

# 2. Initialize project
supabase init

# 3. Start local stack
supabase start

# 4. Open Studio
open http://localhost:54323
```

### Link Existing Project
```bash
# 1. Login
supabase login

# 2. Link
supabase link --project-ref abcdefghijklmnop

# 3. Pull remote schema
supabase db pull
```

### Migration Cycle
```bash
# 1. Make changes in Studio or SQL editor
# 2. Generate migration
supabase db diff --use-migra -f add_posts_table

# 3. Review generated SQL
cat supabase/migrations/*_add_posts_table.sql

# 4. Push to remote
supabase db push
```

### Type Generation
```bash
# From local DB
supabase gen types typescript --local > src/types/supabase.ts

# From remote (linked)
supabase gen types typescript --linked > src/types/supabase.ts
```

### Edge Function Deployment
```bash
# Create
supabase functions new my-function

# Develop locally
supabase functions serve

# Deploy
supabase functions deploy my-function

# Set secrets
supabase secrets set OPENAI_API_KEY=sk-...
```

## Common Issues

### Docker not running
`supabase start` fails with "Cannot connect to Docker daemon". Start Docker Desktop or the Docker service first.

### Port conflicts
If port 54321 is in use, edit `supabase/config.toml` to change the API port:
```toml
[api]
port = 54351
```

### Migration conflicts
If `supabase db push` fails due to conflicting migrations, use `supabase migration repair --status reverted <version>` to mark a migration as reverted, then re-push.

### Type generation stale
Always re-run `supabase gen types` after migrations. Add it to your migration script:
```json
{
  "scripts": {
    "db:push": "supabase db push && supabase gen types typescript --linked > src/types/supabase.ts"
  }
}
```
