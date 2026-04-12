---
name: batch
description: Process large volumes of Claude requests asynchronously at 50% discount. Use when you have many requests that don't need real-time responses — classification, extraction, translation, evaluation.
---

# Message Batches API

Submit thousands of requests, get results within 24 hours at half price.

## When to Use

- Bulk document processing (classification, extraction, summarization)
- Content moderation pipelines
- Translation at scale
- Model evaluation across test datasets
- Any high-volume, non-time-sensitive workload

## Workflow

1. Build array of requests with unique `custom_id` and standard `params`
2. Create batch via `client.messages.batches.create(requests=...)`
3. Poll status via `client.messages.batches.retrieve(batch_id)`
4. When `processing_status == "ended"`, retrieve results
5. Match results to requests via `custom_id`

## Create a Batch

```python
batch = client.messages.batches.create(
    requests=[
        {
            "custom_id": "doc-001",
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 1024,
                "messages": [{"role": "user", "content": "Classify: [document text]"}]
            }
        }
    ]
)
```

## Retrieve Results

```python
for result in client.messages.batches.results(batch.id):
    if result.result.type == "succeeded":
        print(f"{result.custom_id}: {result.result.message.content[0].text}")
    else:
        print(f"{result.custom_id}: ERROR")
```

## Pricing

50% off both input and output tokens. Stacks with prompt caching.

| Model | Batch Input | Batch Output |
|-------|-------------|-------------|
| Opus 4.6 | $2.50/MTok | $12.50/MTok |
| Sonnet 4.6 | $1.50/MTok | $7.50/MTok |
| Haiku 4.5 | $0.50/MTok | $2.50/MTok |

## Limits

- Max 100,000 requests per batch
- Processing takes up to 24 hours
- Tier-dependent queue limits (100K-500K total queued)
- Results may arrive out of order — always match by custom_id

## Edge Cases

- Batches start immediately — there is no scheduling mechanism
- Individual requests in a batch can fail while others succeed
- All Messages API features work (tools, vision, thinking, structured output)
- Extended output (300K tokens) available on Opus 4.6/Sonnet 4.6 with beta header
- No streaming within batch requests
