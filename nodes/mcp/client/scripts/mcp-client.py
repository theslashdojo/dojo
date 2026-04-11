#!/usr/bin/env python3
"""MCP client that connects to a server and demonstrates tool discovery and invocation.

Connects to an MCP server via stdio, lists capabilities, and
provides an interactive REPL for calling tools.

Usage:
    python mcp-client.py path/to/server.py

Requires: pip install mcp anthropic
"""

import asyncio
import json
import sys

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except ImportError:
    print("Error: Install mcp package: pip install mcp", file=sys.stderr)
    sys.exit(1)


async def main():
    if len(sys.argv) < 2:
        print("Usage: python mcp-client.py <server-script>", file=sys.stderr)
        print("  e.g., python mcp-client.py ../server/scripts/create-server.py", file=sys.stderr)
        sys.exit(1)

    server_script = sys.argv[1]
    is_python = server_script.endswith(".py")
    is_js = server_script.endswith(".js")

    if not (is_python or is_js):
        print("Error: Server script must be a .py or .js file", file=sys.stderr)
        sys.exit(1)

    command = "python" if is_python else "node"
    server_params = StdioServerParameters(
        command=command,
        args=[server_script],
        env=None,
    )

    print(f"Connecting to MCP server: {command} {server_script}", file=sys.stderr)

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Connected and initialized.", file=sys.stderr)

            # List tools
            tools_response = await session.list_tools()
            tools = tools_response.tools
            print(f"\nAvailable tools ({len(tools)}):")
            for tool in tools:
                print(f"  - {tool.name}: {tool.description}")

            # List resources
            try:
                resources_response = await session.list_resources()
                resources = resources_response.resources
                print(f"\nAvailable resources ({len(resources)}):")
                for res in resources:
                    print(f"  - {res.uri}: {res.name}")
            except Exception:
                print("\nNo resources available.")

            # List prompts
            try:
                prompts_response = await session.list_prompts()
                prompts = prompts_response.prompts
                print(f"\nAvailable prompts ({len(prompts)}):")
                for p in prompts:
                    print(f"  - {p.name}: {p.description}")
            except Exception:
                print("\nNo prompts available.")

            # Interactive tool calling
            print("\n--- Interactive Tool Caller ---")
            print("Enter: tool_name {\"arg\": \"value\"}")
            print("Type 'quit' to exit.\n")

            while True:
                try:
                    line = input("> ").strip()
                except (EOFError, KeyboardInterrupt):
                    break

                if line.lower() in ("quit", "exit", "q"):
                    break

                if not line:
                    continue

                parts = line.split(" ", 1)
                tool_name = parts[0]
                arguments = {}
                if len(parts) > 1:
                    try:
                        arguments = json.loads(parts[1])
                    except json.JSONDecodeError as e:
                        print(f"Invalid JSON arguments: {e}")
                        continue

                try:
                    result = await session.call_tool(tool_name, arguments=arguments)
                    for content in result.content:
                        if hasattr(content, "text"):
                            print(content.text)
                        else:
                            print(f"[{content.type}]")
                    if result.isError:
                        print("(tool returned an error)")
                except Exception as e:
                    print(f"Error calling tool: {e}")

    print("\nDisconnected.", file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())
