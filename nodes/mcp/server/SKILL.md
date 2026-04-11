---
name: mcp-server
description: Build MCP servers that expose tools, resources, and prompts to AI agents. Use when creating a new MCP server, adding capabilities to an existing server, or debugging server issues.
---

# MCP Server Development

Build servers that expose tools, resources, and prompts through the Model Context Protocol.

## When to Use

- Creating a new MCP server from scratch
- Adding tools, resources, or prompts to an existing server
- Configuring server transport (stdio vs HTTP)
- Debugging MCP server issues
- Testing servers with the MCP Inspector

## Prerequisites

- Python 3.10+ with `mcp[cli]` package, OR
- Node.js 18+ with `@modelcontextprotocol/sdk` package

## Workflow

### 1. Scaffold the Server

**Python:**
```bash
uv init my-server && cd my-server
uv add "mcp[cli]"
```

**TypeScript:**
```bash
npm init -y
npm install @modelcontextprotocol/sdk zod
```

### 2. Define Capabilities

Choose which primitives your server exposes:
- **Tools** — Functions the LLM can call (model-controlled)
- **Resources** — Data the application can read (application-controlled)
- **Prompts** — Templates the user can select (user-controlled)

### 3. Implement the Server

**Python (FastMCP):**
```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool()
async def search(query: str) -> str:
    """Search the knowledge base."""
    results = await kb.search(query)
    return json.dumps(results)

@mcp.resource("docs://readme")
def readme() -> str:
    """Project README."""
    return open("README.md").read()

@mcp.prompt()
def expert(domain: str) -> str:
    """Act as a domain expert."""
    return f"You are an expert in {domain}. Answer questions precisely."

if __name__ == "__main__":
    mcp.run()
```

**TypeScript:**
```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-server", version: "1.0.0" });

server.tool("search", { query: z.string() }, async ({ query }) => ({
  content: [{ type: "text", text: JSON.stringify(await kb.search(query)) }]
}));

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 4. Test with MCP Inspector

```bash
npx @modelcontextprotocol/inspector python server.py
```

The Inspector opens a web UI where you can:
- List all registered tools, resources, and prompts
- Call tools with test arguments
- Read resources
- View JSON-RPC message exchange

### 5. Configure in a Host

Add to Claude Desktop's `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "python",
      "args": ["path/to/server.py"]
    }
  }
}
```

## Key Rules

1. **STDIO servers must never write to stdout** — it corrupts JSON-RPC. Use `stderr`.
2. **Always validate tool inputs** — the server is a trust boundary.
3. **Declare capabilities honestly** — only advertise what you implement.
4. **Use descriptive tool names and descriptions** — LLMs rely on these to select tools.
5. **Return structured errors** — use `isError: true` in tool results for execution failures.

## Edge Cases

- **Tool not found**: Return JSON-RPC error code `-32602`
- **Tool execution failure**: Return result with `isError: true` and error message in content
- **Server crash**: The host will see the subprocess exit; log to stderr before crashing
- **Large responses**: Consider pagination or streaming for large datasets
- **Concurrent requests**: Both Python and TypeScript SDKs handle concurrent JSON-RPC requests

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MCP_SERVER_NAME` | No | Server name (defaults to script name) |
| `MCP_TRANSPORT` | No | `stdio` or `streamable-http` |
| `MCP_PORT` | No | Port for HTTP transport (default 8000) |
