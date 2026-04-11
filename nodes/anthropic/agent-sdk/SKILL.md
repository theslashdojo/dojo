---
name: agent-sdk
description: Build autonomous agents with the Claude Agent SDK — use when you need programmatic agents that can use tools, edit files, run commands, and orchestrate complex workflows
---

# Claude Agent SDK

Build autonomous agents powered by Claude Code.

## When to Use

- Building an autonomous coding agent
- Creating a workflow that reads/writes files and runs commands
- Connecting Claude to custom tools via MCP
- Adding safety guardrails to an agent with hooks
- Orchestrating multi-step tasks programmatically

## Prerequisites

- Python 3.10+
- `pip install claude-agent-sdk`
- `ANTHROPIC_API_KEY` set in environment

## Quick Start

```python
import anyio
from claude_agent_sdk import query, AssistantMessage, TextBlock

async def main():
    async for message in query(prompt="Create a Python hello world"):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    print(block.text)

anyio.run(main)
```

## Interactive Session

```python
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions

options = ClaudeAgentOptions(
    system_prompt="You are a senior developer.",
    allowed_tools=["Read", "Write", "Edit", "Bash"],
    permission_mode="acceptEdits",
    max_turns=10,
    cwd="/my/project",
)

async with ClaudeSDKClient(options=options) as client:
    await client.query("Refactor the main module to use async/await")
    async for msg in client.receive_response():
        print(msg)
```

## Custom MCP Tools

```python
from claude_agent_sdk import tool, create_sdk_mcp_server

@tool("get_user", "Look up user by ID", {"user_id": int})
async def get_user(args):
    user = db.get(args["user_id"])
    return {"content": [{"type": "text", "text": f"User: {user.name}"}]}

server = create_sdk_mcp_server(name="db-tools", version="1.0.0", tools=[get_user])

options = ClaudeAgentOptions(
    mcp_servers={"db": server},
    allowed_tools=["mcp__db__get_user"],
)
```

## Hooks (Safety Guardrails)

```python
from claude_agent_sdk import HookMatcher

async def audit_bash(input_data, tool_use_id, context):
    cmd = input_data["tool_input"].get("command", "")
    if "rm -rf" in cmd:
        return {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "Destructive command blocked"
        }}
    return {}

options = ClaudeAgentOptions(
    hooks={"PreToolUse": [HookMatcher(matcher="Bash", hooks=[audit_bash])]}
)
```

## Permission Modes

| Mode | Behavior |
|------|----------|
| `askUser` | Prompt for every tool use |
| `acceptEdits` | Auto-approve file edits |
| `denyEdits` | Deny all file modifications |

Combine with `allowed_tools` for fine-grained control.

## Edge Cases

- **CLI not found**: Install Claude Code first or let the SDK bundle it
- **Tool name format**: MCP tools use `mcp__servername__toolname` naming
- **Max turns**: Set a reasonable limit to prevent infinite loops
- **Working directory**: Always set `cwd` to scope file operations
- **Async only**: All SDK operations are async — use `anyio.run()` or `asyncio.run()`
