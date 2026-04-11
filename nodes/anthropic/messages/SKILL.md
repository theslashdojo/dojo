---
name: messages
description: Send messages to Claude via the Anthropic Messages API — use when you need to create completions, have multi-turn conversations, process images/documents, or call tools
---

# Messages API

The Messages API (`POST /v1/messages`) is the primary interface for all Claude interactions.

## When to Use

- Sending a prompt and getting a completion from Claude
- Multi-turn conversations with conversation history
- Processing images, PDFs, or documents with vision
- Using tools/function calling (see anthropic/tool-use)
- Getting structured JSON output
- Extended thinking for complex reasoning

## Prerequisites

- `ANTHROPIC_API_KEY` environment variable set
- `anthropic` Python package or `@anthropic-ai/sdk` npm package installed

## Workflow

1. Initialize the client (reads `ANTHROPIC_API_KEY` automatically)
2. Choose a model: `claude-opus-4-6`, `claude-sonnet-4-6`, or `claude-haiku-4-5`
3. Set `max_tokens` based on expected response length
4. Build your messages array with alternating user/assistant roles
5. Optionally add a system prompt, tools, or temperature
6. Call `client.messages.create()` and process the response

## Basic Usage (Python)

```python
import anthropic

client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain recursion in one paragraph"}]
)
print(message.content[0].text)
```

## Basic Usage (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();
const message = await client.messages.create({
  model: "claude-sonnet-4-6",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Explain recursion in one paragraph" }]
});
console.log(message.content[0].text);
```

## Multi-Turn Conversation

```python
messages = [
    {"role": "user", "content": "What is the capital of France?"},
    {"role": "assistant", "content": "The capital of France is Paris."},
    {"role": "user", "content": "What is its population?"}
]
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=messages
)
```

The API is stateless — send the full history each time. Use prompt caching for long histories.

## Vision (Images)

```python
import base64

with open("chart.png", "rb") as f:
    data = base64.standard_b64encode(f.read()).decode()

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": data}},
            {"type": "text", "text": "Describe this chart"}
        ]
    }]
)
```

## System Prompt

```python
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="You are a senior Python developer. Be concise.",
    messages=[{"role": "user", "content": "Review this code: ..."}]
)
```

## Extended Thinking

```python
message = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=16384,
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[{"role": "user", "content": "Solve this math problem step by step: ..."}]
)
for block in message.content:
    if block.type == "thinking":
        print("Thinking:", block.thinking)
    elif block.type == "text":
        print("Answer:", block.text)
```

## Response Handling

```python
message = client.messages.create(...)

# Check stop reason
if message.stop_reason == "end_turn":
    print("Complete response")
elif message.stop_reason == "max_tokens":
    print("Response truncated — increase max_tokens")
elif message.stop_reason == "tool_use":
    print("Claude wants to call a tool")

# Token usage
print(f"Input: {message.usage.input_tokens}, Output: {message.usage.output_tokens}")
```

## Edge Cases

- **Empty content**: Content must not be empty. At minimum, send a text string.
- **Role alternation**: Messages must alternate user/assistant. Consecutive same-role messages are merged.
- **Max tokens**: If response is truncated (stop_reason: max_tokens), increase max_tokens or paginate.
- **Rate limits**: Handle 429 errors with exponential backoff. Check `retry-after` header.
- **Token counting**: Use `POST /v1/messages/count_tokens` to pre-count tokens before sending.

## Key Parameters Reference

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `model` | string | required | e.g., `claude-sonnet-4-6` |
| `max_tokens` | int | required | Up to model max (64k–128k) |
| `messages` | array | required | Alternating user/assistant |
| `system` | string | — | System prompt |
| `temperature` | float | 1.0 | 0.0–1.0 |
| `stream` | bool | false | Enable SSE streaming |
| `tools` | array | — | Tool definitions |
| `thinking` | object | — | Extended thinking config |
