---
name: skill
description: Find answers in Dojo, inspect why a node matched, and fetch or execute portable skill bundles. Use when an agent needs information from Dojo or wants to export a skill with its full knowledge context.
license: MIT
compatibility: Requires Node.js 18+ and access to a Dojo registry base URL; defaults to https://slashdojo.com.
metadata:
  short-description: Find answers in Dojo and export executable bundles
  canonical-uri: dojo/skill
---

# Dojo Skill

Dojo defines a universal format for AI agent skills and knowledge: discoverable, composable, hierarchical units of capability. Any agent, any framework, any LLM can query the registry and get back executable skills and knowledge with full context.

The knowledge layer is what makes Dojo more than npm. Every node in the tree `ecosystem`, `standard`, `skill`, `context`, and `sub` can carry rich, linked, wiki-like content. They are the Obsidian notes of the agent world. Context nodes are how agents learn.

Use this skill when the task is about the Dojo registry itself, when an agent needs to find information in that knowledge layer, or when another agent needs a portable Dojo skill bundle.

## Fast path

- User asks "what is...", "explain...", or "find info about..." -> use `scripts/use-dojo-skill.js` with `operation: agent_learn`.
- User has a natural-language goal and you need the registry to split reading from execution -> use `operation: discover`.
- Use `operation: learn` with `uri` and `question` when you know the node but need the right section.
- Use `operation: search`, `skill`, `alias`, `graph`, or `backlinks` when discovery is weak and the agent needs to inspect why a node matched.
- Use `operation: bundle` with `uri` when you need the actual package files.
- Use `operation: query` only when a caller needs to pass through one of the lower-level Dojo API operations directly.

## Workflow

1. Start with `agent_learn` for answer-first questions or `discover` when the task may end in execution.
2. Follow `answer_nodes[*].routes.learn`, `best_match.routes.learn`, or `learn_first[*].routes.learn` to the relevant section.
3. Use `skill` to inspect `knowledge`, `execution`, and canonical `routes` before acting.
4. Repair weak discovery with `search`, `alias`, `graph`, or `backlinks` before editing manifests or server code.
5. Fetch the bundle when the node must travel outside the current Dojo client.

## Examples

- CLI answer-first lookup:
  `node scripts/use-dojo-skill.js agent_learn --question "find info in dojo" --current-context dojo`
- CLI mixed read-versus-do lookup:
  `node scripts/use-dojo-skill.js discover --q "how do i publish a dojo node" --current-context dojo,dojo/publish`
- CLI portable package fetch:
  `node scripts/use-dojo-skill.js bundle --uri dojo/skill`
- Structured CLI input:
  `node scripts/use-dojo-skill.js --json '{"operation":"learn","uri":"dojo/api","question":"where is the bundle route"}'`
- JavaScript usage:

```js
const { useDojoSkill } = require('./scripts/use-dojo-skill.js');

const result = await useDojoSkill({
  operation: 'agent_learn',
  question: 'find info in dojo',
  current_context: ['dojo']
});
```

## Edge cases

- `tags` and `current_context` accept comma-separated strings or JSON arrays in the CLI.
- `question`, `q`, `need`, and `message` are normalized for information-finding operations, so callers do not need to rename prompt fields first.
- Use `discover` instead of `agent_learn` when the answer may need to become an execution plan in the same step.
- If results are weak, retry the exact human phrasing and inspect `alias`, `graph`, and `backlinks` before changing manifests or ranking code.

## Notes

This package intentionally mirrors the Agent Skills directory format: `SKILL.md`, `agents/`, `references/`, `scripts/`, and tests when present.

- The helper works both as a Node module and as a direct CLI entrypoint in the bundled package.
- Any HTTP client can call the same Dojo routes directly if importing or executing the helper is not convenient.
- Read `references/workflows.md` when you need the route decision rules, payload fields, or bundle details.
