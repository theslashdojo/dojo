---
name: pages-router
description: Build Next.js apps with the Pages Router — getStaticProps, getServerSideProps, _app.tsx, _document.tsx, and classic file-based routing. Use when working with existing Pages Router codebases or creating pages with SSG/SSR data fetching.
---

# Pages Router

Build Next.js applications using the Pages Router with file-based routing and data fetching via exported functions.

## When to Use

- Working with an existing Next.js project using `pages/` directory
- Creating pages with static generation (getStaticProps)
- Server-side rendering pages per request (getServerSideProps)
- Pre-rendering dynamic routes (getStaticPaths)
- Customizing the global app wrapper (_app.tsx)
- Modifying the HTML document structure (_document.tsx)

## Workflow

1. Create a `.tsx` file in the `pages/` directory (filename = route)
2. Export a default React component for the page UI
3. Export `getStaticProps` or `getServerSideProps` for data fetching
4. For dynamic routes (`[slug].tsx`), also export `getStaticPaths`
5. Use `_app.tsx` for global layout and providers
6. Use `_document.tsx` for HTML customization

## Data Fetching Quick Reference

| Method | When it runs | Use case |
|--------|-------------|----------|
| `getStaticProps` | Build time (+ ISR) | Blog posts, product pages, marketing |
| `getServerSideProps` | Every request | Dashboards, authenticated pages |
| `getStaticPaths` | Build time | Define dynamic routes for SSG |
| Client-side (SWR) | Browser | User-specific, frequently updated |

## Static Generation

```tsx
// pages/posts.tsx
export async function getStaticProps() {
  const res = await fetch('https://api.example.com/posts')
  const posts = await res.json()

  return {
    props: { posts },
    revalidate: 60, // ISR: regenerate every 60s
  }
}

export default function PostsPage({ posts }) {
  return (
    <ul>
      {posts.map(post => <li key={post.id}>{post.title}</li>)}
    </ul>
  )
}
```

## Server-Side Rendering

```tsx
// pages/dashboard.tsx
export async function getServerSideProps(context) {
  const { req, query } = context
  const session = await getSession(req)

  if (!session) {
    return { redirect: { destination: '/login', permanent: false } }
  }

  const data = await fetchDashboard(session.userId)
  return { props: { data } }
}

export default function Dashboard({ data }) {
  return <DashboardUI data={data} />
}
```

## Dynamic Routes

```tsx
// pages/blog/[slug].tsx
export async function getStaticPaths() {
  const posts = await getAllPosts()
  return {
    paths: posts.map(p => ({ params: { slug: p.slug } })),
    fallback: 'blocking', // SSR unknown slugs on first visit
  }
}

export async function getStaticProps({ params }) {
  const post = await getPost(params.slug)
  if (!post) return { notFound: true }
  return { props: { post }, revalidate: 300 }
}
```

## Custom App

```tsx
// pages/_app.tsx
import type { AppProps } from 'next/app'
import '@/styles/globals.css'

export default function App({ Component, pageProps }: AppProps) {
  return (
    <Providers>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </Providers>
  )
}
```

## Edge Cases

- `getStaticProps` and `getServerSideProps` cannot be used in the same page
- `getStaticPaths` requires `getStaticProps` (not `getServerSideProps`)
- `_document.tsx` only renders on the server — no event handlers or client hooks
- `_app.tsx` re-renders on every navigation — keep it lean
- Files in `pages/api/` are API routes, not pages (see nextjs/api-routes)
- `fallback: true` in getStaticPaths requires handling the loading state with `router.isFallback`
- ISR with `revalidate` only works when deployed to a platform that supports it (Vercel, self-hosted Node.js)
- The `context` in getServerSideProps includes `req`, `res`, `params`, `query`, `resolvedUrl`, `locale`
