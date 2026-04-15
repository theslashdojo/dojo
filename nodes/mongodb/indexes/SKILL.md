---
name: indexes
description: >
  Create, inspect, drop, and explain MongoDB indexes when query performance or uniqueness constraints need explicit tuning.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Indexes Skill

Use this skill when read latency, sort cost, or uniqueness enforcement depends on index shape.

## Inputs

- `MONGODB_URI`
- `INDEX_INPUT_JSON` or stdin with `database`, `collection`, and `action`

## Example: Create a Compound Index

```bash
export INDEX_INPUT_JSON='{"database":"app","collection":"orders","action":"create","keys":{"customerId":1,"createdAt":-1},"options":{"name":"customer_created_at"}}'
node ./scripts/manage-indexes.js
```

## Example: Explain a Query

```bash
export INDEX_INPUT_JSON='{"database":"app","collection":"orders","action":"explainFind","filter":{"customerId":42},"sort":{"createdAt":-1}}'
node ./scripts/manage-indexes.js
```

## Workflow

1. Start from a real query shape from [[mongodb/crud/find]] or [[mongodb/aggregation]].
2. Create the narrowest index that supports the filter and sort path you care about.
3. Verify the plan with `explain` rather than assuming the server picked the index.
4. Drop unused indexes when they no longer match production access patterns.

## Edge Cases

- Every extra index adds write overhead.
- TTL indexes only work on eligible date fields and expire asynchronously.
- A unique index can fail immediately if duplicate data already exists.
