#!/usr/bin/env python3
"""MCP server demonstrating tool definition patterns.

Exposes tools that showcase text results, error handling,
and structured output. Use as a reference for building tool-rich servers.

Usage:
    python tool-server.py
    npx @modelcontextprotocol/inspector python tool-server.py

Requires: pip install "mcp[cli]" httpx
"""

import json
import sys
import hashlib
import math
from datetime import datetime, timezone

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("tool-examples")


@mcp.tool()
async def calculate(expression: str) -> str:
    """Evaluate a mathematical expression.

    Supports basic arithmetic (+, -, *, /, **), math functions
    (sqrt, sin, cos, tan, log, pi, e), and parentheses.

    Args:
        expression: Math expression to evaluate, e.g. "sqrt(144) + 2**3"
    """
    allowed_names = {
        k: v for k, v in math.__dict__.items()
        if not k.startswith("__")
    }
    allowed_names.update({"abs": abs, "round": round, "int": int, "float": float})
    try:
        result = eval(expression, {"__builtins__": {}}, allowed_names)
        return json.dumps({"expression": expression, "result": result})
    except Exception as e:
        return json.dumps({"expression": expression, "error": str(e)})


@mcp.tool()
async def hash_text(text: str, algorithm: str = "sha256") -> str:
    """Compute a cryptographic hash of the given text.

    Args:
        text: The text to hash
        algorithm: Hash algorithm — sha256, sha512, md5, sha1
    """
    if algorithm not in hashlib.algorithms_available:
        return json.dumps({"error": f"Unknown algorithm: {algorithm}. Available: {sorted(hashlib.algorithms_available)}"})
    h = hashlib.new(algorithm)
    h.update(text.encode("utf-8"))
    return json.dumps({"algorithm": algorithm, "hash": h.hexdigest(), "length": len(text)})


@mcp.tool()
async def json_validate(data: str) -> str:
    """Validate and pretty-print a JSON string.

    Args:
        data: JSON string to validate
    """
    try:
        parsed = json.loads(data)
        return json.dumps({
            "valid": True,
            "formatted": json.dumps(parsed, indent=2),
            "type": type(parsed).__name__,
            "size": len(data),
        })
    except json.JSONDecodeError as e:
        return json.dumps({
            "valid": False,
            "error": str(e),
            "position": e.pos,
        })


@mcp.tool()
async def timestamp(format: str = "iso") -> str:
    """Get the current UTC timestamp.

    Args:
        format: Output format — iso, unix, or human
    """
    now = datetime.now(timezone.utc)
    if format == "unix":
        return json.dumps({"timestamp": now.timestamp(), "format": "unix"})
    elif format == "human":
        return json.dumps({"timestamp": now.strftime("%B %d, %Y %I:%M:%S %p UTC"), "format": "human"})
    else:
        return json.dumps({"timestamp": now.isoformat(), "format": "iso"})


if __name__ == "__main__":
    print("Starting tool-examples MCP server...", file=sys.stderr)
    mcp.run()
