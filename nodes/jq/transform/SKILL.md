---
name: transform
description: >
  Rewrite JSON objects and arrays with jq assignment operators, path helpers, and reducers.
  Use when an agent needs to patch config files, normalize payloads, redact keys, or persist transformed JSON safely.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# jq Transform

Use this skill when JSON needs to be changed, not just queried.

## Workflow

1. Decide whether the change is a field update, path update, key rename, or structural reshape.
2. Prefer jq operators and helpers over text substitution.
3. For file rewrites, write to a temp file and move only after jq succeeds.
4. Review the resulting file diff when the change is persistent.

## Examples

~~~bash
jq ".scripts.test = \"vitest\"" package.json
jq ".count += 1" counters.json
jq "setpath([\"deploy\", \"region\"]; \"us-east-1\")" app.json

JQ_FILTER=".scripts.test = \"vitest\"" \
JQ_FILE="package.json" \
JQ_INPLACE="true" \
JQ_SORT_KEYS="true" \
./scripts/transform-json.sh
~~~

## Edge Cases

- jq does not edit files in place; the wrapper script uses a temp file and move.
- Use `|=` when the update depends on the old value at the selected path.
- Use `-S` when stable object key ordering makes diffs easier to review.
- If the filter becomes large or shared across commands, move it into `../modules`.
