---
name: enrich
description: >
  Deepen a thin Dojo node with aliases, triggers, body content, sections,
  links, and related edges. Use after scaffolding or when improving node quality.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-authoring
allowed-tools: Bash Read Write Edit Grep WebFetch
---

# Enrich Node

Transform a skeleton or thin node into one that teaches well enough for agent consumption.

## When to Use

- After scaffolding a new node that needs knowledge content
- When a node exists but has empty aliases, triggers, body, or sections
- During quality review when validate/knowledge reports gaps
- When converting external docs into rich Dojo knowledge

## Workflow

### 1. Analyze the node

```bash
node ./scripts/enrich-node.js analyze nodes/<path>/node.json
```

Reports which knowledge fields are missing or thin:
- aliases < 3 entries
- triggers empty
- body < 100 words
- sections empty
- links empty
- related empty

### 2. Research the topic

If the node covers an external technology, gather official docs:
- API references, CLI help, SDK docs
- Auth model, rate limits, pagination
- Common workflows and examples

### 3. Write knowledge fields

**Aliases**: Real phrases agents use — abbreviations, acronyms, variant phrasings
**Triggers**: Complete task phrases with verb-object patterns
**Body**: Mental model → workflows → constraints → next-step links
**Sections**: Addressable chunks for the most likely questions
**Links**: Directed next steps with context annotations
**Related**: Semantic edges (prerequisite, see-also, implements)

### 4. Validate

```bash
node nodes/dojo/validate/knowledge/scripts/knowledge-only.js nodes/<path>/node.json
```

## Quality Signals

A well-enriched node has:
- 3+ aliases including abbreviations
- 3+ trigger phrases with verb-object patterns
- 200+ word body with code examples and wiki-links
- 2+ sections with meaningful IDs and tags
- 2+ links to other nodes
- 1+ related edge with typed relation
