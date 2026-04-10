---
name: query
description: Query the Dojo registry through one helper. Use when an agent needs to resolve a task, search or inspect nodes, load learn payloads, fetch portable bundles, or call the agent ask and learn routes from the CLI or JavaScript.
license: MIT
compatibility: Requires Node.js 18+ and access to a Dojo registry base URL; defaults to https://slashdojo.com.
metadata:
  canonical-uri: dojo/api/query
  category: dojo
---

# Query the Registry

Use `scripts/query-registry.js` when the task is to read the Dojo registry, inspect why a node matched, or fetch a portable package for another runtime.

## Fast path

- Use `discover` when the agent needs a grouped read-versus-do answer.
- Use `search` for wider recall and `resolve` for the single best recommendation.
- Use `learn`, `graph`, `backlinks`, or `alias` when the node is known but the right section or graph neighbor is not.
- Use `bundle` when the caller needs `SKILL.md`, agent metadata, references, scripts, or tests from a node package.

## Workflow

1. Start with `discover`, `resolve`, or `search`.
2. Follow with `skill` or `learn` before acting on a match.
3. Use `graph`, `backlinks`, and `alias` when discovery is weak or ambiguous.
4. Fetch `bundle` only after the right node is clear.

## Examples

- CLI search:
  `node scripts/query-registry.js search --q "dojo validation" --mode learn --limit 3`
- CLI learn:
  `node scripts/query-registry.js learn --uri dojo/api --question "where is the bundle route"`
- CLI bundle:
  `node scripts/query-registry.js bundle --uri dojo/skill`
- Structured input:
  `node scripts/query-registry.js --json '{"operation":"agent_learn","question":"find info in dojo","current_context":["dojo"]}'`
- JavaScript:

```js
const { query } = require('./scripts/query-registry.js');

const result = await query({
  operation: 'discover',
  q: 'how do i validate a dojo node',
  current_context: ['dojo']
});
```

## Edge cases

- `agent-ask` and `agent_ask` are both accepted.
- `tags` and `current_context` accept comma-separated strings or JSON arrays.
- `agent_context` accepts a JSON object for structured caller metadata.
- The helper returns raw HTTP `status`, `method`, `url`, and parsed JSON so the caller can decide retries or fallbacks.

Read `references/operations.md` when you need the operation matrix and route decision rules.
