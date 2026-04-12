---
name: search
description: >
  Search and discover nodes in the Dojo knowledge graph by query, alias, tag,
  or trigger phrase. Use when an agent needs to find the right node before
  learning or executing a capability.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-discovery
allowed-tools: Bash Read Grep
---

# Dojo Search

Find nodes in the Dojo knowledge graph using text search, alias resolution, trigger matching, or tag filtering.

## When to Use

- An agent receives a task and needs to find the relevant Dojo node
- You need to discover what capabilities exist for a given technology
- You want to resolve an abbreviation (like `k8s`) to its canonical node
- You need to browse nodes by category/tag

## Workflow

### 1. Determine the search strategy

| User input | Strategy | Example |
|------------|----------|---------|
| A task phrase | Trigger matching | "deploy to vercel" |
| An abbreviation | Alias resolution | "k8s", "gh" |
| A topic keyword | Text search | "kubernetes", "authentication" |
| A category | Tag filtering | tag:deploy, type:skill |

### 2. Execute the search

**Against a running server:**

```bash
# Text search
curl "$DOJO_URL/v1/search?q=deploy+to+vercel&limit=5"

# Filter by type
curl "$DOJO_URL/v1/search?q=auth&type=context"

# Resolve alias
curl "$DOJO_URL/v1/alias/k8s"
```

**Against local filesystem:**

```bash
# Search node.json files by content
grep -r "deploy" nodes/ --include="node.json" -l

# Search by trigger phrase
./scripts/search-nodes.sh "deploy to vercel"
```

### 3. Evaluate results

Read the `context` field of each result to decide relevance. If the top result matches, proceed to `dojo learn <uri>`. If no good match:
- Broaden the query terms
- Try alias resolution for abbreviations
- Use graph traversal from a near-match node

## Search Ranking

Results are scored by field weight:
- triggers: 1.0 (highest — direct intent match)
- aliases: 0.9
- name: 0.85
- context: 0.8
- tags: 0.7
- info: 0.5
- body: 0.3
- sections: 0.2

## Edge Cases

- **No results**: Broaden the query, check for typos, try related terms
- **Too many results**: Add tag or type filters to narrow down
- **Alias collision**: Two nodes claiming the same alias — shallower node wins
- **Partial trigger match**: Score must exceed 0.6 threshold to count as a match
