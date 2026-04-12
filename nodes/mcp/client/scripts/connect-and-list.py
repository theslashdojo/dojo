#!/usr/bin/env python3
"""Connect to an MCP server via stdio and list all available capabilities.

A lightweight discovery script that connects to any MCP server and
prints its tools, resources, and prompts. Use it to inspect what
a server exposes before integrating.

Usage:
    python connect-and-list.py python server.py
    python connect-and-list.py node server.js
    python connect-and-list.py npx -y @modelcontextprotocol/server-filesystem /tmp

Requires: pip install mcp
"""

import asyncio
import sys

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except ImportError:
    print("Error: Install mcp package: pip install mcp", file=sys.stderr)
    sys.exit(1)


async def main():
    if len(sys.argv) < 2:
        print("Usage: python connect-and-list.py <server-command> [args...]", file=sys.stderr)
        print("  e.g., python connect-and-list.py python server.py", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    args = sys.argv[2:]
    params = StdioServerParameters(command=command, args=args)

    print(f"Connecting to: {command} {' '.join(args)}", file=sys.stderr)

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Connected.\n", file=sys.stderr)

            # List tools
            tools = await session.list_tools()
            print(f"Tools ({len(tools.tools)}):")
            for t in tools.tools:
                print(f"  {t.name}: {t.description}")

            # List resources
            try:
                resources = await session.list_resources()
                print(f"\nResources ({len(resources.resources)}):")
                for r in resources.resources:
                    print(f"  {r.uri}: {r.name}")
            except Exception:
                print("\nResources: (not supported)")

            # List prompts
            try:
                prompts = await session.list_prompts()
                print(f"\nPrompts ({len(prompts.prompts)}):")
                for p in prompts.prompts:
                    print(f"  {p.name}: {p.description}")
            except Exception:
                print("\nPrompts: (not supported)")


if __name__ == "__main__":
    asyncio.run(main())
