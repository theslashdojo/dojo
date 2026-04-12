---
name: resources
description: Define MCP resources — data sources identified by URIs that provide contextual information to AI applications. Use when exposing files, schemas, configs, or other data via an MCP server.
---

# MCP Resources

Expose data sources via URIs for AI applications to read as context.

## When to Use

- Exposing database schemas, configs, or documentation as context
- Providing file access through MCP
- Creating parameterized data sources with URI templates
- Enabling real-time data subscriptions

## Workflow

1. Define resource with a URI: `@mcp.resource("scheme://path")`
2. Return text (string) or binary (bytes) content
3. For parameterized access, use URI templates: `"file:///{path}"`
4. Optionally enable subscriptions for change notifications
5. Clients discover via `resources/list` and read via `resources/read`

## Python

```python
@mcp.resource("schema://database")
def get_schema() -> str:
    """Database schema for AI context."""
    return db.get_schema_ddl()

@mcp.resource("file:///{path}")
def read_file(path: str) -> str:
    """Read a project file by path."""
    with open(path) as f:
        return f.read()
```

## TypeScript

```typescript
server.resource("schema", "schema://database", async (uri) => ({
  contents: [{
    uri: uri.href,
    mimeType: "text/plain",
    text: db.getSchema()
  }]
}));
```

## URI Schemes

- `file://` — filesystem resources
- `https://` — web resources
- `git://` — version control
- Custom (`schema://`, `config://`, `db://`) — application-specific

## Edge Cases

- Resource URIs must be unique within a server
- Text content uses `text` field; binary uses `blob` (base64)
- URI templates use RFC 6570 syntax: `{param}`
- Subscriptions require `subscribe: true` in capabilities
- Resources not returned by `resources/list` may still exist (dynamic/template)
