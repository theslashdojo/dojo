---
name: storage
description: Upload, download, and manage files in Supabase Storage with buckets, signed URLs, policies, and image transforms. Use when handling file uploads, generating download links, or managing storage buckets.
---

# Supabase Storage

## When to Use
- Uploading user files (avatars, documents, images)
- Creating and configuring storage buckets
- Generating signed URLs for private files
- Serving images with on-the-fly transformations
- Setting up storage policies for access control

## Prerequisites
- Supabase client initialized (see supabase/client)
- Bucket created (via SDK, dashboard, or SQL migration)

## Workflow

### 1. Create a bucket (in migration)
```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', false, 5242880, ARRAY['image/png', 'image/jpeg']);
```

### 2. Add storage policies (in migration)
```sql
CREATE POLICY "upload_own" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "read_own" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
```

### 3. Upload from client
```typescript
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.png`, file, { upsert: true });
```

### 4. Get URL
```typescript
// Private bucket — signed URL
const { data } = await supabase.storage
  .from('avatars')
  .createSignedUrl(`${userId}/avatar.png`, 3600);

// Public bucket — permanent URL
const { data } = supabase.storage
  .from('public-assets')
  .getPublicUrl('logo.png');
```

## Critical Rules

1. **Always set storage policies** — without them, uploads/downloads fail for anon key
2. **Use `upsert: true`** to overwrite existing files
3. **Structure paths as `<user_id>/<filename>`** for user-scoped policies
4. **Set `contentType` in Node.js** — browser auto-detects, Node.js doesn't
5. **Use signed URLs for private files** — they expire, share safely

## Edge Cases

### Upload too large
Set `fileSizeLimit` on the bucket. Default is 50MB. Error: `Payload too large`.

### Wrong MIME type
Set `allowedMimeTypes` on the bucket. Error: `mime type not allowed`.

### Policy blocks upload
Check that the path matches the policy pattern. Most common issue: folder path doesn't match `auth.uid()::text`.
