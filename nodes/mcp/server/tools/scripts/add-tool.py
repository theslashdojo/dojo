#!/usr/bin/env python3
"""Example MCP server demonstrating how to add tools with FastMCP.

Shows tool definition patterns: typed parameters, docstrings,
default values, sync and async handlers.

Usage:
    python add-tool.py
    npx @modelcontextprotocol/inspector python add-tool.py

Requires: pip install "mcp[cli]"
"""

import sys

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("tool-example")


@mcp.tool()
def greet(name: str, language: str = "en") -> str:
    """Greet someone in a specified language.

    Args:
        name: Person to greet
        language: Language code — en, es, fr, de, ja
    """
    greetings = {
        "en": "Hello",
        "es": "Hola",
        "fr": "Bonjour",
        "de": "Hallo",
        "ja": "こんにちは",
    }
    greeting = greetings.get(language, "Hello")
    return f"{greeting}, {name}!"


@mcp.tool()
async def word_count(text: str) -> str:
    """Count words, characters, and lines in the given text.

    Args:
        text: The text to analyze
    """
    import json
    return json.dumps({
        "words": len(text.split()),
        "characters": len(text),
        "lines": text.count("\n") + 1,
    })


if __name__ == "__main__":
    print("Starting tool-example MCP server...", file=sys.stderr)
    mcp.run()
