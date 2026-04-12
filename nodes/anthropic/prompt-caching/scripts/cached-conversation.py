#!/usr/bin/env python3
"""Demonstrate prompt caching with Claude.

Sends two requests with the same system prompt to show cache write then cache read.

Usage:
    ANTHROPIC_API_KEY=sk-ant-... python cached-request.py

Requires: pip install anthropic
"""

import os
import sys
import time

try:
    import anthropic
except ImportError:
    print("Error: pip install anthropic", file=sys.stderr)
    sys.exit(1)


def main():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic()

    # Build a system prompt long enough to cache (>2048 tokens for Sonnet 4.6)
    base_instructions = "You are an expert technical assistant. "
    # Pad with substantial reference material to meet minimum cache threshold
    reference_material = (
        "Reference documentation follows.\n\n"
        + "\n".join(
            f"Section {i}: This section covers topic {i} in detail. "
            f"The key concepts include principle-{i}a, principle-{i}b, and principle-{i}c. "
            f"When applying these concepts, consider the trade-offs between performance, "
            f"maintainability, and correctness. Each principle has been validated through "
            f"extensive real-world usage and peer review."
            for i in range(1, 101)
        )
    )
    system_prompt = base_instructions + reference_material

    print(f"System prompt length: ~{len(system_prompt.split())} words")
    print()

    # Request 1: Cache write
    print("Request 1 (cache write)...")
    r1 = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=256,
        cache_control={"type": "ephemeral"},
        system=system_prompt,
        messages=[{"role": "user", "content": "Summarize section 1"}],
    )

    print(f"  Response: {r1.content[0].text[:100]}...")
    print(f"  Cache write tokens: {r1.usage.cache_creation_input_tokens}")
    print(f"  Cache read tokens:  {r1.usage.cache_read_input_tokens}")
    print(f"  Uncached tokens:    {r1.usage.input_tokens}")
    print(f"  Output tokens:      {r1.usage.output_tokens}")
    print()

    # Brief pause then send second request
    print("Request 2 (cache read)...")
    r2 = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=256,
        cache_control={"type": "ephemeral"},
        system=system_prompt,
        messages=[{"role": "user", "content": "Summarize section 50"}],
    )

    print(f"  Response: {r2.content[0].text[:100]}...")
    print(f"  Cache write tokens: {r2.usage.cache_creation_input_tokens}")
    print(f"  Cache read tokens:  {r2.usage.cache_read_input_tokens}")
    print(f"  Uncached tokens:    {r2.usage.input_tokens}")
    print(f"  Output tokens:      {r2.usage.output_tokens}")
    print()

    # Summary
    if r2.usage.cache_read_input_tokens > 0:
        savings_pct = (1 - 0.1) * 100  # cache reads are 10% of base
        print(f"Cache hit! Saved ~{savings_pct:.0f}% on {r2.usage.cache_read_input_tokens} cached tokens")
    else:
        print("No cache hit. Verify system prompt meets minimum token threshold for this model.")


if __name__ == "__main__":
    main()
