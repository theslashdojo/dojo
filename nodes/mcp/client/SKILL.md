---
name: mcp-client
description: Build MCP clients that connect to servers, discover tools, and route LLM tool calls. Use when creating a host application that integrates with MCP servers.
---

# MCP Client Development

Build client applications that connect to MCP servers and integrate their capabilities with LLMs.

## When to Use

- Building a chatbot or IDE that connects to MCP servers
- Integrating MCP tools with Claude or another LLM
- Managing connections to multiple MCP servers
- Routing LLM tool calls to the appropriate MCP server

## Prerequisites

- Python 3.10+ with `mcp` and `anthropic` packages, OR
- Node.js 18+ with `@modelcontextprotocol/sdk` package

## Workflow

### 1. Set Up the Client

```bash
uv init mcp-client && cd mcp-client
uv add mcp anthropic python-dotenv
```

### 2. Connect to a Server

```python
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

server_params = StdioServerParameters(
    command="python",
    args=["path/to/server.py"]
)

async with stdio_client(server_params) as (read, write):
    async with ClientSession(read, write) as session:
        await session.initialize()
        tools = await session.list_tools()
```

### 3. Integrate with LLM

```python
import anthropic

client = anthropic.Anthropic()

# Convert MCP tools to Anthropic format
anthropic_tools = [
    {"name": t.name, "description": t.description, "input_schema": t.inputSchema}
    for t in tools.tools
]

# Agentic tool-use loop
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=messages,
    tools=anthropic_tools
)
```

### 4. Route Tool Calls

```python
for block in response.content:
    if block.type == "tool_use":
        result = await session.call_tool(block.name, block.input)
```

## Key Patterns

1. **Always initialize** — Call `session.initialize()` before any other operations
2. **Aggregate tools** — Collect tools from all servers into one list for the LLM
3. **Map tools to sessions** — Maintain a lookup from tool name to session for routing
4. **Handle notifications** — Listen for `list_changed` to stay current
5. **Graceful disconnection** — Use context managers to ensure clean shutdown
