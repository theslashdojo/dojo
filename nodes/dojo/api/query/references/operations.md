# Operation Matrix

- `index`: Load top-level registry metadata and route discovery.
- `ecosystems`: List loaded ecosystem roots.
- `resolve`: Ask for the highest-confidence executable or relevant node for a need.
- `discover`: Ask for grouped `learn_first`, `then_do`, and alternatives in one call.
- `search`: Ask for broader full-text recall with paging and filters.
- `skill`: Load a node with ancestry and children.
- `learn`: Load a node's knowledge payload and optionally ask for relevant sections.
- `graph`: Inspect nearby graph nodes.
- `backlinks`: Inspect inbound references.
- `alias`: Resolve human phrasing to a canonical URI.
- `bundle`: Fetch the portable package for a node.
- `agent_ask`: Ask for the best executable node with readiness details.
- `agent_learn`: Ask for answer-first guidance with section excerpts and follow-up skills.

# Selection Rules

- Prefer `discover` when the prompt might end in either reading or execution.
- Prefer `search` when you need recall, paging, or an explanation of why multiple nodes matched.
- Prefer `resolve` when the task is clearly action-first and you want the best single recommendation.
- Prefer `learn` after a node has already been selected.
- Prefer `bundle` only after the target node is stable.
