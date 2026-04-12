#!/usr/bin/env python3
"""Example MCP server demonstrating how to add prompts with FastMCP.

Shows prompt definition patterns: simple string return, parameterized
prompts, and multi-turn conversation starters.

Usage:
    python add-prompt.py
    npx @modelcontextprotocol/inspector python add-prompt.py

Requires: pip install "mcp[cli]"
"""

import sys

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Error: Install mcp package: pip install 'mcp[cli]'", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("prompt-example")


@mcp.prompt()
def review_code(code: str, focus: str = "quality") -> str:
    """Review code with a specific focus area.

    Args:
        code: Source code to review
        focus: Focus area — quality, security, performance, readability
    """
    return (
        f"Review this code focusing on {focus}:\n\n"
        f"```\n{code}\n```\n\n"
        f"Provide specific suggestions for improvement."
    )


@mcp.prompt()
def explain_concept(concept: str, audience: str = "developer") -> str:
    """Explain a technical concept for a specific audience.

    Args:
        concept: The concept to explain
        audience: Target audience — developer, manager, student, beginner
    """
    return f"Explain '{concept}' for a {audience}. Include examples and analogies."


@mcp.prompt()
def debug_session(error: str, code: str) -> list:
    """Start an interactive debugging session.

    Args:
        error: The error message or traceback
        code: The relevant source code
    """
    return [
        {"role": "user", "content": f"I have this code:\n\n```\n{code}\n```"},
        {"role": "assistant", "content": "I see the code. What issue are you experiencing?"},
        {"role": "user", "content": f"I'm getting this error:\n\n```\n{error}\n```"},
    ]


if __name__ == "__main__":
    print("Starting prompt-example MCP server...", file=sys.stderr)
    mcp.run()
