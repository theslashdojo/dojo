---
name: authoring
description: >
  Create, scaffold, and enrich Dojo nodes with proper structure, knowledge
  fields, and executable scripts. Use when building new ecosystem trees or
  expanding existing ones.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-authoring
allowed-tools: Bash Read Write Edit Glob Grep
---

# Dojo Node Authoring

Create and enrich Dojo knowledge graph nodes following the spec contract.

## When to Use

- Creating a new ecosystem, skill, or context node
- Expanding an existing tree with new child nodes
- Converting external documentation into Dojo nodes
- Enriching thin/skeleton nodes with knowledge content

## Workflow

### 1. Plan the node

Decide: what type? where in the tree? what capability does it represent?

| Type | Purpose | Has scripts? |
|------|---------|-------------|
| ecosystem | Vendor/platform namespace | No |
| standard | Protocol/spec/convention | No |
| skill | Executable capability | Yes |
| context | Reference material/guide | No |
| sub | Specialized skill variant | Yes |

### 2. Scaffold the structure

```bash
# Create directory and skeleton files
./scripts/create-node.sh <type> <uri>

# Examples
./scripts/create-node.sh ecosystem redis
./scripts/create-node.sh skill github/actions/workflows
./scripts/create-node.sh context kubernetes/troubleshooting
```

### 3. Write node.json

Fill in all fields per the spec:

**Required**: name, version, uri, type, context, info, parent, tags
**Knowledge**: aliases, triggers, body, sections, links, related
**Execution** (skill/sub): scripts, schema, depends

### 4. Write knowledge content

- `context`: One line under 200 chars — when to use this node
- `info`: Dense paragraph — scope, surface, why it matters
- `aliases`: Real phrases agents say (abbreviations, synonyms)
- `triggers`: Complete task phrases (verb + object)
- `body`: Markdown with code examples and `[[wiki-links]]`
- `sections`: Addressable chunks for likely questions
- `links`: Directed next steps with context
- `related`: Semantic edges (prerequisite, see-also, implements)

### 5. Add scripts (skill/sub only)

Create real executable scripts in `scripts/`:
- Include env var declarations with required/secret/default
- Include package dependencies
- Write SKILL.md for portable bundling

### 6. Validate

```bash
# Full validation
dojo validate nodes/<path>/node.json

# Or use the validate skill directly
node nodes/dojo/validate/scripts/validate-node.js nodes/<path>/node.json
```

## Quality Checklist

- [ ] context is one line, under 200 chars, not repeated in info
- [ ] aliases include abbreviations and phrase variants (3+ entries)
- [ ] triggers are complete task phrases (3+ entries)
- [ ] body has code examples and wiki-links (200+ words)
- [ ] sections have meaningful IDs and tags (2+ sections)
- [ ] links point to real nodes (2+ links)
- [ ] related has at least 1 semantic edge
- [ ] scripts are real executable code (no placeholders)
- [ ] schema documents actual inputs and outputs
