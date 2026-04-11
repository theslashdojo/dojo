#!/usr/bin/env python3
"""Complete tool use agentic loop with Claude.

Demonstrates:
- Defining tools with JSON Schema
- Handling tool_use responses
- Sending tool_result back
- Multi-turn agentic loop

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python tool-use-loop.py

Requires: pip install anthropic
"""

import json
import os
import sys

try:
    import anthropic
except ImportError:
    print("Error: pip install anthropic", file=sys.stderr)
    sys.exit(1)


# ── Tool Definitions ──────────────────────────────────────────────────

TOOLS = [
    {
        "name": "get_weather",
        "description": "Get the current weather for a city. Returns temperature (celsius), conditions, and humidity.",
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "City name, e.g. 'San Francisco, CA'"
                }
            },
            "required": ["city"]
        }
    },
    {
        "name": "calculate",
        "description": "Evaluate a mathematical expression. Returns the numeric result.",
        "input_schema": {
            "type": "object",
            "properties": {
                "expression": {
                    "type": "string",
                    "description": "Math expression to evaluate, e.g. '2 + 2 * 3'"
                }
            },
            "required": ["expression"]
        }
    }
]


# ── Tool Implementations ─────────────────────────────────────────────

def get_weather(city: str) -> dict:
    """Simulated weather lookup."""
    weather_data = {
        "San Francisco, CA": {"temperature": 18, "conditions": "foggy", "humidity": 80},
        "New York, NY": {"temperature": 25, "conditions": "sunny", "humidity": 55},
        "London, UK": {"temperature": 14, "conditions": "rainy", "humidity": 90},
    }
    return weather_data.get(city, {"temperature": 20, "conditions": "partly cloudy", "humidity": 60})


def calculate(expression: str) -> dict:
    """Safe math expression evaluator."""
    allowed = set("0123456789+-*/().% ")
    if not all(c in allowed for c in expression):
        return {"error": "Invalid characters in expression"}
    try:
        result = eval(expression)  # Safe: only math chars allowed
        return {"result": result}
    except Exception as e:
        return {"error": str(e)}


TOOL_HANDLERS = {
    "get_weather": lambda args: get_weather(**args),
    "calculate": lambda args: calculate(**args),
}


# ── Agentic Loop ─────────────────────────────────────────────────────

def run_agent(prompt: str, model: str = "claude-sonnet-4-6", max_turns: int = 10):
    """Run the agentic tool use loop."""
    client = anthropic.Anthropic()
    messages = [{"role": "user", "content": prompt}]

    for turn in range(max_turns):
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            tools=TOOLS,
            messages=messages,
        )

        # Add assistant response to history
        messages.append({"role": "assistant", "content": response.content})

        # Print any text content
        for block in response.content:
            if block.type == "text":
                print(block.text)

        if response.stop_reason == "end_turn":
            return  # Done

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    handler = TOOL_HANDLERS.get(block.name)
                    if handler:
                        print(f"  [calling {block.name}({json.dumps(block.input)})]")
                        result = handler(block.input)
                    else:
                        result = {"error": f"Unknown tool: {block.name}"}

                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                    })

            messages.append({"role": "user", "content": tool_results})

    print("Warning: max turns reached", file=sys.stderr)


def main():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    prompt = sys.argv[1] if len(sys.argv) > 1 else "What's the weather in San Francisco and what is 42 * 17?"
    run_agent(prompt)


if __name__ == "__main__":
    main()
