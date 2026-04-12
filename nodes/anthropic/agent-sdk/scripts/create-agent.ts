#!/usr/bin/env npx tsx
/**
 * Build a simple autonomous agent with the Claude Agent SDK.
 *
 * Demonstrates:
 * - Creating an agent session
 * - Streaming events (text, tool_use, tool_result)
 * - Tool permissions and working directory
 *
 * Usage:
 *   ANTHROPIC_API_KEY=sk-ant-... npx tsx create-agent.ts
 *   ANTHROPIC_API_KEY=sk-ant-... npx tsx create-agent.ts "Explain the project structure"
 *
 * Requires: npm install @anthropic-ai/claude-agent-sdk
 */

import { ClaudeAgent } from "@anthropic-ai/claude-agent-sdk";

const model = process.env.ANTHROPIC_MODEL || "claude-sonnet-4-6";
const task =
  process.argv[2] ||
  "List the files in the current directory and describe the project structure";

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("Error: ANTHROPIC_API_KEY environment variable not set");
  process.exit(1);
}

const agent = new ClaudeAgent({
  model,
  systemPrompt:
    "You are a helpful coding assistant. Be concise and write clean code.",
  tools: ["bash", "text_editor", "file_reader"],
  permissions: {
    fileRead: { autoApprove: true },
    bash: { autoApprove: ["ls", "cat", "grep", "find", "echo", "pwd"] },
  },
});

console.log(`Task: ${task}\n---`);

const stream = agent.message({
  message: task,
  workingDirectory: process.cwd(),
});

for await (const event of stream) {
  switch (event.type) {
    case "text":
      process.stdout.write(event.text);
      break;
    case "tool_use":
      console.log(`\n[Tool: ${event.tool}]`);
      break;
    case "tool_result":
      // Tool results are handled internally
      break;
    case "error":
      console.error(`Error: ${event.message}`);
      break;
  }
}

console.log("\n--- Done");
