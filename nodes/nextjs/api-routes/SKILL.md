---
name: api-routes
description: Build API endpoints in Next.js — Route Handlers (App Router) and API Routes (Pages Router) for REST, webhooks, and backend logic. Use when creating API endpoints, handling HTTP requests, building REST APIs, or processing webhooks.
---

# API Routes

Build backend API endpoints inside your Next.js application.

## When to Use

- Creating REST API endpoints
- Handling webhook callbacks
- Building backend-for-frontend (BFF) APIs
- Processing form submissions (alternative: Server Actions)
- Serving dynamic data to client components
- Streaming responses (SSE, NDJSON)

## Workflow

### App Router (Route Handlers)

1. Create `route.ts` in the desired `app/` directory path
2. Export named functions for HTTP methods (`GET`, `POST`, etc.)
3. Use `NextRequest` for request helpers, `NextResponse` for response helpers
4. For dynamic routes, create `[param]/route.ts` directories

### Pages Router (API Routes)

1. Create a `.ts` file in `pages/api/`
2. Export a default handler function
3. Switch on `req.method` for different HTTP methods
4. Use `req.body`, `req.query` for input; `res.json()`, `res.status()` for output

## Route Handler Examples (App Router)

### CRUD Endpoint

```tsx
// app/api/items/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl
  const page = parseInt(searchParams.get('page') ?? '1')
  const items = await db.item.findMany({ skip: (page - 1) * 20, take: 20 })
  return NextResponse.json(items)
}

export async function POST(request: NextRequest) {
  const body = await request.json()
  const item = await db.item.create({ data: body })
  return NextResponse.json(item, { status: 201 })
}
```

### With Authentication

```tsx
// app/api/protected/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

export async function GET(request: NextRequest) {
  const session = await getServerSession()
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }
  const data = await getProtectedData(session.user.id)
  return NextResponse.json(data)
}
```

### Streaming (Server-Sent Events)

```tsx
// app/api/stream/route.ts
export async function GET() {
  const encoder = new TextEncoder()
  const stream = new ReadableStream({
    async start(controller) {
      for await (const event of getEvents()) {
        const data = `data: ${JSON.stringify(event)}\n\n`
        controller.enqueue(encoder.encode(data))
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
}
```

## Edge Cases

- `route.ts` and `page.tsx` cannot coexist in the same directory
- GET Route Handlers without reading the request are cached by default — add `export const dynamic = 'force-dynamic'` to opt out
- `params` in Next.js 15+ Route Handlers is a Promise — must be awaited
- Pages Router API routes auto-parse JSON body; disable with `config.api.bodyParser = false`
- Route Handlers use Web API `Request`/`Response`; Pages Router uses Node.js `req`/`res`
- For file uploads, disable body parsing and handle raw streams
- CORS requires explicit `OPTIONS` handler or middleware configuration
