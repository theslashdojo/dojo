---
name: mcp-server-tools
description: Define and expose MCP tools — executable functions that AI models discover and invoke. Use when adding tools to an MCP server or debugging tool invocation.
---

# MCP Server Tools

Define executable functions that AI models can discover and invoke through the Model Context Protocol.

## When to Use

- Adding a new tool to an MCP server
- Defining tool input schemas
- Handling tool execution errors
- Implementing structured tool output
- Debugging tool discovery or invocation

## Workflow

### 1. Define the Tool

**Python (FastMCP):**
```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool()
async def search_docs(query: str, limit: int = 10) -> str:
    """Search documentation by keyword.

    Args:
        query: Search query string
        limit: Maximum results to return (1-100)
    """
    results = await doc_search(query, limit)
    return json.dumps(results)
```

**TypeScript:**
```typescript
server.tool(
  "search_docs",
  "Search documentation by keyword",
  {
    query: z.string().describe("Search query string"),
    limit: z.number().min(1).max(100).default(10)
  },
  async ({ query, limit }) => ({
    content: [{ type: "text", text: JSON.stringify(await docSearch(query, limit)) }]
  })
);
```

### 2. Handle Errors

Return `isError: true` for execution failures:

```python
@mcp.tool()
async def fetch_url(url: str) -> str:
    """Fetch content from a URL."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, timeout=30.0)
            resp.raise_for_status()
            return resp.text
    except httpx.HTTPError as e:
        # Return error as tool result, not exception
        raise McpError(f"HTTP error: {e}")
```

### 3. Test with Inspector

```bash
npx @modelcontextprotocol/inspector python server.py
```

## Best Practices

1. **Descriptive names** — Use `verb_noun` format: `search_docs`, `create_issue`, `get_weather`
2. **Rich descriptions** — LLMs use descriptions to decide when to call tools
3. **Typed parameters** — Use specific types with constraints, not just `string`
4. **Graceful errors** — Return informative error messages, don't crash the server
5. **Validate inputs** — Never trust tool arguments blindly
6. **Idempotent when possible** — Retry-safe tools are more reliable
