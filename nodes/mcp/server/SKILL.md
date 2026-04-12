---
name: server
description: Build MCP servers that expose tools, resources, and prompts to AI applications. Use when creating a new MCP server, adding capabilities to an existing server, or deploying servers for Claude Desktop, VS Code, or other MCP hosts.
---

# MCP Server

Build servers that expose tools, resources, and prompts via the Model Context Protocol.

## When to Use

- Creating a new MCP server from scratch
- Adding tools, resources, or prompts to a server
- Configuring server transport (stdio or HTTP)
- Deploying a server to Claude Desktop or another host
- Debugging MCP server issues

## Workflow

1. Choose language: Python (`mcp[cli]`) or TypeScript (`@modelcontextprotocol/sdk`)
2. Initialize server: `FastMCP("name")` or `new McpServer({name, version})`
3. Register primitives: tools (`@mcp.tool()`), resources (`@mcp.resource(uri)`), prompts (`@mcp.prompt()`)
4. Choose transport: stdio (local) or Streamable HTTP (remote)
5. Run and test: `mcp dev server.py` for inspector, or configure in host app
6. Deploy: `mcp install server.py` for Claude Desktop, or host HTTP endpoint

## Python Quick Reference

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("server-name")

# Tool — model-controlled, LLM invokes it
@mcp.tool()
def search(query: str, limit: int = 10) -> str:
    """Search for items matching the query."""
    return json.dumps(do_search(query, limit))

# Resource — application-controlled context data
@mcp.resource("schema://main")
def get_schema() -> str:
    """Database schema for context."""
    return schema_ddl

# Prompt — user-controlled interaction template
@mcp.prompt()
def review(code: str) -> str:
    """Create a code review prompt."""
    return f"Review this code:\n\n{code}"

if __name__ == "__main__":
    mcp.run()
```

## TypeScript Quick Reference

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "server-name", version: "1.0.0" });

server.tool("search", { query: z.string(), limit: z.number().default(10) },
  async ({ query, limit }) => ({
    content: [{ type: "text", text: JSON.stringify(doSearch(query, limit)) }]
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

## Configuration

Claude Desktop (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "my-server": {
      "command": "python",
      "args": ["/path/to/server.py"]
    }
  }
}
```

## Testing

```bash
# Interactive inspector
mcp dev server.py

# Install into Claude Desktop
mcp install server.py --name "My Server"
```

## Edge Cases

- stdio servers must never print to stdout — use stderr or logging
- FastMCP generates schema from type hints; use `Annotated[str, "description"]` for richer schemas
- Tool functions can be sync or async
- Resource URIs must be unique within the server
- Prompt names must be unique within the server
- Server must handle `initialize` before any primitive operations
