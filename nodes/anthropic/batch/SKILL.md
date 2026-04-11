---
name: batch
description: Process thousands of Claude requests asynchronously at 50% discount — use when you have bulk workloads like document processing, data extraction, or content generation that don't need real-time responses
---

# Message Batches API

Submit up to 100,000 requests per batch. Results within 24 hours at half price.

## When to Use

- Processing hundreds or thousands of documents
- Bulk data extraction or classification
- Content generation at scale
- Any workload where 24-hour turnaround is acceptable
- Cost optimization for high-volume usage

## Prerequisites

- `ANTHROPIC_API_KEY` set in environment
- `pip install anthropic`

## Workflow

1. Build an array of requests with unique `custom_id` and Messages API `params`
2. Create the batch via `client.messages.batches.create()`
3. Poll `client.messages.batches.retrieve(id)` until `processing_status == "ended"`
4. Iterate results via `client.messages.batches.results(id)`
5. Match results to requests using `custom_id`

## Create and Process a Batch

```python
import anthropic
import time

client = anthropic.Anthropic()

# Build requests
requests = [
    {
        "custom_id": f"doc-{i}",
        "params": {
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": f"Summarize document {i}: ..."}]
        }
    }
    for i in range(100)
]

# Create batch
batch = client.messages.batches.create(requests=requests)
print(f"Batch {batch.id} created with {len(requests)} requests")

# Poll until done
while True:
    batch = client.messages.batches.retrieve(batch.id)
    succeeded = batch.request_counts.succeeded
    total = succeeded + batch.request_counts.processing + batch.request_counts.errored
    print(f"Progress: {succeeded}/{total}")

    if batch.processing_status == "ended":
        break
    time.sleep(60)

# Collect results
results = {}
for result in client.messages.batches.results(batch.id):
    if result.result.type == "succeeded":
        results[result.custom_id] = result.result.message.content[0].text
    else:
        results[result.custom_id] = f"ERROR: {result.result.error.message}"

print(f"Completed: {len(results)} results")
```

## Canceling a Batch

```python
client.messages.batches.cancel(batch.id)
# Only cancels unprocessed requests; completed results remain available
```

## Edge Cases

- **Results out of order**: Always use `custom_id` to match results to requests
- **Partial failure**: Some requests may succeed while others error. Check each result's type.
- **24-hour window**: Batches complete within 24 hours. Plan accordingly.
- **Results expiry**: Results available for 29 days after batch completion.
- **Rate limits**: Batch RPM and queue limits are separate from Messages API limits.
