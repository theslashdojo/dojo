---
name: app-router
description: Build Next.js apps with the App Router — file-based routing, layouts, Server Components, streaming, and loading states. Use when creating routes, pages, layouts, or organizing a Next.js app directory.
---

# App Router

Build Next.js applications using the App Router with file-system based routing and React Server Components.

## When to Use

- Creating a new Next.js page or route
- Setting up nested layouts for shared UI
- Adding loading states or error boundaries
- Organizing routes with route groups
- Creating dynamic routes with parameters
- Building dashboards with parallel routes
- Setting up modal intercepting routes

## Workflow

1. Identify the URL path you need (e.g., `/blog/my-post`)
2. Create the corresponding directory structure under `app/`
3. Add `page.tsx` for the route UI
4. Add `layout.tsx` if the route needs shared wrapping UI
5. Add `loading.tsx` for streaming fallback
6. Add `error.tsx` for error handling
7. Use Server Components by default; add `'use client'` only for interactivity

## File Convention Reference

| File | Purpose | Required |
|------|---------|----------|
| `page.tsx` | Route UI — makes path accessible | Yes (for visible routes) |
| `layout.tsx` | Shared wrapper — persists on navigation | Yes (root only) |
| `loading.tsx` | Suspense fallback while loading | No |
| `error.tsx` | Error boundary (must be 'use client') | No |
| `not-found.tsx` | 404 UI | No |
| `template.tsx` | Re-renders on every navigation | No |
| `route.ts` | API endpoint (cannot coexist with page.tsx) | No |
| `default.tsx` | Parallel route fallback | No |

## Creating a Basic Page

```tsx
// app/about/page.tsx → /about
export default function AboutPage() {
  return (
    <div>
      <h1>About Us</h1>
      <p>We build things.</p>
    </div>
  )
}
```

## Dynamic Routes

```tsx
// app/blog/[slug]/page.tsx → /blog/:slug
export default async function BlogPost({
  params,
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
  const post = await getPost(slug)

  return (
    <article>
      <h1>{post.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: post.html }} />
    </article>
  )
}

// Generate static paths at build time
export async function generateStaticParams() {
  const posts = await getAllPosts()
  return posts.map((post) => ({ slug: post.slug }))
}
```

## Nested Layouts

```tsx
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="flex">
      <aside className="w-64">
        <nav>
          <a href="/dashboard">Overview</a>
          <a href="/dashboard/settings">Settings</a>
        </nav>
      </aside>
      <main className="flex-1">{children}</main>
    </div>
  )
}
```

## Route Groups

```
app/
  (marketing)/
    layout.tsx       ← Marketing layout (no auth)
    page.tsx         ← / (home)
    pricing/page.tsx ← /pricing
  (app)/
    layout.tsx       ← App layout (with auth)
    dashboard/page.tsx ← /dashboard
```

## Error Handling

```tsx
// app/dashboard/error.tsx
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div role="alert">
      <h2>Dashboard error</h2>
      <p>{error.message}</p>
      <button onClick={() => reset()}>Retry</button>
    </div>
  )
}
```

## Loading States

```tsx
// app/dashboard/loading.tsx
export default function Loading() {
  return (
    <div className="animate-pulse">
      <div className="h-8 bg-gray-200 rounded w-1/3 mb-4" />
      <div className="h-4 bg-gray-200 rounded w-full mb-2" />
      <div className="h-4 bg-gray-200 rounded w-2/3" />
    </div>
  )
}
```

## Metadata

```tsx
// Static metadata
export const metadata = {
  title: 'Dashboard',
  description: 'Your dashboard overview',
}

// Dynamic metadata
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
  const post = await getPost(slug)
  return {
    title: post.title,
    openGraph: { images: [post.ogImage] },
  }
}
```

## Edge Cases

- `page.tsx` and `route.ts` cannot coexist in the same directory
- Root layout must include `<html>` and `<body>` tags
- `error.tsx` must be a Client Component (`'use client'`)
- `params` in Next.js 15+ is a Promise — must be awaited
- `searchParams` in page components is also a Promise in Next.js 15+
- Layouts do NOT re-render when navigating between child routes
- Templates DO re-render on every navigation (use for animations, per-page state)
- Route groups `(name)` should not resolve to the same URL path
- Private folders `_name` are excluded from routing entirely
