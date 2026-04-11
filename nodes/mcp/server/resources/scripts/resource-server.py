#!/usr/bin/env python3
"""MCP server demonstrating resource patterns.

Exposes resources showing text content, JSON data, and
dynamic content generation. Use as a reference for resource-rich servers.

Usage:
    python resource-server.py
    npx @modelcontextprotocol/inspector python resource-server.py

Requires: pip install "mcp[cli]"
"""

import json
import os
import sys
from datetime import datetime, timezone

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("resource-examples")


@mcp.resource("info://server")
def server_info() -> str:
    """Server metadata and runtime information."""
    return json.dumps({
        "name": "resource-examples",
        "version": "1.0.0",
        "python_version": sys.version,
        "platform": sys.platform,
        "pid": os.getpid(),
        "cwd": os.getcwd(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }, indent=2)


@mcp.resource("env://variables")
def env_summary() -> str:
    """Summary of environment variables (names only, no values for security)."""
    env_vars = sorted(os.environ.keys())
    return json.dumps({
        "count": len(env_vars),
        "variables": env_vars,
        "note": "Values redacted for security. Use specific tools to read individual values.",
    }, indent=2)


@mcp.resource("fs://cwd")
def working_directory() -> str:
    """List files in the current working directory."""
    cwd = os.getcwd()
    entries = []
    for entry in sorted(os.listdir(cwd)):
        path = os.path.join(cwd, entry)
        entries.append({
            "name": entry,
            "type": "directory" if os.path.isdir(path) else "file",
            "size": os.path.getsize(path) if os.path.isfile(path) else None,
        })
    return json.dumps({"directory": cwd, "entries": entries}, indent=2)


@mcp.resource("config://example")
def example_config() -> str:
    """Example application configuration."""
    return json.dumps({
        "database": {
            "host": "localhost",
            "port": 5432,
            "name": "myapp",
            "pool_size": 10,
        },
        "cache": {
            "backend": "redis",
            "ttl_seconds": 300,
        },
        "logging": {
            "level": "INFO",
            "format": "json",
        },
    }, indent=2)


if __name__ == "__main__":
    print("Starting resource-examples MCP server...", file=sys.stderr)
    mcp.run()
