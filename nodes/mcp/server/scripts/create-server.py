#!/usr/bin/env python3
"""Scaffold and run a basic MCP server with example tools, resources, and prompts.

This script creates a minimal MCP server that demonstrates all three primitives.
Run it directly to start the server, or use it as a template for your own server.

Usage:
    python create-server.py
    # Or with MCP Inspector:
    npx @modelcontextprotocol/inspector python create-server.py

Environment:
    MCP_SERVER_NAME: Server name (default: "example-server")

Requires: pip install "mcp[cli]"
"""

import os
import json
import sys
from datetime import datetime

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: mcp package not installed. Run: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

server_name = os.environ.get("MCP_SERVER_NAME", "example-server")
mcp = FastMCP(server_name)


@mcp.tool()
async def echo(message: str) -> str:
    """Echo back the provided message. Useful for testing connectivity."""
    return f"Echo: {message}"


@mcp.tool()
async def get_timestamp() -> str:
    """Return the current UTC timestamp in ISO 8601 format."""
    return datetime.utcnow().isoformat() + "Z"


@mcp.tool()
async def json_format(data: str) -> str:
    """Pretty-print a JSON string. Returns formatted JSON or an error message."""
    try:
        parsed = json.loads(data)
        return json.dumps(parsed, indent=2)
    except json.JSONDecodeError as e:
        return f"Invalid JSON: {e}"


@mcp.resource("info://server")
def server_info() -> str:
    """Return server metadata as JSON."""
    return json.dumps({
        "name": server_name,
        "version": "1.0.0",
        "capabilities": ["tools", "resources", "prompts"],
        "python_version": sys.version,
    }, indent=2)


@mcp.prompt()
def code_review(code: str) -> str:
    """Generate a code review prompt for the given code."""
    return (
        "You are an expert code reviewer. Review the following code for:\n"
        "1. Bugs and logic errors\n"
        "2. Security vulnerabilities\n"
        "3. Performance issues\n"
        "4. Code style and readability\n\n"
        f"```\n{code}\n```"
    )


if __name__ == "__main__":
    print(f"Starting {server_name} MCP server...", file=sys.stderr)
    mcp.run()
