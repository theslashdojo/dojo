#!/usr/bin/env python3
"""Build a simple autonomous agent with the Claude Agent SDK.

Demonstrates:
- Simple query
- Interactive session with options
- Custom MCP tools
- Permission control

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python agent-example.py

Requires: pip install claude-agent-sdk
"""

import os
import sys

try:
    import anyio
    from claude_agent_sdk import (
        query,
        ClaudeSDKClient,
        ClaudeAgentOptions,
        AssistantMessage,
        TextBlock,
        ToolUseBlock,
        tool,
        create_sdk_mcp_server,
    )
except ImportError:
    print("Error: pip install claude-agent-sdk", file=sys.stderr)
    sys.exit(1)


# ── Custom Tools ─────────────────────────────────────────────────────

@tool("get_time", "Get the current date and time", {})
async def get_time(args):
    """Return the current time."""
    from datetime import datetime
    now = datetime.now().isoformat()
    return {"content": [{"type": "text", "text": f"Current time: {now}"}]}


@tool("calculate", "Evaluate a math expression", {"expression": str})
async def calculate(args):
    """Safely evaluate a math expression."""
    expr = args["expression"]
    allowed = set("0123456789+-*/().% ")
    if not all(c in allowed for c in expr):
        return {"content": [{"type": "text", "text": "Error: invalid characters"}]}
    try:
        result = eval(expr)
        return {"content": [{"type": "text", "text": f"Result: {result}"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {e}"}]}


# ── Simple Query Demo ────────────────────────────────────────────────

async def demo_simple_query():
    """Demonstrate a simple one-shot query."""
    print("=== Simple Query ===")
    async for message in query(prompt="What is the capital of Japan? Reply in one word."):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    print(f"  {block.text}")
    print()


# ── Interactive Session Demo ─────────────────────────────────────────

async def demo_interactive_session():
    """Demonstrate an interactive session with custom tools."""
    print("=== Interactive Session with Custom Tools ===")

    # Create MCP server with custom tools
    server = create_sdk_mcp_server(
        name="demo-tools",
        version="1.0.0",
        tools=[get_time, calculate],
    )

    options = ClaudeAgentOptions(
        system_prompt="You are a helpful assistant with access to time and calculator tools.",
        mcp_servers={"demo": server},
        allowed_tools=["mcp__demo__get_time", "mcp__demo__calculate"],
        permission_mode="denyEdits",
        max_turns=3,
    )

    async with ClaudeSDKClient(options=options) as client:
        await client.query("What time is it, and what is 42 * 17?")
        async for msg in client.receive_response():
            if isinstance(msg, AssistantMessage):
                for block in msg.content:
                    if isinstance(block, TextBlock):
                        print(f"  {block.text}")
                    elif isinstance(block, ToolUseBlock):
                        print(f"  [Tool: {block.name}({block.input})]")
    print()


# ── Main ─────────────────────────────────────────────────────────────

async def main():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    await demo_simple_query()
    await demo_interactive_session()


if __name__ == "__main__":
    anyio.run(main)
