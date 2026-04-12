#!/usr/bin/env python3
"""Create a message batch, poll for completion, and retrieve results.

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python batch-process.py
    python batch-process.py --count 10 --model claude-haiku-4-5

Requires: pip install anthropic
"""

import argparse
import json
import os
import sys
import time

try:
    import anthropic
except ImportError:
    print("Error: pip install anthropic", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Process a batch of Claude requests")
    parser.add_argument("--count", type=int, default=5, help="Number of requests in batch")
    parser.add_argument("--model", default="claude-sonnet-4-6", help="Model ID")
    parser.add_argument("--poll-interval", type=int, default=30, help="Poll interval in seconds")
    args = parser.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic()

    # Build sample requests
    requests = [
        {
            "custom_id": f"req-{i:04d}",
            "params": {
                "model": args.model,
                "max_tokens": 256,
                "messages": [
                    {"role": "user", "content": f"In one sentence, what is the #{i+1} most populated city in the world?"}
                ]
            }
        }
        for i in range(args.count)
    ]

    # Create batch
    print(f"Creating batch with {len(requests)} requests...")
    batch = client.messages.batches.create(requests=requests)
    print(f"Batch ID: {batch.id}")
    print(f"Status: {batch.processing_status}")

    # Poll for completion
    while batch.processing_status != "ended":
        time.sleep(args.poll_interval)
        batch = client.messages.batches.retrieve(batch.id)
        counts = batch.request_counts
        print(f"  Processing: {counts.processing} | Succeeded: {counts.succeeded} | Errored: {counts.errored}")

    print(f"\nBatch completed!")

    # Retrieve and display results
    print("\n--- Results ---")
    for result in client.messages.batches.results(batch.id):
        if result.result.type == "succeeded":
            msg = result.result.message
            text = msg.content[0].text if msg.content else "(empty)"
            print(f"[{result.custom_id}] {text}")
        elif result.result.type == "errored":
            print(f"[{result.custom_id}] ERROR: {result.result.error.message}")


if __name__ == "__main__":
    main()
