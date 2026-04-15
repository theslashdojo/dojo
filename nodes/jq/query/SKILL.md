---
name: query
description: >
  Extract fields, filter arrays, and emit shell-friendly values from JSON with jq.
  Use when an agent needs IDs, URLs, booleans, counts, or filtered subsets from API responses, CLI output, or JSON files.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# jq Query

Use this skill when the input is already JSON and the job is to read, filter, or branch on it without rewriting the whole structure.

## Workflow

1. Decide whether the result should stay JSON or become plain text.
2. Write the smallest filter that selects the needed fields or elements.
3. Add `-r` for shell interpolation, `-c` for one-line JSON, or `-e` for conditionals.
4. Pass caller-controlled values through jq variables instead of string interpolation.

## Examples

~~~bash
jq -r ".version" package.json
jq ".items[] | select(.state == \"open\") | {id, title}" issues.json
jq -e ".ready == true" status.json > /dev/null

JQ_FILTER=".deployments[] | select(.environment == $env) | .url" \
JQ_FILE="deployments.json" \
JQ_RAW_OUTPUT="true" \
JQ_VARS_JSON='{"env":"prod"}' \
./scripts/run-query.sh
~~~

## Edge Cases

- Use `-r` only when plain text is required; otherwise keep JSON output for downstream jq or API tooling.
- Use `-e` when jq should control a Bash `if` statement or CI step.
- Avoid building filters with shell interpolation. Pass values with variables instead.
- If the payload is very large, switch to `../streaming` instead of forcing jq to materialize everything.
