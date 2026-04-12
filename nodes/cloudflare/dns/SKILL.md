---
name: dns
description: >
  Manage Cloudflare DNS zones and records — create, list, update, and delete A, AAAA,
  CNAME, MX, TXT, and other DNS records. Use when pointing domains to servers, Workers,
  or Pages, configuring email DNS, or verifying domain ownership.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: cloudflare-dns
---

# Cloudflare DNS

Authoritative DNS management with global anycast resolution.

## When to Use

- Pointing a domain to a server, Worker, or Pages project
- Adding DNS verification records (TXT)
- Setting up email records (MX, SPF, DKIM, DMARC)
- Managing DNS for any Cloudflare-hosted domain

## Prerequisites

- `CLOUDFLARE_API_TOKEN` with Zone:DNS:Edit permission
- Zone ID for the target domain (find via API or dashboard)

## Workflow

### 1. Find Zone ID

```bash
curl -s "https://api.cloudflare.com/client/v4/zones?name=example.com" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq '.result[0].id'
```

### 2. Create DNS Records

```bash
# A record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"app","content":"192.0.2.1","ttl":1,"proxied":true}'

# CNAME record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"CNAME","name":"www","content":"example.com","ttl":1,"proxied":true}'

# TXT record (SPF)
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"TXT","name":"@","content":"v=spf1 include:_spf.google.com ~all","ttl":1}'
```

### 3. List Records

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq '.result[] | {type, name, content}'
```

### 4. Update a Record

```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"content":"198.51.100.1"}'
```

### 5. Delete a Record

```bash
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

## Record Types

| Type | Purpose | Example |
|------|---------|---------|
| A | IPv4 address | `192.0.2.1` |
| AAAA | IPv6 address | `2001:db8::1` |
| CNAME | Alias | `app.example.com` |
| MX | Email routing | `mail.example.com` (priority 10) |
| TXT | Text data | SPF, DKIM, verification |
| SRV | Service location | `_sip._tcp.example.com` |

## Edge Cases

- Set `proxied: true` for A/CNAME records to route through Cloudflare CDN/WAF.
- MX, TXT, and SRV records cannot be proxied.
- `ttl: 1` means "automatic" — Cloudflare manages the TTL.
- Use `@` as the name for the zone apex (root domain).
- DNS propagation is near-instant within Cloudflare; external resolvers may cache.
