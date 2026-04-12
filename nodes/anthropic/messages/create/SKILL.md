---
name: create
description: Create a single synchronous Claude message completion. Use when you need a complete response before proceeding — the standard non-streaming API call.
---

# Create Message

`POST /v1/messages` — synchronous message completion.

## When to Use

- Standard API calls where you wait for the full response
- Backend processing where streaming isn't needed
- Batch-like operations in a loop
- Any non-interactive Claude integration

## Workflow

1. Build the request with model, max_tokens, messages
2. Call `client.messages.create(**params)`
3. Wait for complete response
4. Read `response.content[0].text`
5. Check `response.stop_reason` for completion status

## Examples

### Basic

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain async/await"}]
)
```

### With Vision

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": img_b64}},
            {"type": "text", "text": "Describe this image"}
        ]
    }]
)
```

### With Structured Output

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    output_config={
        "type": "json_schema",
        "schema": {"type": "object", "properties": {"sentiment": {"type": "string"}}}
    },
    messages=[{"role": "user", "content": "Analyze: Great product!"}]
)
```

## Error Handling

```python
try:
    response = client.messages.create(...)
except anthropic.RateLimitError as e:
    retry_after = e.response.headers.get("retry-after", 1)
    time.sleep(float(retry_after))
except anthropic.AuthenticationError:
    print("Check your API key")
```

## Edge Cases

- `stop_reason: "max_tokens"` means the response was truncated — increase max_tokens
- `stop_reason: "tool_use"` means Claude wants to call a tool — handle it
- The SDK automatically retries on transient 5xx errors
