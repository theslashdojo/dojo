#!/usr/bin/env python3
"""Create a synchronous message with Claude.

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python create-sync-message.py --prompt "Hello"
    python create-sync-message.py --model claude-opus-4-6 --system "Be concise" --prompt "What is gravity?"

Requires: pip install anthropic
"""

import argparse
import json
import os
import sys

try:
    import anthropic
except ImportError:
    print("Error: pip install anthropic", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Create a synchronous Claude message")
    parser.add_argument("--prompt", "-p", required=True, help="User prompt")
    parser.add_argument("--model", "-m", default="claude-sonnet-4-6", help="Model ID")
    parser.add_argument("--max-tokens", type=int, default=1024, help="Max output tokens")
    parser.add_argument("--system", "-s", help="System prompt")
    parser.add_argument("--temperature", "-t", type=float, help="Temperature (0.0-1.0)")
    parser.add_argument("--json-output", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic()

    kwargs = {
        "model": args.model,
        "max_tokens": args.max_tokens,
        "messages": [{"role": "user", "content": args.prompt}],
    }
    if args.system:
        kwargs["system"] = args.system
    if args.temperature is not None:
        kwargs["temperature"] = args.temperature

    try:
        message = client.messages.create(**kwargs)
    except anthropic.AuthenticationError:
        print("Error: Invalid API key", file=sys.stderr)
        sys.exit(1)
    except anthropic.RateLimitError as e:
        retry = e.response.headers.get("retry-after", "unknown")
        print(f"Error: Rate limited. Retry after {retry}s", file=sys.stderr)
        sys.exit(1)
    except anthropic.APIError as e:
        print(f"Error: {e.status_code} — {e.message}", file=sys.stderr)
        sys.exit(1)

    if args.json_output:
        print(json.dumps({
            "id": message.id,
            "model": message.model,
            "stop_reason": message.stop_reason,
            "content": [{"type": b.type, "text": b.text} for b in message.content if b.type == "text"],
            "usage": {"input_tokens": message.usage.input_tokens, "output_tokens": message.usage.output_tokens},
        }, indent=2))
    else:
        for block in message.content:
            if block.type == "text":
                print(block.text)
        print(f"\n--- {message.model} | {message.usage.input_tokens}in/{message.usage.output_tokens}out | {message.stop_reason} ---")


if __name__ == "__main__":
    main()
