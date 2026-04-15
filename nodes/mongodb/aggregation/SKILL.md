---
name: aggregation
description: >
  Run MongoDB aggregation pipelines when a plain find is not expressive enough and you need grouping, joins, reshaping, or materialized outputs.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Aggregation Skill

Use this skill for reporting, enrichment, reshaping, and multi-stage query logic.

## Inputs

- `MONGODB_URI`
- `AGGREGATION_INPUT_JSON` or stdin with `database`, `collection`, and `pipeline`

## Example

```bash
export AGGREGATION_INPUT_JSON='{"database":"app","collection":"orders","pipeline":[{"$match":{"status":"paid"}},{"$group":{"_id":"$customerId","revenue":{"$sum":"$total"}}},{"$sort":{"revenue":-1}}],"options":{"allowDiskUse":true}}'
node ./scripts/run-pipeline.js
```

## Workflow

1. Push `$match` and other narrowing stages as early as possible.
2. Keep `$project` tight so later stages do less work.
3. Use `explain` mode if the pipeline is slow, then check [[mongodb/indexes]].
4. Treat `$merge` and `$out` as write operations that need extra review.

## Edge Cases

- `allowDiskUse` can keep a large pipeline running, but it does not fix poor stage ordering.
- Aggregation results can be large; keep result sets bounded when the caller only needs the top N rows.
- Materializing results into another collection changes data and should be considered destructive if the target is replaced.
