---
name: prompts
description: Define MCP prompts — reusable interaction templates that surface as slash commands. Use when creating structured conversation starters for AI model interactions via MCP.
---

# MCP Prompts

Create reusable interaction templates that users select to structure conversations.

## When to Use

- Creating slash commands for common tasks (code review, analysis, debugging)
- Building structured conversation starters with parameters
- Embedding resources into prompt context
- Setting up multi-turn conversation patterns

## Workflow

1. Define prompt function with typed arguments
2. Decorate with `@mcp.prompt()` or call `server.prompt()`
3. Return a string (single message) or list of messages (multi-turn)
4. Prompt surfaces as slash command or menu item in host app
5. User selects prompt, provides arguments, conversation starts

## Python

```python
@mcp.prompt()
def review_code(code: str) -> str:
    """Review code for quality and suggest improvements."""
    return f"Review this code:\n\n```\n{code}\n```"

@mcp.prompt()
def debug_error(error: str, language: str = "python") -> str:
    """Debug an error message."""
    return f"Explain this {language} error and suggest fixes:\n\n{error}"
```

## TypeScript

```typescript
server.prompt("review_code", "Review code quality", {
  code: z.string()
}, async ({ code }) => ({
  messages: [{
    role: "user",
    content: { type: "text", text: `Review this code:\n\n${code}` }
  }]
}));
```

## Multi-Turn Prompts

Return a list to set up conversation context:

```python
@mcp.prompt()
def debug_session(error: str, code: str) -> list:
    """Start an interactive debugging session."""
    return [
        {"role": "user", "content": f"Here's my code:\n{code}"},
        {"role": "assistant", "content": "I see the code. What's the issue?"},
        {"role": "user", "content": f"I get this error:\n{error}"}
    ]
```

## Embedding Resources

```python
@mcp.prompt()
def analyze_schema() -> list:
    """Analyze database schema with live data."""
    return [{"role": "user", "content": [
        {"type": "text", "text": "Analyze this schema:"},
        {"type": "resource", "resource": {
            "uri": "schema://database",
            "text": db.get_schema()
        }}
    ]}]
```

## Edge Cases

- Prompt names must be unique within a server
- Arguments are optional by default unless marked required
- Return string for simple prompts, list for multi-turn
- Resources embedded in prompts are fetched at retrieval time
- Prompts support pagination if there are many
