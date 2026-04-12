---
name: send
description: Send transactional emails via the Resend API — use when an agent needs to dispatch emails with HTML, plain text, React templates, attachments, or scheduled delivery
---

# Send Email with Resend

Send transactional emails through Resend's API. Supports HTML, plain text, React Email components, file attachments, batch sending, scheduled delivery, and idempotent sends.

## Prerequisites

- A Resend API key (`RESEND_API_KEY` env var) — see `resend/auth`
- A verified sending domain for production — see `resend/domains`
- `npm install resend` (Node.js) or `pip install resend` (Python)

## Workflow

1. **Install SDK**: `npm install resend`
2. **Initialize client**: `new Resend(process.env.RESEND_API_KEY)`
3. **Send email**: Call `resend.emails.send()` with from, to, subject, and content
4. **Handle response**: Check `{ data, error }` — `data.id` is the email ID on success

## Quick Start (Node.js)

```typescript
import { Resend } from 'resend';
const resend = new Resend(process.env.RESEND_API_KEY);

const { data, error } = await resend.emails.send({
  from: 'Acme <hello@yourdomain.com>',
  to: ['user@example.com'],
  subject: 'Welcome to Acme',
  html: '<h1>Welcome!</h1><p>Thanks for signing up.</p>',
});

if (error) {
  console.error(error);
  throw error;
}
console.log('Sent:', data.id);
```

## Quick Start (Python)

```python
import os, resend

resend.api_key = os.environ["RESEND_API_KEY"]

email = resend.Emails.send({
    "from": "Acme <hello@yourdomain.com>",
    "to": ["user@example.com"],
    "subject": "Welcome to Acme",
    "html": "<h1>Welcome!</h1><p>Thanks for signing up.</p>",
})
print(email)  # {'id': '...'}
```

## Quick Start (cURL)

```bash
curl -X POST 'https://api.resend.com/emails' \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "from": "Acme <hello@yourdomain.com>",
    "to": ["user@example.com"],
    "subject": "Welcome",
    "html": "<h1>Welcome!</h1>"
  }'
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `from` | string | Yes | Sender: `Name <email@verified-domain.com>` |
| `to` | string/string[] | Yes | Recipient(s) |
| `subject` | string | Yes | Subject line |
| `html` | string | * | HTML body |
| `text` | string | * | Plain text body |
| `react` | ReactNode | * | React Email component (Node.js only) |
| `cc` | string/string[] | No | CC recipients |
| `bcc` | string/string[] | No | BCC recipients |
| `replyTo` | string/string[] | No | Reply-to address(es) |
| `headers` | object | No | Custom SMTP headers |
| `attachments` | array | No | `{ filename, content }` or `{ filename, path }` |
| `tags` | array | No | `{ name, value }` tracking pairs |
| `scheduledAt` | string | No | ISO 8601 future delivery time |
| `idempotencyKey` | string | No | Deduplication key (24h window) |

\* At least one of `html`, `text`, or `react` is required.

## With React Email

```typescript
import { WelcomeEmail } from './emails/welcome';

await resend.emails.send({
  from: 'Acme <hello@yourdomain.com>',
  to: ['user@example.com'],
  subject: 'Welcome',
  react: WelcomeEmail({ firstName: 'John' }),
});
```

Call components as functions, not JSX.

## Batch Sending (up to 100)

```typescript
const { data, error } = await resend.batch.send([
  { from: 'Acme <hello@yourdomain.com>', to: ['a@example.com'], subject: 'Hi A', html: '<p>Hi A</p>' },
  { from: 'Acme <hello@yourdomain.com>', to: ['b@example.com'], subject: 'Hi B', html: '<p>Hi B</p>' },
]);
```

## Attachments

```typescript
import { readFileSync } from 'fs';

await resend.emails.send({
  from: 'Billing <billing@yourdomain.com>',
  to: ['user@example.com'],
  subject: 'Invoice',
  html: '<p>Invoice attached.</p>',
  attachments: [{ filename: 'invoice.pdf', content: readFileSync('./invoice.pdf') }],
});
```

## Scheduled Delivery

```typescript
await resend.emails.send({
  from: 'Acme <hello@yourdomain.com>',
  to: ['user@example.com'],
  subject: 'Reminder',
  html: '<p>Your reminder</p>',
  scheduledAt: '2026-12-25T09:00:00Z',
});
```

## Error Handling

Always destructure `{ data, error }`:

```typescript
const { data, error } = await resend.emails.send({ ... });
if (error) {
  // error: { statusCode: 422, message: '...', name: 'validation_error' }
  console.error(error.message);
  return;
}
// data: { id: '49a3999c-...' }
```

Common errors:
- `validation_error` (422): Missing/invalid fields, unverified domain
- `not_found` (404): Invalid API key or endpoint
- `rate_limit_exceeded` (429): Too many requests

## Edge Cases

- **Test addresses**: Use `delivered@resend.dev`, `bounced@resend.dev`, `complained@resend.dev` during development
- **React components**: Must be passed as function calls not JSX (`EmailTemplate({ name })` not `<EmailTemplate />`)
- **Always await**: `resend.emails.send()` returns a Promise — forgetting `await` silently drops the email
- **Domain verification**: Production sends fail if `from` uses an unverified domain; use `onboarding@resend.dev` for testing
