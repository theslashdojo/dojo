---
name: auth
description: Implement user authentication with Supabase — sign-up, sign-in, OAuth, magic links, phone OTP, and session management. Use when adding login/signup flows, protecting routes, or integrating social auth providers.
---

# Supabase Auth

## When to Use
- Adding user authentication to an app
- Implementing OAuth (Google, GitHub, Apple, Discord, etc.)
- Setting up passwordless magic link or phone OTP
- Protecting routes based on authentication state
- Managing user sessions and token refresh

## Prerequisites
- Supabase client initialized (see supabase/client)
- OAuth providers configured in dashboard or config.toml

## Workflow

### Email/Password Auth
```typescript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'securepassword123',
});

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'securepassword123',
});
```

### OAuth
```typescript
// Redirect to provider
await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: { redirectTo: 'https://myapp.com/auth/callback' },
});

// Handle callback (exchange code for session)
const code = searchParams.get('code');
if (code) await supabase.auth.exchangeCodeForSession(code);
```

### Get Current User
```typescript
// Server-side (ALWAYS use this on server)
const { data: { user } } = await supabase.auth.getUser();

// Client-side (reads local session, NOT verified)
const { data: { session } } = await supabase.auth.getSession();
```

## Critical Rules

1. **ALWAYS use `getUser()` on the server** — `getSession()` reads from cookies without JWT verification and can be spoofed
2. **Handle the auth callback** — OAuth and magic links redirect to a callback URL; you must call `exchangeCodeForSession(code)`
3. **Set `redirectTo` correctly** — must be in the allowed redirect URLs list in dashboard settings
4. **Auth + RLS** — auth.uid() in RLS policies comes from the JWT issued by auth; no auth = no access with anon key

## Edge Cases

### Email confirmation disabled
If disabled, `signUp()` returns a session immediately. If enabled, session is null until confirmed.

### OAuth popup blocked
Use `signInWithOAuth()` which redirects (not popup). The PKCE flow handles the redirect securely.

### Token refresh race condition
The client auto-refreshes. If two tabs refresh simultaneously, both get valid tokens. The SDK handles this.

### Custom redirect URL
Must be added to "Redirect URLs" in Authentication > URL Configuration in the Supabase dashboard.
