---
name: prompt-caching
description: Cache prompt prefixes to reduce latency and cost on repeated context. Use when sending the same system prompt, documents, or tool definitions across multiple API calls.
---

# Prompt Caching

Avoid reprocessing identical prompt prefixes. Cache once, read at 90% discount.

## When to Use

- Multi-turn conversations with long system prompts
- Applications that send large documents with each request
- Repeated tool definitions across many calls
- Any pattern where the same prefix appears in multiple requests

## Workflow

### Automatic (Recommended)

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},
    system="Long system prompt with docs...",
    messages=[{"role": "user", "content": "Question about the docs"}]
)
```

### Explicit Breakpoints

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[
        {"type": "text", "text": "Instructions...", "cache_control": {"type": "ephemeral"}},
        {"type": "text", "text": "Large document...", "cache_control": {"type": "ephemeral"}}
    ],
    messages=[{"role": "user", "content": "Question"}]
)
```

## Verifying Cache Hits

```python
usage = response.usage
print(f"Cache write: {usage.cache_creation_input_tokens}")
print(f"Cache read:  {usage.cache_read_input_tokens}")
print(f"Uncached:    {usage.input_tokens}")
```

If `cache_read_input_tokens > 0`, caching is working.

## TTL Options

- `{"type": "ephemeral"}` — 5-minute TTL, 1.25x write cost
- `{"type": "ephemeral", "ttl": "1h"}` — 1-hour TTL, 2x write cost
- Both: 0.1x base price on reads

## Requirements

- Minimum cacheable tokens: 1024-4096 depending on model
- Up to 4 explicit breakpoints per request
- Longer TTL entries must appear before shorter ones when mixing
- Content changes invalidate downstream cache entries

## Cost Math

| Scenario (Sonnet 4.6) | Cost/MTok |
|------------------------|-----------|
| Standard input | $3.00 |
| Cache write (5m) | $3.75 |
| Cache read | $0.30 |
| Batch + cache read | $0.15 |

Break-even: 1 cache read pays back a 5m write, 2 reads pay back a 1h write.

## Edge Cases

- Prompts below minimum token count won't cache (no error, just no caching)
- First request always writes to cache — subsequent requests read
- Parallel requests to the same prefix: first response creates cache, others may miss
- Changes to tools, system prompt, or messages invalidate affected cache levels
