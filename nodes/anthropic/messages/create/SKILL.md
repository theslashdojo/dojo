---
name: create
description: Create a synchronous (non-streaming) message with Claude — use when you need the complete response before proceeding, in pipelines, or for batch-style processing
---

# Create Message (Synchronous)

Send a prompt to Claude and receive the complete response in one HTTP call.

## When to Use

- You need the full response before taking the next step
- Processing in automated pipelines
- Simple request/response patterns
- When streaming overhead is unnecessary

## Prerequisites

- `ANTHROPIC_API_KEY` set in environment
- `pip install anthropic` or `npm install @anthropic-ai/sdk`

## Workflow

1. Initialize the Anthropic client
2. Call `client.messages.create()` with model, max_tokens, messages
3. Access `message.content[0].text` for the response text
4. Check `message.stop_reason` to know if the response was complete
5. Read `message.usage` for token counts

## Python Example

```python
import anthropic

client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain async/await in Python"}]
)
print(message.content[0].text)
```

## Error Handling

```python
try:
    message = client.messages.create(...)
except anthropic.RateLimitError as e:
    retry_after = e.response.headers.get("retry-after", 60)
    time.sleep(int(retry_after))
except anthropic.AuthenticationError:
    print("Check your ANTHROPIC_API_KEY")
```

## Edge Cases

- **Truncated response**: `stop_reason == "max_tokens"` means the response was cut off. Increase `max_tokens`.
- **Tool use stop**: `stop_reason == "tool_use"` means Claude wants to call a tool. Handle the tool_use block.
- **Empty content**: Never happens on success. If content is empty, check for errors.
