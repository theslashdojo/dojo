#!/usr/bin/env python3
"""Send a message to Claude via the Anthropic Messages API.

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python create-message.py

    # Or with arguments:
    python create-message.py --model claude-sonnet-4-6 --prompt "Hello Claude"

Requires: pip install anthropic
"""

import argparse
import json
import os
import sys

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Run: pip install anthropic", file=sys.stderr)
    sys.exit(1)


def create_message(
    prompt: str,
    model: str = "claude-sonnet-4-6",
    max_tokens: int = 1024,
    system: str | None = None,
    temperature: float | None = None,
) -> dict:
    """Create a message using the Anthropic Messages API."""
    client = anthropic.Anthropic()

    kwargs = {
        "model": model,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
    }
    if system:
        kwargs["system"] = system
    if temperature is not None:
        kwargs["temperature"] = temperature

    message = client.messages.create(**kwargs)

    return {
        "id": message.id,
        "model": message.model,
        "content": [
            {"type": block.type, "text": block.text}
            for block in message.content
            if block.type == "text"
        ],
        "stop_reason": message.stop_reason,
        "usage": {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Send a message to Claude")
    parser.add_argument("--prompt", "-p", default="Hello, Claude! What can you do?", help="The prompt to send")
    parser.add_argument("--model", "-m", default="claude-sonnet-4-6", help="Model ID")
    parser.add_argument("--max-tokens", type=int, default=1024, help="Max tokens to generate")
    parser.add_argument("--system", "-s", help="System prompt")
    parser.add_argument("--temperature", "-t", type=float, help="Temperature (0.0-1.0)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    result = create_message(
        prompt=args.prompt,
        model=args.model,
        max_tokens=args.max_tokens,
        system=args.system,
        temperature=args.temperature,
    )

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for block in result["content"]:
            print(block["text"])
        print(f"\n--- {result['model']} | {result['usage']['input_tokens']}in/{result['usage']['output_tokens']}out | {result['stop_reason']} ---")


if __name__ == "__main__":
    main()
