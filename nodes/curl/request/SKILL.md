---
name: request
description: Execute HTTP requests with curl — GET, POST, PUT, DELETE with headers, JSON bodies, form data, file uploads. Use when making API calls, testing endpoints, sending webhooks, or transferring files from the command line.
---

# curl HTTP Request

Execute HTTP requests from the command line using curl. Handles all methods, body types, headers, redirects, and response output.

## When to Use

- Making API calls (REST, GraphQL) without writing application code
- Testing an endpoint before building integration code
- Sending webhooks or notifications
- Uploading or downloading files
- Checking if a service is reachable
- Automating HTTP requests in CI/CD scripts

## Workflow

1. Determine the target URL and HTTP method
2. Set required headers (Content-Type, Accept, Authorization)
3. Attach the request body if needed (JSON, form data, file)
4. Choose output handling (full body, status code only, save to file)
5. Execute and check exit code + HTTP status
6. Parse the response (pipe to `jq` for JSON)

## Quick Reference

### GET

```bash
curl -s -H "Accept: application/json" https://api.example.com/users
```

### POST JSON

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"name": "Alice", "email": "alice@example.com"}' \
     https://api.example.com/users
```

### POST from file

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d @payload.json \
     https://api.example.com/users
```

### PUT update

```bash
curl -X PUT \
     -H "Content-Type: application/json" \
     -d '{"name": "Updated Name"}' \
     https://api.example.com/users/42
```

### DELETE

```bash
curl -X DELETE \
     -H "Authorization: Bearer $TOKEN" \
     https://api.example.com/users/42
```

### File upload (multipart)

```bash
curl -F "file=@document.pdf" \
     -F "description=Quarterly report" \
     https://api.example.com/upload
```

### Download

```bash
curl -LO https://releases.example.com/v1.0/binary.tar.gz
```

### Status check

```bash
status=$(curl -s -o /dev/null -w '%{http_code}' https://api.example.com/health)
if [ "$status" -eq 200 ]; then
  echo "Service healthy"
else
  echo "Service returned $status"
fi
```

## Building JSON Payloads Safely

Avoid string interpolation for JSON — it breaks on special characters. Use `jq`:

```bash
# Build JSON from shell variables
jq -n \
  --arg name "$USER_NAME" \
  --arg email "$USER_EMAIL" \
  --argjson active true \
  '{name: $name, email: $email, active: $active}' | \
curl -X POST -H "Content-Type: application/json" -d @- https://api.example.com/users
```

## Piping to jq

```bash
# Extract a single field
curl -s https://api.example.com/users/1 | jq -r '.email'

# Filter an array
curl -s https://api.example.com/users | jq '[.[] | select(.active == true)]'

# Pretty-print
curl -s https://api.example.com/data | jq .
```

## Script Usage

The `http-request.sh` script wraps curl with environment-variable-driven configuration:

```bash
CURL_URL="https://api.example.com/users" \
CURL_METHOD="POST" \
CURL_HEADERS="Content-Type: application/json
Authorization: Bearer $TOKEN" \
CURL_DATA='{"name":"Alice"}' \
CURL_OUTPUT="full" \
./scripts/http-request.sh
```

## Edge Cases

- **`@` in data**: `-d @filename` reads from a file; use `--data-raw` if your data literally starts with `@`
- **Binary data**: use `--data-binary @file` to prevent curl from stripping newlines
- **Empty POST body**: use `-X POST -d ''` to send a POST with an empty body
- **Shell quoting**: single-quote JSON to prevent Bash from interpolating `$` and `{}`; use `jq` for dynamic values
- **Large responses**: pipe to `jq` or redirect to a file; don't let huge responses flood the terminal
- **HEAD + body**: `-I` returns headers only; some servers behave differently for HEAD vs GET
- **HTTP/2**: curl uses HTTP/2 by default for HTTPS when available; force HTTP/1.1 with `--http1.1` if needed
