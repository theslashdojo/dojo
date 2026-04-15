---
name: streaming
description: >
  Process large JSON inputs incrementally with jq stream mode, reducers, and JSON sequence support.
  Use when whole-document filters are too memory-heavy or when the source is a long-lived stream of JSON texts.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# jq Streaming

Use this skill when payload size or stream shape matters more than convenient random access.

## Workflow

1. Decide whether the input is a large normal JSON document, `application/json-seq`, or a partially invalid stream.
2. Turn on `--stream` and write reducers around stream events rather than whole objects.
3. Use `--seq` for record-separated JSON streams and `--unbuffered` when downstream consumers should see each result immediately.
4. Move complex reducers into `../modules` once the inline filter stops being readable.

## Examples

~~~bash
jq -n --stream "reduce inputs as $item (0; if ($item | length == 2 and $item[0][-1] == \"duration_ms\") then . + $item[1] else . end)" metrics.json
jq --seq -c "." events.seq

JQ_FILTER="reduce inputs as $item (0; if ($item | length == 2) then . + 1 else . end)" \
JQ_FILE="large.json" \
./scripts/stream-reduce.sh
~~~

## Edge Cases

- Stream mode emits path metadata, not whole objects. Design filters around event arrays.
- Use `--stream-errors` when invalid records should become data instead of aborting immediately.
- Prefer file-based jq programs for non-trivial reducers and reconstruction logic.
- Add `--unbuffered` when the next process should receive results before jq exits.
