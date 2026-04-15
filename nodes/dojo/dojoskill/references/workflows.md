# Dojo Skill Workflows

## When to use which route

- `agent_learn`: The user says "what is", "explain", "show docs", or "find info" and the agent wants answer nodes, excerpts, and suggested next skills.
- `discover`: You have a goal in natural language and need the registry to separate `learn_first` from `then_do`.
- `learn`: You already know the node URI and need the most relevant section for a question.
- `search`: You need wider recall than `discover`, usually with `mode=learn`, or you need to inspect multiple candidates.
- `skill`: You need the full node envelope, including `execution`, `knowledge`, `reasons`, and `routes`.
- `alias`: You want to turn human phrasing into a canonical URI.
- `graph` or `backlinks`: You need to inspect surrounding context when search quality is weak.
- `bundle`: You need the portable package for a node, including `node.json`, `SKILL.md`, agent metadata, references, scripts, and tests when present.
- `query`: You need a lower-level Dojo API operation with explicit routing control.

## Information-finding pattern

1. Start with `agent_learn` when the question is explanatory, or `discover` when the prompt may turn into execution.
2. Follow `answer_nodes[*].routes.learn`, `best_match.routes.learn`, or a `learn_first[*].routes.learn` entry to read the right section.
3. Use `skill` to inspect whether the chosen node is knowledge-heavy, executable, or both, and to capture the canonical follow-up routes.
4. If the result feels off, retry with `search --mode learn`, then inspect `alias`, `graph`, `backlinks`, and `reasons` before changing manifests.
5. Fetch `bundle` when the chosen node must be reused in another agent runtime.

## CLI quick examples

- Answer-first lookup:
  `node scripts/use-dojo-skill.js agent_learn --question "find info in dojo" --current-context dojo`
- Bundle fetch:
  `node scripts/use-dojo-skill.js bundle --uri dojo/skill`
- Structured input:
  `node scripts/use-dojo-skill.js --json '{"operation":"discover","q":"how do i publish a dojo node","current_context":["dojo","dojo/publish"]}'`

## Important response fields

- `query_variants`: How the registry expanded the original phrasing.
- `answer_nodes`: Ranked knowledge-first answers from `agent_learn`.
- `learn_first` and `then_do`: The split reading-versus-execution plan from `discover`.
- `reasons` and `excerpt`: Why a node matched and what supporting text the registry surfaced.
- `routes`: Canonical follow-up endpoints for the matched node.
- `relevant_sections`: Ranked section hits for `learn?question=...`.
- `execution` and `knowledge`: Summaries on `skill` and search-style payloads that tell an agent whether to read or run next.
- `entrypoints`: Bundle files that matter first, especially `manifest`, `skill_md`, `agents`, `references`, and `scripts`.
