---
name: prompt-caching
description: Cache prompt prefixes to reduce cost and latency with Claude — use when sending repeated system prompts, large documents, or tool definitions across multiple requests
---

# Prompt Caching

Cache repeated prompt content so Claude skips re-processing it. Cache reads cost 10% of base input price.

## When to Use

- Long system prompts sent with every request
- Large reference documents (contracts, codebases, manuals)
- Tool definitions that don't change between requests
- Multi-turn conversations with growing history
- Any repeated prefix content across requests

## Prerequisites

- `ANTHROPIC_API_KEY` set in environment
- `pip install anthropic`

## Workflow

1. Add `cache_control: {"type": "ephemeral"}` to the request or on specific content blocks
2. First request: content is cached (cache write at 1.25x cost)
3. Subsequent requests within 5 minutes: cache hit (0.1x cost)
4. Monitor `cache_read_input_tokens` in usage to verify cache hits

## Automatic Caching (Recommended)

```python
import anthropic

client = anthropic.Anthropic()

# Same system prompt reused across many requests
system_prompt = "You are a legal expert. Here is the full contract text: [10,000 tokens of contract...]"

# Request 1: cache write
r1 = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},
    system=system_prompt,
    messages=[{"role": "user", "content": "What are the payment terms?"}]
)
print(f"Cache write: {r1.usage.cache_creation_input_tokens}")

# Request 2 (within 5 min): cache hit
r2 = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},
    system=system_prompt,
    messages=[{"role": "user", "content": "What are the liability clauses?"}]
)
print(f"Cache read: {r2.usage.cache_read_input_tokens}")  # ~10,000
```

## Explicit Breakpoints

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[{
        "type": "text",
        "text": "You are an expert. Reference doc: [long text...]",
        "cache_control": {"type": "ephemeral"}
    }],
    messages=[{"role": "user", "content": "Summarize section 3"}]
)
```

## Minimum Token Requirements

| Model | Min Tokens Before Breakpoint |
|-------|------------------------------|
| Opus 4.6, Opus 4.5, Haiku 4.5 | 4,096 |
| Sonnet 4.6, Haiku 3.5 | 2,048 |
| Sonnet 4.5, Sonnet 4, Opus 4.1, Opus 4 | 1,024 |

Below minimum: request works but no caching occurs (silent, no error).

## Edge Cases

- **Below minimum**: No error, no caching. Check usage fields — both cache fields will be 0.
- **Cache miss**: Prefix changed. Verify content before breakpoint is identical across requests.
- **Concurrent requests**: Wait for first response before sending parallel requests. Cache is only available after the first response begins.
- **Invalidation**: Changing tools invalidates everything downstream. Change messages only if possible.
