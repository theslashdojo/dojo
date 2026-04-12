---
name: middleware
description: Run code before Next.js requests complete — authentication, redirects, rewrites, headers, and geo-routing with middleware.ts. Use when adding auth guards, URL rewrites, response headers, locale detection, A/B testing, or request logging.
---

# Middleware

Intercept and modify requests before they reach routes in Next.js.

## When to Use

- Protecting routes with authentication checks
- Redirecting users based on locale or region
- Setting security headers on all responses
- Rewriting URLs for A/B testing or proxying
- Logging requests
- Setting cookies for analytics or feature flags

## Workflow

1. Create `middleware.ts` at the project root (next to `app/` or `pages/`, or in `src/`)
2. Export a `middleware` function that receives `NextRequest`
3. Return `NextResponse.next()`, `.redirect()`, or `.rewrite()`
4. Export `config.matcher` to scope which paths trigger the middleware
5. Test with `next dev` — middleware runs on every navigation

## Authentication Guard

```tsx
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('session')?.value

  if (!token) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('callbackUrl', request.nextUrl.pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/settings/:path*', '/api/protected/:path*'],
}
```

## Security Headers

```tsx
export function middleware(request: NextRequest) {
  const response = NextResponse.next()

  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  response.headers.set(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' 'unsafe-inline'"
  )

  return response
}
```

## Locale Detection

```tsx
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  const locales = ['en', 'fr', 'de']

  const hasLocale = locales.some(l => pathname.startsWith(`/${l}`))
  if (hasLocale) return NextResponse.next()

  const lang = request.headers.get('Accept-Language') ?? ''
  const locale = locales.find(l => lang.includes(l)) ?? 'en'

  return NextResponse.rewrite(new URL(`/${locale}${pathname}`, request.url))
}
```

## Matcher Patterns

```tsx
export const config = {
  matcher: [
    // Exact path
    '/dashboard',
    // Path with wildcard
    '/dashboard/:path*',
    // Regex: exclude static files
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
```

## Edge Cases

- Only ONE `middleware.ts` file per project (at root or `src/`)
- Middleware runs on the Edge Runtime — no `fs`, `path`, or native Node.js APIs
- `request.geo` and `request.ip` only work on Vercel (undefined elsewhere)
- Middleware runs before static file serving — always use a matcher to exclude `_next/static`
- `NextResponse.redirect()` defaults to 307; use 308 for permanent redirects
- Middleware cannot directly render a page — it can only redirect, rewrite, or modify headers
- Avoid heavy computation — middleware adds latency to every matched request
- For JWT validation, use `jose` (edge-compatible), not `jsonwebtoken` (Node.js only)
- Middleware does NOT run during `next build` — only at request time
