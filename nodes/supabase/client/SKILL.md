---
name: client
description: Initialize and configure @supabase/supabase-js client SDK with type safety. Use when setting up Supabase in any JavaScript/TypeScript app, configuring SSR with @supabase/ssr, or creating service role clients.
---

# Supabase Client SDK

## When to Use
- Setting up Supabase in a new or existing app
- Configuring server-side rendering with Next.js, SvelteKit, Remix
- Creating a service role client for admin operations
- Deciding between anon key and service role key

## Prerequisites
- `npm install @supabase/supabase-js`
- For SSR: `npm install @supabase/ssr`
- `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` environment variables

## Workflow

### 1. Install
```bash
npm install @supabase/supabase-js
# For Next.js/SvelteKit/Remix:
npm install @supabase/ssr
```

### 2. Generate types
```bash
supabase gen types typescript --local > src/types/supabase.ts
```

### 3. Create client utility
```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js';
import type { Database } from '@/types/supabase';

export const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
```

### 4. Use in components
```typescript
const { data, error } = await supabase
  .from('posts')
  .select('*')
  .order('created_at', { ascending: false });
```

## Key Rules

1. **Create once, reuse everywhere** — don't instantiate per request
2. **Anon key is public** — RLS policies protect data, not the key
3. **Service role key is secret** — never expose to browser
4. **Use @supabase/ssr for SSR** — handles cookies and session refresh
5. **Always pass Database generic** — enables full type inference
6. **Middleware refreshes sessions** — add middleware.ts in Next.js

## Edge Cases

### Token expired mid-request
The client auto-refreshes tokens. If a request fails with 401, retry once — the client will have refreshed by then.

### Multiple clients
Avoid creating multiple clients with the same credentials. If you need both anon and service role, create exactly two instances.

### Custom fetch
Pass a custom fetch for environments without global fetch (older Node.js):
```typescript
const supabase = createClient(url, key, {
  global: { fetch: nodeFetch }
});
```
