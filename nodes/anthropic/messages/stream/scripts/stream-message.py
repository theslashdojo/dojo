#!/usr/bin/env python3
"""Stream a Claude response token-by-token.

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python stream-message.py --prompt "Write a story"
    python stream-message.py --model claude-opus-4-6 --prompt "Explain quantum computing"

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
    parser = argparse.ArgumentParser(description="Stream a Claude response")
    parser.add_argument("--prompt", "-p", required=True, help="User prompt")
    parser.add_argument("--model", "-m", default="claude-sonnet-4-6", help="Model ID")
    parser.add_argument("--max-tokens", type=int, default=1024, help="Max output tokens")
    parser.add_argument("--system", "-s", help="System prompt")
    parser.add_argument("--temperature", "-t", type=float, help="Temperature (0.0-1.0)")
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
        with client.messages.stream(**kwargs) as stream:
            for text in stream.text_stream:
                print(text, end="", flush=True)

        message = stream.get_final_message()
        print(f"\n\n--- {message.model} | {message.usage.input_tokens}in/{message.usage.output_tokens}out | {message.stop_reason} ---")

    except anthropic.AuthenticationError:
        print("Error: Invalid API key", file=sys.stderr)
        sys.exit(1)
    except anthropic.RateLimitError as e:
        retry = e.response.headers.get("retry-after", "unknown")
        print(f"\nError: Rate limited. Retry after {retry}s", file=sys.stderr)
        sys.exit(1)
    except anthropic.APIError as e:
        print(f"\nError: {e.status_code} — {e.message}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
