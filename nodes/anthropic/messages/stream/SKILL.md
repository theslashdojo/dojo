---
name: stream
description: Stream Claude responses token-by-token via server-sent events. Use when building chat UIs, real-time displays, or any application where perceived latency matters.
---

# Stream Messages

Stream responses via SSE for real-time output.

## When to Use

- Chat interfaces showing text as it generates
- Long-running completions where users need feedback
- Any UX where waiting for the full response feels slow
- Tool use with real-time progress indicators

## Workflow

1. Use `client.messages.stream()` instead of `client.messages.create()`
2. Iterate the text stream or listen for events
3. Optionally get the final message after streaming completes

## Python

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Write a poem"}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

final = stream.get_final_message()
```

### Async Python

```python
async with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Write a poem"}]
) as stream:
    async for text in stream.text_stream:
        print(text, end="", flush=True)
```

## TypeScript

```typescript
const stream = await client.messages.stream({
  model: "claude-sonnet-4-6",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Write a poem" }]
});

stream.on("text", (text) => process.stdout.write(text));
const final = await stream.finalMessage();
```

## SSE Event Types

| Event | When |
|-------|------|
| `message_start` | Response begins |
| `content_block_start` | New content block |
| `content_block_delta` | Incremental text/JSON |
| `content_block_stop` | Block complete |
| `message_delta` | Final stop_reason and usage |
| `message_stop` | Stream complete |

## Streaming with Tools

Tool use blocks stream `input_json_delta` events with partial JSON. The complete tool input is only available after `content_block_stop`. Execute the tool, then send the result as a normal message to continue.

## Edge Cases

- Always flush stdout when printing streamed text
- Tool input JSON is partial during streaming — wait for block completion
- Network interruptions may truncate the stream without a message_stop event
- Use `get_final_message()` / `finalMessage()` to get the complete response object
