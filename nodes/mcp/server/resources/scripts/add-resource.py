#!/usr/bin/env python3
"""Example MCP server demonstrating how to add resources with FastMCP.

Shows resource definition patterns: static resources, JSON data,
and URI templates for parameterized access.

Usage:
    python add-resource.py
    npx @modelcontextprotocol/inspector python add-resource.py

Requires: pip install "mcp[cli]"
"""

import json
import sys

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("resource-example")


@mcp.resource("config://app")
def app_config() -> str:
    """Application configuration as JSON."""
    return json.dumps({
        "version": "1.0.0",
        "database": "postgresql://localhost/mydb",
        "features": ["search", "analytics"],
    }, indent=2)


@mcp.resource("schema://tables")
def table_schema() -> str:
    """Database table definitions as SQL DDL."""
    return (
        "CREATE TABLE users (\n"
        "  id SERIAL PRIMARY KEY,\n"
        "  name TEXT NOT NULL,\n"
        "  email TEXT UNIQUE NOT NULL,\n"
        "  created_at TIMESTAMPTZ DEFAULT NOW()\n"
        ");\n\n"
        "CREATE TABLE posts (\n"
        "  id SERIAL PRIMARY KEY,\n"
        "  author_id INT REFERENCES users(id),\n"
        "  title TEXT NOT NULL,\n"
        "  body TEXT,\n"
        "  published_at TIMESTAMPTZ\n"
        ");"
    )


if __name__ == "__main__":
    print("Starting resource-example MCP server...", file=sys.stderr)
    mcp.run()
