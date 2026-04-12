---
name: messages
description: Send conversational messages to Claude and receive structured responses. Use when building any application that needs to call the Claude API — chat, completion, analysis, or generation.
---

# Messages API

The Messages API is the single endpoint for all Claude interactions.

## When to Use

- Building a chatbot or conversational AI
- Generating text completions
- Analyzing documents or images
- Any programmatic interaction with Claude

## Workflow

1. Set `ANTHROPIC_API_KEY` environment variable
2. Install SDK: `pip install anthropic` or `npm install @anthropic-ai/sdk`
3. Create a client: `client = anthropic.Anthropic()`
4. Call `client.messages.create()` with model, max_tokens, and messages
5. Read `response.content[0].text` for the output

## Quick Reference

```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="You are a helpful assistant.",
    messages=[{"role": "user", "content": "Hello, Claude"}]
)
print(response.content[0].text)
```

## Parameters

### Required
- `model` — Model ID (`claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`)
- `max_tokens` — Maximum output tokens
- `messages` — Array of `{role, content}` turns

### Optional
- `system` — System prompt (string or content block array)
- `temperature` — 0.0 (deterministic) to 1.0 (creative)
- `stream` — Enable SSE streaming
- `tools` — Tool definitions for function calling
- `tool_choice` — How to use tools (auto, any, tool, none)
- `thinking` — Extended thinking configuration
- `output_config` — Structured JSON output schema

## Response Structure

```json
{
  "id": "msg_...",
  "role": "assistant",
  "content": [{"type": "text", "text": "..."}],
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 25, "output_tokens": 150}
}
```

## Multi-Turn Pattern

Append each response to the messages array and send the full history each time. There is no server-side session state.

## Error Handling

- `AuthenticationError` (401) — Invalid API key
- `RateLimitError` (429) — Read `retry-after` header, back off
- `BadRequestError` (400) — Invalid parameters
- SDK includes automatic retries for transient errors

## Edge Cases

- Messages must alternate user/assistant roles (consecutive same-role messages are merged)
- Empty content strings are not allowed
- Image content blocks require base64 data or URL source
- Max 100,000 messages per request
- Token limits vary by model — check `anthropic/models`
