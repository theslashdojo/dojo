---
name: r2
description: >
  Manage Cloudflare R2 object storage — create buckets, upload, download, list, and delete
  objects. Use when storing files, media, backups, or any binary data with S3-compatible
  access and zero egress fees.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-storage
---

# Cloudflare R2

S3-compatible object storage with zero egress fees.

## When to Use

- Storing files, images, videos, or documents
- Hosting static assets for web applications
- Backups and data archival
- Data lakes and large datasets
- Migrating from S3 (drop-in replacement)

## Prerequisites

- Wrangler CLI installed
- `CLOUDFLARE_API_TOKEN` with Workers R2 Storage:Edit
- `CLOUDFLARE_ACCOUNT_ID`

## Workflow

### 1. Create a Bucket

```bash
wrangler r2 bucket create my-files
```

### 2. Bind to Worker

```toml
# wrangler.toml
[[r2_buckets]]
binding = "FILES"
bucket_name = "my-files"
```

### 3. Upload/Download in Worker

```typescript
export interface Env { FILES: R2Bucket; }

export default {
  async fetch(request: Request, env: Env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1);

    if (request.method === 'PUT') {
      const obj = await env.FILES.put(key, request.body, {
        httpMetadata: { contentType: request.headers.get('content-type') || 'application/octet-stream' },
      });
      return Response.json({ key: obj.key, size: obj.size });
    }

    if (request.method === 'GET') {
      const obj = await env.FILES.get(key);
      if (!obj) return new Response('Not Found', { status: 404 });
      const headers = new Headers();
      obj.writeHttpMetadata(headers);
      return new Response(obj.body, { headers });
    }

    if (request.method === 'DELETE') {
      await env.FILES.delete(key);
      return new Response('Deleted');
    }
  },
};
```

### 4. CLI Operations

```bash
wrangler r2 object put my-files/photos/cat.jpg --file ./cat.jpg
wrangler r2 object get my-files/photos/cat.jpg --file ./downloaded.jpg
wrangler r2 object delete my-files/photos/cat.jpg
wrangler r2 object list my-files --prefix photos/
```

### 5. S3 API Access

```bash
# Use AWS CLI with R2 endpoint
aws s3 cp ./file.txt s3://my-files/file.txt \
  --endpoint-url https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com
```

## Limits

| Resource | Value |
|----------|-------|
| Max object size | 5TB |
| Free storage | 10GB |
| Free Class A ops/month | 1M (PUT, POST, LIST) |
| Free Class B ops/month | 10M (GET, HEAD) |
| Egress | Always free |

## Edge Cases

- R2 is strongly consistent — reads after writes always return latest data.
- For S3 API access, generate R2 API tokens (separate from Cloudflare API tokens).
- Multipart uploads required for objects > 5GB via S3 API.
- `delete()` accepts a single key or array of keys for batch deletion.
- Custom metadata limited to 2KB per object.
