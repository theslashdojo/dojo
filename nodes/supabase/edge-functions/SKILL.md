---
name: edge-functions
description: Create and deploy Deno-based Supabase Edge Functions for server-side logic, webhooks, and API endpoints. Use when you need server-side code that shouldn't run on the client — API proxies, webhook handlers, payment processing, or LLM calls.
---

# Supabase Edge Functions

## When to Use
- Processing webhooks (Stripe, GitHub, etc.)
- Calling third-party APIs with secret keys
- Running server-side logic (email, payments, AI)
- Creating custom API endpoints
- Admin database operations (bypassing RLS)

## Prerequisites
- Supabase CLI installed (see supabase/cli)
- Project initialized with `supabase init`

## Workflow

### 1. Create
```bash
supabase functions new my-function
```

### 2. Write handler
```typescript
// supabase/functions/my-function/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const { name } = await req.json();

  return new Response(
    JSON.stringify({ message: `Hello, ${name}!` }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
```

### 3. Develop locally
```bash
supabase functions serve
```

### 4. Set secrets
```bash
supabase secrets set MY_API_KEY=sk-...
```

### 5. Deploy
```bash
supabase functions deploy my-function
```

### 6. Invoke
```typescript
const { data, error } = await supabase.functions.invoke('my-function', {
  body: { name: 'Alice' },
});
```

## Critical Rules

1. **Always handle CORS** — browser clients need OPTIONS preflight handling
2. **Built-in env vars** — SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are auto-injected
3. **Use npm: specifiers** — `import Stripe from "npm:stripe@14"` for npm packages
4. **Service role for admin** — create a service role client inside functions for admin operations
5. **Verify webhooks** — always validate webhook signatures before processing

## Edge Cases

### Function times out
Default timeout is 60 seconds. For long-running tasks, return early and process async, or use database triggers.

### CORS errors in browser
Add OPTIONS handler and set Access-Control-Allow-Origin. The SDK handles auth headers automatically.

### Import errors
Use `npm:` prefix for npm packages and `jsr:` for JSR packages. Deno doesn't use node_modules.
