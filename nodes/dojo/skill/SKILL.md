---
name: skill
description: >
  Query the Dojo registry to discover skills, answer questions from knowledge nodes,
  inspect graph context, and export portable bundles. Use when an agent needs to find
  a capability, learn about a topic, debug discovery ranking, or package a skill for
  another runtime.
license: MIT
compatibility: Requires Node.js 18+. Works via the `dojo` CLI, the bundled script, or direct HTTP against any Dojo registry.
metadata:
  author: dojo-community
  version: "1.1"
  scope: dojo-meta
---

# Dojo Skill

Query the Dojo registry to find skills, learn from knowledge nodes, inspect the graph, and export portable bundles.

Dojo is a universal registry where every node — `ecosystem`, `standard`, `skill`, `context`, `sub` — carries executable scripts alongside rich, linked, wiki-like content. This skill packages the registry's full API surface for agent consumption.

## Fast path

**"I have a question"** → `agent_learn --question "..."`
**"I need a skill for a task"** → `discover --q "..."`
**"I know the node, need a section"** → `learn --uri <uri> --question "..."`
**"Export for another runtime"** → `bundle --uri <uri>`

## When to use

| Goal | Operation | Why not the others |
|------|-----------|-------------------|
| Answer a knowledge question | `agent_learn` | Returns ranked excerpts + `then_do`. `discover` adds execution planning you don't need. |
| Find a skill for a task | `discover` | Splits into `learn_first` + `then_do`. `search` doesn't split. |
| Action-oriented agent request | `agent_ask` | Like `agent_learn` but for "do this" instead of "explain this." |
| Natural language resolution | `resolve` | Returns the single best-match skill. `discover` adds learning context. |
| Read a known node's content | `learn` | Accepts `question` or `section` to focus. `skill` returns the full envelope, not a reading path. |
| Wide recall or filtering | `search` | Returns scored list with `eco`, `type`, `tags`, `mode` filters. `discover` returns one recommendation. |
| Full node inspection | `skill` | Returns `knowledge` + `execution` + `routes`. Use when you need the envelope, not a reading path. |
| Browse ecosystem tree | `tree` | Hierarchical view of all children. `search` is flat. |
| Debug weak matches | `alias`, `graph`, `backlinks` | Inspect the graph to understand ranking before changing manifests. |
| Export portable package | `bundle` | Returns `SKILL.md`, agent metadata, references, scripts, tests — everything another runtime needs. |
| Registry overview | `index`, `ecosystems` | Root-level listings. Use before `search` when you don't know what's available. |
| Proxy a raw API call | `query` | Delegates to any operation via `query_options`. |

## Install

```bash
# CLI (recommended)
npm install -g @dojo/sdk

# Or install this skill locally
dojo install dojo/skill

# Or run standalone (no install)
node scripts/use-dojo-skill.js --help
```

## Workflow

1. **Start with `agent_learn` or `discover`.** Use `agent_learn` for "what is..." questions. Use `discover` when the task may need execution.
2. **Follow routes.** Every response includes `routes.learn` links. Follow them instead of constructing URIs manually.
3. **Inspect before acting.** Use `skill` to see `knowledge`, `execution`, and canonical `routes` for a node.
4. **Repair weak discovery.** Use `search --mode learn` for wider recall. Check `alias`, `graph`, `backlinks` to understand ranking before editing manifests.
5. **Export.** Use `bundle` to get the full portable package for another runtime.

See `references/workflows.md` for the route decision tree and response field guide.

## Operations reference

| Operation | Required | Optional | Returns |
|-----------|----------|----------|---------|
| `agent_learn` | `question` | `current_context` | `answer_nodes[]` with excerpts and `then_do` |
| `agent_ask` | `message` | `agent_context` | Action-oriented response with next steps |
| `discover` | `q` | `limit`, `current_context` | `learn_first[]` + `then_do[]` split |
| `resolve` | `need` | `eco`, `type`, `tags`, `mode`, `limit` | Best-match skill node |
| `search` | `q` | `eco`, `type`, `tags`, `mode`, `executable`, `limit`, `offset` | `results[]` with scores |
| `learn` | `uri` | `question`, `section` | `node`, `focused_section`, `reading_path` |
| `skill` | `uri` | — | Full envelope: `knowledge`, `execution`, `routes` |
| `tree` | `uri` | `depth` | Hierarchical node tree |
| `bundle` | `uri` | — | `files[]`, `entrypoints`, `manifest` |
| `alias` | alias string | — | Canonical `uri` |
| `graph` | `uri` | `depth` | `nodes[]` + `edges[]` |
| `backlinks` | `uri` | — | `backlinks[]` with `from`, `type`, `context` |
| `index` | — | — | Registry root with ecosystems |
| `ecosystems` | — | — | All registered ecosystems |
| `query` | `query_options.operation` | operation-specific | Proxied API response |

