---
name: tools
description: Define MCP tools — executable functions that LLMs discover and invoke. Use when adding callable functions to an MCP server for AI model interaction.
---

# MCP Tools

Define executable functions that AI models can discover and invoke via the Model Context Protocol.

## When to Use

- Adding callable functions to an MCP server
- Exposing API endpoints as tools for AI models
- Creating computation tools (math, search, data processing)
- Wrapping CLI commands as MCP tools

## Workflow

1. Import FastMCP (Python) or McpServer (TypeScript)
2. Define tool function with typed parameters and docstring
3. Decorate with `@mcp.tool()` or call `server.tool()`
4. Tool is automatically discoverable via `tools/list`
5. LLM invokes via `tools/call` with arguments matching inputSchema

## Python

```python
@mcp.tool()
def search(query: str, limit: int = 10) -> str:
    """Search for items matching the query."""
    results = do_search(query, limit)
    return json.dumps(results)

@mcp.tool()
async def fetch_url(url: str) -> str:
    """Fetch content from a URL."""
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.text
```

## TypeScript

```typescript
server.tool("search", "Search for items", {
  query: z.string(),
  limit: z.number().default(10)
}, async ({ query, limit }) => ({
  content: [{ type: "text", text: JSON.stringify(doSearch(query, limit)) }]
}));
```

## Response Format

Tools return content arrays:
```json
{
  "content": [{"type": "text", "text": "result"}],
  "isError": false
}
```

For errors: set `isError: true` with descriptive text.

## Edge Cases

- Tool names must be unique within a server
- Functions can be sync or async (Python)
- Return strings from Python tools (FastMCP handles wrapping)
- TypeScript tools must return `{content: [...]}` objects
- Validate inputs server-side even with schema validation
- Use `annotations` for destructive tools requiring confirmation
