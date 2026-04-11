---
name: mcp-server-resources
description: Expose contextual data via MCP resources — files, schemas, configs identified by URIs. Use when adding data sources to an MCP server or implementing resource subscriptions.
---

# MCP Server Resources

Expose contextual data sources that applications read to provide context to AI models.

## When to Use

- Adding data sources to an MCP server
- Exposing files, database schemas, or API data as resources
- Implementing resource templates for parameterized access
- Setting up resource subscriptions for real-time updates

## Workflow

### 1. Define Resources

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.resource("schema://database")
def database_schema() -> str:
    """Current database schema."""
    return open("schema.sql").read()

@mcp.resource("config://app")
def app_config() -> str:
    """Application configuration."""
    return json.dumps(config, indent=2)
```

### 2. Choose URI Schemes

- `file://` — Filesystem-like content
- `https://` — Web resources clients can fetch directly
- `db://`, `config://`, `schema://` — Custom application-specific schemes

### 3. Handle Binary Content

```python
@mcp.resource("file://logo")
def logo() -> bytes:
    """Company logo."""
    return open("logo.png", "rb").read()
```

### 4. Test

```bash
npx @modelcontextprotocol/inspector python server.py
```

## Best Practices

1. Use meaningful URI schemes that describe the data domain
2. Set appropriate MIME types for content
3. Keep resources focused — one concept per resource
4. Implement subscriptions for frequently changing data
5. Validate URIs before processing reads
