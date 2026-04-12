---
name: domains
description: Add, verify, and manage Resend sending domains with DNS records (SPF, DKIM, DMARC) — use when setting up email infrastructure or troubleshooting deliverability
---

# Resend Domain Management

Manage sending domains for Resend. Before sending production emails from a custom domain, you must add it to Resend and verify ownership by configuring DNS records.

## Prerequisites

- A Resend API key with `full_access` permission — see `resend/auth`
- Access to your domain's DNS settings (Cloudflare, Route 53, Namecheap, etc.)
- `npm install resend` (Node.js)

## Workflow

1. **Add domain**: Call `resend.domains.create({ name })` with your subdomain
2. **Get DNS records**: The response includes SPF, DKIM, and MX records to add
3. **Configure DNS**: Add the records at your DNS provider
4. **Verify**: Call `resend.domains.verify(domainId)` to trigger verification
5. **Wait**: DNS propagation takes 10 minutes to 48 hours
6. **Confirm**: Check `resend.domains.get(domainId)` — status should be `verified`

## Adding a Domain

```typescript
import { Resend } from 'resend';
const resend = new Resend(process.env.RESEND_API_KEY);

const { data, error } = await resend.domains.create({
  name: 'send.yourdomain.com',
});

// Response includes DNS records to add:
// data.records = [
//   { type: 'TXT', name: 'send', value: 'v=spf1 include:amazonses.com ~all' },
//   { type: 'TXT', name: 'resend._domainkey.send', value: 'p=MIGfMA0GCS...' },
//   { type: 'MX', name: 'send', value: 'feedback-smtp.us-east-1.amazonses.com', priority: 10 }
// ]
```

## DNS Records

### SPF — Authorizes Resend's IPs

| Type | Host/Name | Value |
|------|-----------|-------|
| TXT | `send` | `v=spf1 include:amazonses.com ~all` |

### DKIM — Cryptographic email signing

| Type | Host/Name | Value |
|------|-----------|-------|
| TXT | `resend._domainkey.send` | Public key from Resend response |

### MX — Bounce handling

| Type | Host/Name | Value | Priority |
|------|-----------|-------|----------|
| MX | `send` | `feedback-smtp.us-east-1.amazonses.com` | 10 |

### DMARC — Optional but recommended

| Type | Host/Name | Value |
|------|-----------|-------|
| TXT | `_dmarc.send` | `v=DMARC1; p=none;` |

## Verifying DNS

After adding records, check propagation locally:

```bash
# Check SPF
dig TXT send.yourdomain.com +short

# Check DKIM
dig TXT resend._domainkey.send.yourdomain.com +short

# Check MX
dig MX send.yourdomain.com +short
```

Then trigger verification via API:

```typescript
await resend.domains.verify('d91cd9bd-...');
```

## Domain Status Reference

| Status | Meaning | Action |
|--------|---------|--------|
| `not_started` | Records not yet added | Add DNS records |
| `pending` | Records found, verifying | Wait |
| `verified` | All records confirmed | Ready to send |
| `partially_verified` | Some records ok | Fix remaining records |
| `partially_failed` | Some records failed | Check DNS config |
| `failed` | Verification failed | Re-check all records |
| `temporary_failure` | DNS issue, auto-retries 72h | Wait or fix DNS |

## Listing Domains

```typescript
const { data } = await resend.domains.list();
for (const domain of data.data) {
  console.log(`${domain.name}: ${domain.status}`);
}
```

## Deleting a Domain

```typescript
await resend.domains.remove('d91cd9bd-...');
```

Warning: Deleting a domain immediately prevents sending from that domain.

## Best Practices

1. **Use subdomains**: `send.yourdomain.com` isolates email reputation from your root domain
2. **Always add DMARC**: Even `p=none` improves deliverability signals
3. **Verify before deployment**: Test domain status before going live
4. **Monitor status**: Periodically check domain status hasn't degraded
5. **Custom Return-Path**: Set via `customReturnPath` parameter (max 63 chars, starts with letter, alphanumeric/hyphens only)

## Edge Cases

- DNS changes at Cloudflare propagate in minutes; other providers may take 24-48 hours
- If using a root domain, the `name` field in DNS records is `@` instead of the subdomain
- Multiple Resend accounts cannot verify the same domain simultaneously
- Domain deletion is immediate and irreversible — emails in flight may still deliver
