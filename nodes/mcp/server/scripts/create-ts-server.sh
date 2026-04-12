#!/bin/bash
# Scaffold a new TypeScript MCP server project with McpServer.
#
# Creates a project directory, installs the MCP SDK and Zod,
# and generates a server.js with an example tool.
#
# Usage:
#   SERVER_NAME=my-server bash create-ts-server.sh
#   bash create-ts-server.sh  # defaults to "my-mcp-server"
#
# Requires: Node.js 18+, npm

set -e

SERVER_NAME="${SERVER_NAME:-my-mcp-server}"

echo "Creating TypeScript MCP server project: $SERVER_NAME"

mkdir -p "$SERVER_NAME" && cd "$SERVER_NAME"

# Initialize package.json as ESM
cat > package.json << 'JSONEOF'
{
  "name": "my-mcp-server",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "scripts": {
    "start": "node server.js"
  }
}
JSONEOF

npm install @modelcontextprotocol/sdk zod

cat > server.js << 'JSEOF'
/**
 * MCP server with example tool.
 *
 * Run:   node server.js
 * Or:    npx @modelcontextprotocol/inspector node server.js
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-mcp-server", version: "1.0.0" });

server.tool(
  "hello",
  "Greet someone by name",
  { name: z.string().describe("Person to greet") },
  async ({ name }) => ({
    content: [{ type: "text", text: `Hello, ${name}!` }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
JSEOF

echo ""
echo "Server created at $SERVER_NAME/server.js"
echo "Run with:    cd $SERVER_NAME && node server.js"
echo "Inspect with: npx @modelcontextprotocol/inspector node server.js"
