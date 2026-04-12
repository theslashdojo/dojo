---
name: linear-webhooks
description: Configure and handle Linear webhooks for real-time event-driven automation. Use when building integrations that react to issue, project, or comment changes in Linear.
---

# Linear Webhooks

Build real-time integrations that react to Linear events via webhook HTTP callbacks.

## Prerequisites

- `LINEAR_API_KEY` for creating webhooks programmatically (or use Linear Settings UI)
- `LINEAR_WEBHOOK_SECRET` for signature verification
- A publicly accessible HTTPS endpoint

## Workflow

### 1. Create a webhook

Via GraphQL:

```graphql
mutation {
  webhookCreate(input: {
    url: "https://your-app.com/webhooks/linear"
    resourceTypes: ["Issue", "Comment", "Project"]
    label: "My Bot"
  }) {
    success
    webhook { id secret }
  }
}
```

Or via Linear Settings → API → Webhooks.

### 2. Implement the handler

```typescript
import express from "express";
import { createHmac, timingSafeEqual } from "crypto";

const app = express();
const SECRET = process.env.LINEAR_WEBHOOK_SECRET!;

app.post("/webhooks/linear", express.raw({ type: "application/json" }), (req, res) => {
  const signature = req.headers["linear-signature"] as string;
  const body = req.body.toString();

  // Verify HMAC signature
  const hmac = createHmac("sha256", SECRET);
  hmac.update(body);
  const digest = hmac.digest("hex");
  const sigBuf = Buffer.from(signature, "utf8");
  const digBuf = Buffer.from(digest, "utf8");

  if (sigBuf.length !== digBuf.length || !timingSafeEqual(sigBuf, digBuf)) {
    return res.status(401).send("Invalid signature");
  }

  // Verify freshness
  const payload = JSON.parse(body);
  if (Date.now() - payload.webhookTimestamp > 60_000) {
    return res.status(401).send("Stale");
  }

  // Route events
  const { action, type, data } = payload;
  console.log(`${type} ${action}:`, data.identifier || data.id);

  res.status(200).send("OK");
});

app.listen(3000);
```

### 3. Verify signature (security-critical)

Always verify:
1. HMAC-SHA256 of raw body matches `Linear-Signature` header
2. `webhookTimestamp` is within 60 seconds of now
3. Use constant-time comparison (`timingSafeEqual`)

### 4. Handle retries gracefully

- Make your handler idempotent using `Linear-Delivery` UUID
- Respond within 5 seconds
- Return HTTP 200 even if downstream processing is async

## Event Types

- **Issue**: create, update, remove
- **Comment**: create, update, remove
- **Project**: create, update, remove
- **ProjectUpdate**: create, update, remove
- **Cycle**: create, update, remove
- **IssueLabel**: create, update, remove
- **User**: update

## Common Patterns

- **Auto-triage**: On issue create, assign priority based on labels or title keywords
- **Slack notifications**: Forward issue creates and state changes to Slack
- **CI triggers**: Trigger builds when issues move to "In Review"
- **Status sync**: Mirror issue state to external project management tools
- **SLA monitoring**: Track time-in-state for SLA compliance

## Edge Cases

- `updatedFrom` is only present on `update` actions and only contains changed fields
- `actor.type` can be `user`, `OAuthClient`, or `Integration`
- Webhooks disabled after persistent delivery failures — re-enable in Settings
- IP allowlist: `35.231.147.226`, `35.243.134.228`, `34.140.253.14`, `34.38.87.206`, `34.134.222.122`, `35.222.25.142`
