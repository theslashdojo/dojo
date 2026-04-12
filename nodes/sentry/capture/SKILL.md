---
name: capture
description: Capture errors, messages, and breadcrumbs with Sentry and enrich events with user context, tags, and scopes. Use when adding manual error reporting, user identification, or contextual data to Sentry events.
---

# Sentry Capture & Enrichment

Manually capture errors, messages, and enrich Sentry events with contextual data for debugging.

## Prerequisites

- Sentry SDK initialized via `Sentry.init()` (see sentry/setup)
- DSN configured and events flowing to Sentry

## Workflow

1. **Identify the capture point** — catch block, error boundary, business logic violation
2. **Choose the method** — `captureException` for errors, `captureMessage` for textual events
3. **Enrich the event** — add tags, user, context, breadcrumbs
4. **Scope if needed** — use `withScope` for event-specific context

## Core Methods

### captureException

For caught errors with stack traces:

```javascript
import * as Sentry from "@sentry/node";

try {
  await processPayment(order);
} catch (err) {
  Sentry.captureException(err);
  // Optionally show the event ID to users for support
  const eventId = Sentry.captureException(err);
  showError(`Error ID: ${eventId}`);
}
```

With inline enrichment:

```javascript
Sentry.captureException(err, {
  tags: { payment_provider: "stripe" },
  extra: { order_id: order.id, amount: order.total },
  level: "fatal",
});
```

### captureMessage

For events without an error object:

```javascript
Sentry.captureMessage("User exceeded rate limit", "warning");
Sentry.captureMessage("Config migration completed", {
  level: "info",
  tags: { migration: "v2-to-v3" },
});
```

Severity levels: `fatal`, `error`, `warning`, `log`, `info`, `debug`.

### addBreadcrumb

Record a trail of actions leading up to errors:

```javascript
Sentry.addBreadcrumb({
  category: "auth",
  message: `User ${user.email} logged in`,
  level: "info",
  data: { method: "oauth", provider: "google" },
});
```

### setUser

Identify the current user on all subsequent events:

```javascript
// After login
Sentry.setUser({
  id: user.id,
  email: user.email,
  username: user.username,
  ip_address: "{{auto}}",
});

// On logout
Sentry.setUser(null);
```

### setTag / setContext / setExtra

```javascript
// Tags — indexed, searchable in Sentry UI
Sentry.setTag("feature_flag", "new-checkout-v2");
Sentry.setTag("tenant", customer.tenantId);

// Context — structured, visible in event detail
Sentry.setContext("order", {
  id: order.id,
  total: order.total,
  items: order.items.length,
});

// Extra — arbitrary key-value, visible in event detail
Sentry.setExtra("response_body", JSON.stringify(apiResponse));
```

### withScope

Attach context to a single event without affecting the global scope:

```javascript
Sentry.withScope((scope) => {
  scope.setTag("transaction", "checkout");
  scope.setLevel("warning");
  scope.setContext("cart", { items: cart.items, total: cart.total });
  Sentry.captureException(new Error("Checkout validation failed"));
});
// Global scope is unaffected
```

## Edge Cases

- **Non-Error values** — `captureException("string")` works but produces low-quality events; always wrap in `new Error()`
- **Async errors** — unhandled promise rejections are auto-captured; for handled async errors, use try/catch + captureException
- **High-volume events** — use `sampleRate` in config to reduce volume; tags help you filter noise
- **PII in breadcrumbs** — use `beforeBreadcrumb` in config to redact sensitive data
- **Server-side scoping** — Node.js servers should use isolation scopes per request to avoid user data leaking between requests

## Examples

### Express error handler

```javascript
app.use((err, req, res, next) => {
  Sentry.withScope((scope) => {
    scope.setUser({ id: req.user?.id });
    scope.setTag("route", req.path);
    scope.setContext("request", {
      method: req.method,
      query: req.query,
      body: req.body,
    });
    Sentry.captureException(err);
  });
  res.status(500).json({ error: "Internal server error" });
});
```

### React Error Boundary with user feedback

```jsx
<Sentry.ErrorBoundary
  fallback={({ error, eventId }) => (
    <div>
      <p>Something went wrong.</p>
      <p>Error ID: {eventId}</p>
      <button onClick={() => Sentry.showReportDialog({ eventId })}>
        Report Feedback
      </button>
    </div>
  )}
>
  <App />
</Sentry.ErrorBoundary>
```
