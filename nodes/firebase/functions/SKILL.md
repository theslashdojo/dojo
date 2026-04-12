---
name: functions
description: >
  Create and deploy Cloud Functions for Firebase (2nd gen) — serverless backend code
  triggered by HTTP requests, Firestore document changes, Auth user lifecycle events,
  Cloud Storage uploads, and cron schedules. Use when you need server-side logic that
  responds to Firebase events or exposes HTTP endpoints.
---

# Cloud Functions for Firebase

## When to Use

- Exposing an HTTP API endpoint or webhook handler
- Running server logic when a Firestore document is created, updated, or deleted
- Sending welcome emails or creating profiles when users sign up (Auth triggers)
- Processing file uploads — thumbnails, virus scans, metadata extraction (Storage triggers)
- Running scheduled jobs — cleanup, reports, data sync (cron)
- Calling external APIs with server-side secrets (Stripe, OpenAI, SendGrid)
- Implementing callable functions invoked from the client SDK with automatic auth

## Prerequisites

- Firebase CLI installed (`npm install -g firebase-tools`) — see firebase/cli
- Firebase project initialized (`firebase init`)
- Functions directory set up (`firebase init functions`, select TypeScript)
- Node.js 20+ installed (for nodejs20 runtime)

## Workflow

### 1. Initialize Functions Directory

```bash
firebase init functions
# Select TypeScript (recommended)
# Creates: functions/package.json, functions/tsconfig.json, functions/src/index.ts
```

### 2. Write Functions with v2 API

All functions are exported from `functions/src/index.ts`. Each export becomes a deployed function.

**HTTP function:**

```typescript
import { onRequest } from "firebase-functions/v2/https";

export const api = onRequest({ region: "us-central1", cors: true }, (req, res) => {
  const name = req.query.name || "World";
  res.json({ message: `Hello, ${name}!` });
});
```

**Callable function (client SDK invocation with auth):**

```typescript
import { onCall, HttpsError } from "firebase-functions/v2/https";

export const processOrder = onCall({ region: "us-central1" }, (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }
  const { orderId } = request.data;
  return { status: "processed", orderId, uid: request.auth.uid };
});
```

**Firestore trigger:**

```typescript
import { onDocumentCreated } from "firebase-functions/v2/firestore";

export const onUserCreated = onDocumentCreated("users/{userId}", (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const userData = snapshot.data();
  console.log(`New user ${event.params.userId}:`, userData);
  return snapshot.ref.update({ welcomeEmailSent: true });
});
```

**Auth trigger:**

```typescript
import { onAuthUserCreated } from "firebase-functions/v2/identity";

export const welcomeUser = onAuthUserCreated((event) => {
  const user = event.data;
  console.log(`User signed up: ${user.uid}, ${user.email}`);
  // Create profile doc, send welcome email
});
```

**Storage trigger:**

```typescript
import { onObjectFinalized } from "firebase-functions/v2/storage";

export const processUpload = onObjectFinalized((event) => {
  const { name, contentType, size, bucket } = event.data;
  console.log(`Uploaded: gs://${bucket}/${name} (${contentType}, ${size} bytes)`);
  // Generate thumbnail, extract metadata
});
```

**Scheduled function:**

```typescript
import { onSchedule } from "firebase-functions/v2/scheduler";

export const dailyCleanup = onSchedule("every day 02:00", async (event) => {
  console.log("Running daily cleanup...");
  // Delete expired records, send digests
});
```

### 3. Configure Environment Variables and Secrets

```typescript
import { defineSecret, defineString } from "firebase-functions/params";

const stripeKey = defineSecret("STRIPE_SECRET_KEY");
const appName = defineString("APP_NAME", { default: "My App" });

export const checkout = onRequest({ secrets: [stripeKey] }, (req, res) => {
  const key = stripeKey.value();
  res.json({ app: appName.value() });
});
```

```bash
# Set secrets (stored in Google Secret Manager)
firebase functions:secrets:set STRIPE_SECRET_KEY

# Non-secret env vars in functions/.env
echo "APP_NAME=My Production App" >> functions/.env

# Emulator-only env vars in functions/.env.local
echo "APP_NAME=My Dev App" >> functions/.env.local
```

### 4. Test Locally with Emulator

```bash
# Start functions emulator with dependent services
firebase emulators:start --only functions,firestore,auth,storage

# Functions emulator runs on http://localhost:5001
# Test HTTP functions:
curl http://localhost:5001/<project-id>/<region>/api?name=test

# Emulator UI at http://localhost:4000
```

### 5. Deploy

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:api

# Deploy multiple
firebase deploy --only functions:api,functions:onUserCreated

# View logs
firebase functions:log --only api

# Delete a function
firebase functions:delete api --region us-central1
```

## v2 Import Reference

| Trigger | Import |
|---------|--------|
| HTTP / Callable | `firebase-functions/v2/https` |
| Firestore | `firebase-functions/v2/firestore` |
| Auth | `firebase-functions/v2/identity` |
| Storage | `firebase-functions/v2/storage` |
| Scheduled | `firebase-functions/v2/scheduler` |
| Pub/Sub | `firebase-functions/v2/pubsub` |
| Params | `firebase-functions/params` |

## Critical Rules

1. **Always use v2 API** — import from `firebase-functions/v2/*`, not the legacy `firebase-functions` top-level
2. **Set region explicitly** — defaults to us-central1; set `region` in function options for production
3. **Handle errors in all functions** — wrap in try/catch, use `HttpsError` for callables, log failures
4. **Set memory and timeout** — defaults are 256MiB and 60s; adjust for workload (e.g., image processing needs more memory)
5. **Keep functions focused** — one function per concern; split large function files into separate modules and re-export from index.ts
6. **Declare secrets in options** — secrets must be listed in the function's `{ secrets: [key] }` option to be accessible
7. **Export everything from index.ts** — only functions exported from the entry point are deployed; unexported functions are deleted

## Edge Cases

### Cold starts
First invocation after idle may take 1-5 seconds. Set `minInstances: 1` for latency-sensitive functions. Each warm instance costs money even when idle.

### Max timeout
2nd gen functions support up to 3600 seconds (60 minutes). Default is 60 seconds. Set `timeoutSeconds` in options. Scheduled functions and event triggers may need longer timeouts for batch processing.

### Max functions per project
Limit of 1000 functions per project per region. Group related logic into fewer functions where possible. Use onRequest with Express routing for REST APIs instead of one function per route.

### Idempotency for retries
Event-triggered functions (Firestore, Auth, Storage) may be retried on failure. Design handlers to be idempotent — check if the work was already done before processing. Use event IDs or document fields as deduplication keys.

### Function deletion on deploy
Functions that are no longer exported from index.ts are deleted on the next `firebase deploy --only functions`. This is intentional — remove exports to delete functions. Use `--only functions:name` to deploy individual functions without affecting others.
