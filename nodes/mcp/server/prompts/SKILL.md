---
name: mcp-server-prompts
description: Expose reusable prompt templates via MCP — structured message sequences for code review, debugging, analysis. Use when adding prompts to an MCP server.
---

# MCP Server Prompts

Expose reusable prompt templates that users can select to structure LLM interactions.

## When to Use

- Adding reusable prompt templates to an MCP server
- Creating slash commands for users
- Building multi-turn conversation starters
- Implementing few-shot example prompts

## Workflow

### 1. Define Prompts

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.prompt()
def code_review(code: str, language: str = "python") -> str:
    """Review code for bugs, security, and style."""
    return f"Review this {language} code:\n\n```{language}\n{code}\n```"

@mcp.prompt()
def explain_error(error: str) -> str:
    """Explain an error message and suggest fixes."""
    return f"Explain this error and suggest fixes:\n\n{error}"
```

### 2. Test

```bash
npx @modelcontextprotocol/inspector python server.py
```

In the Inspector, navigate to the Prompts tab to list and test prompts.

## Best Practices

1. **Descriptive names** — Use clear names that work as slash commands: `code_review`, `debug_error`
2. **Useful defaults** — Make arguments optional where sensible
3. **Rich context** — Include embedded resources when prompts need data
4. **Clear descriptions** — Help users understand when to use each prompt