All prompt-like fields (`question`, `q`, `need`, `message`) are normalized — callers don't need to rename.

## Examples

### CLI

```bash
dojo search "state channels"
dojo learn dojo/api --question "how does the bundle route work"
dojo learn dojo/api#bundle-route
dojo graph dojo/skill --depth 2
dojo run dojo/skill use-dojo-skill --input '{"operation":"agent_learn","question":"what is dojo"}'
```

### Script (subprocess boundary)

```bash
node scripts/use-dojo-skill.js agent_learn \
  --question "what is the knowledge layer" --current-context dojo

node scripts/use-dojo-skill.js discover \
  --q "how do i publish a dojo node" --current-context dojo,dojo/publish

node scripts/use-dojo-skill.js bundle --uri dojo/skill

# Structured JSON input
node scripts/use-dojo-skill.js \
  --json '{"operation":"discover","q":"deploy to vercel","current_context":["vercel"]}'
```

### JavaScript (in-process)

```js
const { useDojoSkill } = require('./scripts/use-dojo-skill.js');

// Answer-first lookup
const answer = await useDojoSkill({
  operation: 'agent_learn',
  question: 'what is the knowledge layer',
  current_context: ['dojo']
});
// answer.data.answer_nodes[0].excerpt → relevant text
// answer.data.answer_nodes[0].routes.learn → follow-up URI

// Discover + act
const plan = await useDojoSkill({
  operation: 'discover',
  q: 'publish a dojo node',
  current_context: ['dojo']
});
// plan.data.learn_first → read these first
// plan.data.then_do → execute these after
```

## Response anatomy

Key fields to read from responses:

- **`answer_nodes[].excerpt`** — the knowledge text that matched (`agent_learn`)
- **`answer_nodes[].routes.learn`** — follow-up URI to read more
- **`learn_first[]` / `then_do[]`** — split plan from `discover`
- **`focused_section`** — most relevant section (`learn?question=...`)
- **`reading_path`** — ordered follow-up nodes for deeper understanding
- **`reasons` / `excerpt`** — why a node matched and supporting text
- **`execution` / `knowledge`** — summaries telling agents whether to read or run next
- **`routes`** — canonical follow-up endpoints for the matched node
- **`entrypoints`** — bundle files that matter first: `manifest`, `skill_md`, `agents`, `scripts`
- **`query_variants`** — how the registry expanded the original phrasing

## Gotchas

1. **`agent_learn` vs `discover`** — `agent_learn` returns knowledge excerpts for "what is..." questions. `discover` splits into learn-then-do for task-oriented prompts. Using `discover` for pure questions wastes the execution split. Using `agent_learn` when the agent needs to act misses the `then_do` plan.
2. **`current_context` matters** — passing the agent's working context significantly improves relevance. Always include it.
3. **Follow `routes`, don't construct URIs** — every response carries follow-up routes. Manually building paths risks hitting the wrong section or missing query params the registry added.
4. **Inspect before editing manifests** — if discovery results feel wrong, check `alias`, `graph`, `backlinks`, and `reasons` first. The graph context usually explains the ranking.
5. **`tags` and `current_context` accept both formats** — comma-separated strings (`"dojo,dojo/api"`) or JSON arrays (`["dojo","dojo/api"]`) in CLI mode.
6. **Default registry** — the script defaults to `https://slashdojo.com` when `base_url` is omitted.
7. **`--json` on `dojo` CLI** — switches any command to machine-readable JSON output.

## Package shape

This skill follows the [Agent Skills directory format](https://github.com/agentskills/agentskills):

```
skill/
├── SKILL.md                      # This file
├── node.json                     # Dojo manifest (graph semantics)
├── agents/openai.yaml            # Agent integration metadata
├── references/workflows.md       # Route decision tree + response field guide
├── scripts/use-dojo-skill.js     # CLI + in-process entry point
└── tests/use-dojo-skill.test.js  # Verification tests
```

The helper in `scripts/use-dojo-skill.js` works as both a `require()`-able module and a direct CLI. This dual interface lowers integration cost for agents that prefer either a subprocess boundary or an in-process import.
