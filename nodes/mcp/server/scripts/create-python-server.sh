#!/bin/bash
# Scaffold a new Python MCP server project with FastMCP.
#
# Creates a project directory with a virtual environment, installs the MCP SDK,
# and generates a server.py with example tool, resource, and prompt.
#
# Usage:
#   SERVER_NAME=my-server bash create-python-server.sh
#   bash create-python-server.sh  # defaults to "my-mcp-server"
#
# Requires: Python 3.10+, uv (or pip)

set -e

SERVER_NAME="${SERVER_NAME:-my-mcp-server}"

echo "Creating MCP server project: $SERVER_NAME"

mkdir -p "$SERVER_NAME" && cd "$SERVER_NAME"

# Set up Python project with uv if available, else pip
if command -v uv &>/dev/null; then
    uv init 2>/dev/null || true
    uv venv 2>/dev/null || true
    uv add 'mcp[cli]'
else
    python3 -m venv .venv
    .venv/bin/pip install -q 'mcp[cli]'
    echo "Activate with: source .venv/bin/activate"
fi

cat > server.py << 'PYEOF'
"""MCP server with example tool, resource, and prompt.

Run:
    python server.py            # stdio transport
    mcp dev server.py           # MCP Inspector
    mcp install server.py       # Install into Claude Desktop
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-mcp-server")


@mcp.tool()
def hello(name: str) -> str:
    """Greet someone by name."""
    return f"Hello, {name}!"


@mcp.resource("info://server")
def server_info() -> str:
    """Return server information."""
    return "MCP Server v1.0.0"


@mcp.prompt()
def ask_question(topic: str) -> str:
    """Create a prompt to ask about a topic."""
    return f"Please explain {topic} in detail."


if __name__ == "__main__":
    mcp.run()
PYEOF

echo ""
echo "Server created at $SERVER_NAME/server.py"
echo "Run with:   cd $SERVER_NAME && python server.py"
echo "Debug with: cd $SERVER_NAME && mcp dev server.py"
echo "Install:    cd $SERVER_NAME && mcp install server.py"
