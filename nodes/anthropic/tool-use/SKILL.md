---
name: tool-use
description: Connect Claude to external tools and functions for agentic workflows. Use when Claude needs to take actions, fetch data, or interact with external systems.
---

# Tool Use

Give Claude the ability to call functions you define.

## When to Use

- Claude needs to fetch real-time data (weather, stock prices, databases)
- Building agents that take actions (file operations, API calls, deployments)
- Structured data extraction (force specific output via tool_choice)
- Any workflow where Claude needs to interact with external systems

## Workflow

1. Define tools with name, description, and input_schema
2. Send messages with tools array
3. If stop_reason is "tool_use", extract tool_use blocks
4. Execute each tool with the provided input
5. Send tool_result blocks back (matching tool_use_id)
6. Repeat until stop_reason is "end_turn"

## Defining Tools

```python
tools = [{
    "name": "get_weather",
    "description": "Get current weather for a location. Returns temperature and conditions.",
    "input_schema": {
        "type": "object",
        "properties": {
            "location": {"type": "string", "description": "City, e.g. 'San Francisco, CA'"},
            "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
        },
        "required": ["location"]
    }
}]
```

## The Agentic Loop

```python
messages = [{"role": "user", "content": "What's the weather?"}]

while True:
    response = client.messages.create(
        model="claude-sonnet-4-6", max_tokens=1024,
        tools=tools, messages=messages
    )
    messages.append({"role": "assistant", "content": response.content})

    if response.stop_reason == "end_turn":
        break

    results = []
    for block in response.content:
        if block.type == "tool_use":
            output = execute(block.name, block.input)
            results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": output
            })
    messages.append({"role": "user", "content": results})
```

## Tool Choice

- `{"type": "auto"}` — Claude decides (default)
- `{"type": "any"}` — Must use at least one tool
- `{"type": "tool", "name": "get_weather"}` — Must use specific tool
- `{"type": "none"}` — Cannot use tools

## Best Practices

- Write clear, specific tool descriptions — they guide Claude's decision
- Include parameter descriptions with examples
- Use `strict: true` for guaranteed schema conformance
- Return errors via `is_error: true` on tool_result
- Cache tool definitions with prompt caching to save tokens
- Handle multiple tool calls in a single response

## Edge Cases

- Claude may call multiple tools in one response — handle all of them
- Missing required parameters: Opus asks for clarification, Sonnet may guess
- Tool input JSON may be malformed on rare occasions — validate before executing
- Long tool results consume input tokens on the next turn
