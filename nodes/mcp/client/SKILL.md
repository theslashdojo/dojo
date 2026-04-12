---
name: client
description: Build MCP clients that connect to servers and invoke tools, resources, and prompts. Use when creating custom AI applications that need to integrate with MCP servers programmatically.
---

# MCP Client

Build clients that connect to MCP servers and use their tools, resources, and prompts.

## When to Use

- Building a custom AI application that connects to MCP servers
- Creating an agent framework with MCP integration
- Programmatically invoking MCP tools from code
- Testing MCP servers from a client perspective

## Workflow

1. Install SDK: `pip install mcp` or `npm install @modelcontextprotocol/sdk`
2. Create transport: stdio for local, HTTP for remote
3. Create client session and call `initialize()`
4. Discover primitives: `list_tools()`, `list_resources()`, `list_prompts()`
5. Use primitives: `call_tool()`, `read_resource()`, `get_prompt()`
6. Handle notifications for dynamic updates

## Python Quick Reference

```python
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async with stdio_client(StdioServerParameters(
    command="python", args=["server.py"]
)) as (read, write):
    async with ClientSession(read, write) as session:
        await session.initialize()

        # Discover
        tools = await session.list_tools()
        resources = await session.list_resources()

        # Use
        result = await session.call_tool("search", {"query": "test"})
        data = await session.read_resource("schema://main")
```

## TypeScript Quick Reference

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const client = new Client({ name: "my-client", version: "1.0.0" });
await client.connect(new StdioClientTransport({
  command: "python", args: ["server.py"]
}));

const tools = await client.listTools();
const result = await client.callTool("search", { query: "test" });
```

## LLM Integration Pattern

```python
# Get tools and format for LLM
tools = await session.list_tools()
llm_tools = [{"name": t.name, "description": t.description,
               "input_schema": t.inputSchema} for t in tools.tools]

# LLM decides to call a tool
response = anthropic.messages.create(model="claude-sonnet-4-6", tools=llm_tools, messages=msgs)

# Execute tool calls from LLM response
for block in response.content:
    if block.type == "tool_use":
        result = await session.call_tool(block.name, block.input)
```

## Edge Cases

- Always call `initialize()` before any other operations
- Handle `tools/list_changed` notifications to refresh tool list
- Remote servers may return 401 — implement OAuth flow (see mcp/auth)
- Sessions are 1:1 with servers — create one client per server
- Tool call results may contain multiple content blocks (text, image, resource)
