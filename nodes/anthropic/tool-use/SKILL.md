---
name: tool-use
description: Define callable tools for Claude and handle the agentic tool use loop — use when Claude needs to interact with external systems, fetch data, or take actions
---

# Tool Use (Function Calling)

Give Claude tools it can call. Build agentic loops where Claude decides what to do, calls tools, and continues.

## When to Use

- Claude needs to access external data (APIs, databases, files)
- Building an agent that takes actions in the real world
- Structured data extraction (force a specific output schema)
- Connecting Claude to your application's capabilities

## Prerequisites

- `ANTHROPIC_API_KEY` set in environment
- `pip install anthropic` or `npm install @anthropic-ai/sdk`

## Workflow

1. Define tools with `name`, `description`, and `input_schema` (JSON Schema)
2. Pass tools in the `tools` parameter of `messages.create()`
3. Check if `stop_reason == "tool_use"`
4. Execute each `tool_use` block's function with its `input`
5. Send `tool_result` blocks back with the output
6. Repeat until `stop_reason == "end_turn"`

## Defining a Tool

```python
tools = [{
    "name": "search_database",
    "description": "Search the product database by query. Returns matching products with name, price, and availability.",
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "Search query"},
            "limit": {"type": "integer", "description": "Max results (default 10)"}
        },
        "required": ["query"]
    }
}]
```

## Complete Loop

```python
import anthropic
import json

client = anthropic.Anthropic()

def search_database(query, limit=10):
    return [{"name": "Widget", "price": 9.99, "available": True}]

tools = [{
    "name": "search_database",
    "description": "Search products by query",
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {"type": "string"},
            "limit": {"type": "integer"}
        },
        "required": ["query"]
    }
}]

messages = [{"role": "user", "content": "Find widgets under $20"}]

while True:
    response = client.messages.create(
        model="claude-sonnet-4-6", max_tokens=1024,
        tools=tools, messages=messages
    )
    messages.append({"role": "assistant", "content": response.content})

    if response.stop_reason == "end_turn":
        for b in response.content:
            if b.type == "text": print(b.text)
        break

    if response.stop_reason == "tool_use":
        results = []
        for b in response.content:
            if b.type == "tool_use":
                result = search_database(**b.input)
                results.append({
                    "type": "tool_result",
                    "tool_use_id": b.id,
                    "content": json.dumps(result)
                })
        messages.append({"role": "user", "content": results})
```

## Tool Choice

```python
# Claude decides (default)
tool_choice = {"type": "auto"}

# Must use a tool
tool_choice = {"type": "any"}

# Must use specific tool
tool_choice = {"type": "tool", "name": "search_database"}

# Disable tools
tool_choice = {"type": "none"}
```

## Best Practices

- **Write clear descriptions** — Claude reads them to decide when to call tools
- **Use required fields** — Mark mandatory parameters
- **Return JSON** — Structured results work best
- **Use strict mode** — `"strict": True` guarantees schema conformance
- **Fewer tools = better** — Only include tools relevant to the task

## Edge Cases

- **Multiple tool calls**: Claude can call multiple tools in one turn. Execute all before sending results.
- **Missing parameters**: Opus asks for clarification; Sonnet may guess. Use clear descriptions.
- **Tool errors**: Return error messages in tool_result — Claude will handle them gracefully.
- **Recursive tools**: Claude may call tools repeatedly. Set a max loop count.
