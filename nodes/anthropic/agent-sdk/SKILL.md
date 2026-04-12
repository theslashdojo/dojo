---
name: agent-sdk
description: Build autonomous Claude agents that understand codebases, edit files, and run commands. Use when you need to embed Claude's agentic capabilities into your own application or workflow.
---

# Claude Agent SDK

Build autonomous agents powered by Claude.

## When to Use

- Embedding Claude Code capabilities in your application
- Building custom coding assistants
- Automating multi-step development workflows
- Creating agents that interact with file systems and terminals

## Installation

```bash
npm install @anthropic-ai/claude-agent-sdk
```

Requires Node.js 18+ and `ANTHROPIC_API_KEY`.

## Quick Start

```typescript
import { ClaudeAgent } from "@anthropic-ai/claude-agent-sdk";

const agent = new ClaudeAgent({
  model: "claude-sonnet-4-6",
  tools: ["bash", "text_editor", "file_reader"],
});

const stream = agent.message({
  message: "Read package.json and explain the project",
  workingDirectory: "/path/to/project",
});

for await (const event of stream) {
  if (event.type === "text") process.stdout.write(event.text);
}
```

## Core Concepts

### Sessions
Agent maintains conversation context across `.message()` calls. No manual history management needed.

### Tools
Built-in: `bash`, `text_editor`, `file_reader`, `web_search`, `web_fetch`. Extend with custom tools using the standard tool_use format.

### Permissions
Control what the agent can do autonomously vs. what requires approval. Scope by command prefix (bash) or glob pattern (file writes).

### Events
Stream typed events: `text`, `tool_use`, `tool_result`, `error`. Build reactive UIs around the event stream.

## Custom Tools

```typescript
const agent = new ClaudeAgent({
  model: "claude-sonnet-4-6",
  customTools: [{
    name: "deploy",
    description: "Deploy the application to staging",
    input_schema: { type: "object", properties: { env: { type: "string" } } },
    handler: async (input) => {
      const result = await deployToStaging(input.env);
      return { output: result };
    }
  }]
});
```

## vs. Messages API

Use **Messages API** when you want full control over the conversation loop, tool execution, and response handling. Use **Agent SDK** when you want batteries-included autonomous behavior with built-in file system and shell access.

## Edge Cases

- The SDK was previously called `claude-code-sdk` — migration guide in docs
- Long-running agent sessions consume tokens for each turn in the loop
- File permissions should be scoped to prevent unintended modifications
- Network interruptions may terminate the agent session
- Set `maxTurns` to prevent runaway loops
