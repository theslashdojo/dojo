---
name: stream
description: Stream Claude responses token-by-token via server-sent events — use when building real-time UIs, chatbots, or any interface where perceived latency matters
---

# Stream Messages

Stream Claude's response incrementally for real-time display.

## When to Use

- Building a chat UI where users see tokens appear
- Long responses where showing progress matters
- Any scenario where first-token latency is critical
- Streaming tool use arguments as they're generated

## Prerequisites

- `ANTHROPIC_API_KEY` set in environment
- `pip install anthropic` or `npm install @anthropic-ai/sdk`

## Workflow

1. Initialize the Anthropic client
2. Use `client.messages.stream()` (not `.create()`)
3. Iterate over `stream.text_stream` for simple text output
4. Or iterate over raw events for full control
5. Call `stream.get_final_message()` for the accumulated message

## Python — Simple Text Stream

```python
import anthropic

client = anthropic.Anthropic()

with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Write a short story about a robot"}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
print()  # newline after stream
```

## Python — Raw Events

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
) as stream:
    for event in stream:
        match event.type:
            case "content_block_delta":
                if event.delta.type == "text_delta":
                    print(event.delta.text, end="", flush=True)
            case "message_delta":
                print(f"\nDone: {event.delta.stop_reason}")
```

## TypeScript — Event Handler

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const stream = client.messages.stream({
  model: "claude-sonnet-4-6",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Write a haiku" }]
});

stream.on("text", (text) => process.stdout.write(text));
stream.on("message", (msg) => console.log("\nDone:", msg.stop_reason));

await stream.finalMessage();
```

## Async Python

```python
import asyncio
import anthropic

async def main():
    client = anthropic.AsyncAnthropic()
    async with client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": "Hello"}]
    ) as stream:
        async for text in stream.text_stream:
            print(text, end="", flush=True)

asyncio.run(main())
```

## Edge Cases

- **Connection drops**: The SDK handles reconnection automatically for transient failures
- **Tool use in streams**: Watch for `input_json_delta` events — accumulate partial JSON until `content_block_stop`
- **Extended thinking**: `thinking_delta` events arrive before `text_delta` events
- **Error events**: An `error` SSE event may arrive mid-stream on server errors
