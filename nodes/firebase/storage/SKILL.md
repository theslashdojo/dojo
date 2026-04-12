---
name: storage
description: Upload, download, and manage files in Cloud Storage for Firebase with security rules, resumable uploads, and CDN delivery. Use when handling file uploads/downloads, configuring storage security rules, or managing files server-side with the Admin SDK.
---

# Cloud Storage for Firebase

## When to Use
- Uploading user-generated files (images, videos, documents) from a web or mobile client
- Downloading files or generating long-lived download URLs
- Tracking upload progress with resumable uploads for large files
- Setting up storage security rules to restrict access per user or file type
- Managing files server-side with the Admin SDK (bypassing security rules)
- Listing or deleting files in a storage bucket
- Configuring CORS for browser-based downloads from custom domains

## Prerequisites
- Firebase project initialized with Cloud Storage enabled (see firebase/config)
- `firebase` npm package installed for client SDK operations
- `firebase-admin` npm package installed for server-side / Admin SDK operations
- Service account JSON for Admin SDK (`GOOGLE_APPLICATION_CREDENTIALS`)
- Storage security rules deployed (`firebase deploy --only storage`)

## Workflow

### 1. Initialize Storage

```typescript
import { initializeApp } from 'firebase/app';
import { getStorage, ref } from 'firebase/storage';

const app = initializeApp(firebaseConfig);
const storage = getStorage(app);
```

### 2. Storage References and Path Structure

References are pointers to files or directories. They do not create files.

```typescript
import { ref } from 'firebase/storage';

// File reference
const photoRef = ref(storage, 'images/photo.jpg');

// Directory reference
const imagesRef = ref(storage, 'images/');

// Navigate: child, parent, root
const childRef = ref(imagesRef, 'photo.jpg');  // images/photo.jpg
const parentRef = photoRef.parent;              // images/
const rootRef = photoRef.root;                  // bucket root

// Properties: fullPath, name, bucket
console.log(photoRef.fullPath);  // 'images/photo.jpg'
console.log(photoRef.name);      // 'photo.jpg'
```

### 3. Upload Operations

#### Upload bytes (small files)
```typescript
import { ref, uploadBytes } from 'firebase/storage';

const storageRef = ref(storage, 'images/photo.jpg');
const snapshot = await uploadBytes(storageRef, file);
console.log('Uploaded', snapshot.metadata.size, 'bytes');
```

#### Resumable upload with progress (large files)
```typescript
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';

const storageRef = ref(storage, 'videos/clip.mp4');
const uploadTask = uploadBytesResumable(storageRef, file);

uploadTask.on('state_changed',
  (snapshot) => {
    const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
    console.log(`Upload: ${progress.toFixed(1)}%`);
  },
  (error) => {
    console.error('Upload failed:', error.code);
  },
  async () => {
    const url = await getDownloadURL(uploadTask.snapshot.ref);
    console.log('Download URL:', url);
  }
);

// Control: pause, resume, cancel
uploadTask.pause();
uploadTask.resume();
uploadTask.cancel();
```

#### Upload string (base64, data URL)
```typescript
import { ref, uploadString } from 'firebase/storage';

await uploadString(storageRef, base64String, 'base64');
await uploadString(storageRef, dataUrl, 'data_url');
await uploadString(storageRef, 'Hello, World!');
```

### 4. Download Operations

#### Get download URL
```typescript
import { ref, getDownloadURL } from 'firebase/storage';

const url = await getDownloadURL(ref(storage, 'images/photo.jpg'));
// Long-lived URL with access token — valid until token is revoked
```

#### Download bytes
```typescript
import { ref, getBytes, getBlob } from 'firebase/storage';

// Into memory (ArrayBuffer)
const bytes = await getBytes(ref(storage, 'images/photo.jpg'));

// As Blob (browser)
const blob = await getBlob(ref(storage, 'images/photo.jpg'));
```

### 5. Metadata Management

```typescript
import { ref, getMetadata, updateMetadata } from 'firebase/storage';

const storageRef = ref(storage, 'images/photo.jpg');

// Read metadata
const metadata = await getMetadata(storageRef);
console.log(metadata.contentType, metadata.size, metadata.customMetadata);

// Update metadata
await updateMetadata(storageRef, {
  contentType: 'image/jpeg',
  cacheControl: 'public, max-age=31536000',
  customMetadata: { uploadedBy: 'user123' },
});
```

### 6. Security Rules Patterns

Rules live in `storage.rules`:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Authenticated read
    match /{allPaths=**} {
      allow read: if request.auth != null;
    }

    // User-scoped writes
    match /users/{userId}/{allPaths=**} {
      allow write: if request.auth.uid == userId;
    }

    // Size + type restriction
    match /images/{imageId} {
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

Deploy: `firebase deploy --only storage`

## Critical Rules

1. **Always deploy security rules** before client uploads — default rules deny all access after 30 days
2. **Use `uploadBytesResumable` for files over 5MB** — supports progress tracking, pause/resume, and automatic retry on network failure
3. **Handle all upload error codes** — `storage/unauthorized`, `storage/canceled`, `storage/quota-exceeded`, `storage/retry-limit-exceeded`
4. **Set CORS configuration** for browser downloads from custom domains — without it, `getBytes`/`getBlob` fail with CORS errors
5. **Set `contentType` explicitly** when uploading from Node.js — browsers auto-detect, server environments do not
6. **Never expose service account keys to clients** — use the client SDK with security rules, Admin SDK only on servers
7. **Validate file type and size in security rules** — client-side validation is easily bypassed

## Edge Cases

### Max file size
Individual files can be up to 5TB. A single `uploadBytes` call supports up to 5GB. For files over 5GB, use the resumable upload protocol via the REST API or Admin SDK multipart upload.

### CORS required for browser downloads
`getBytes` and `getBlob` require CORS to be configured on the bucket. Without it, only `getDownloadURL` works (it returns a URL the browser navigates to, not a fetch). Apply CORS with `gsutil cors set cors.json gs://bucket-name`.

### Token-based download URLs
URLs from `getDownloadURL` contain an access token in the query string. These URLs are long-lived — they survive until the token is revoked in the Firebase console or via Admin SDK. Treat them as semi-secret: anyone with the URL can access the file regardless of security rules.

### Listing requires rules_version '2'
`listAll` and `list` only work with `rules_version = '2'` in storage.rules. Version 1 rules do not support list operations.

### Deleting a folder
There is no folder delete operation. List all files in the prefix with `listAll`, then delete each file individually with `deleteObject`.
