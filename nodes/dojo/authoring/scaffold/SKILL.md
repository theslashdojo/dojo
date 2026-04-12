---
name: scaffold
description: >
  Generate a new Dojo node directory with skeleton node.json and optional
  SKILL.md from a type template. Use when creating new nodes from scratch.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-authoring
allowed-tools: Bash Write
---

# Scaffold Node

Generate a new Dojo node directory with a valid skeleton node.json.

## When to Use

- Starting a brand new node from scratch
- Creating multiple nodes as part of a new ecosystem tree
- Need a correctly structured starting point that passes schema validation

## Workflow

### 1. Choose type and URI

```bash
# Ecosystem (top-level)
./scripts/scaffold-node.sh ecosystem redis

# Skill under existing parent
./scripts/scaffold-node.sh skill github/actions/workflows

# Context node
./scripts/scaffold-node.sh context kubernetes/troubleshooting

# Sub-skill under a skill
./scripts/scaffold-node.sh sub github/repos/create
```

### 2. Review generated files

The script creates:
- `nodes/<uri>/node.json` — skeleton manifest with TODO placeholders
- `nodes/<uri>/SKILL.md` — Agent Skills frontmatter (skill/sub only)
- `nodes/<uri>/scripts/` — empty scripts directory (skill/sub only)

### 3. Fill in placeholders

Replace all `TODO` markers with real content. The skeleton is valid JSON
but has placeholder text that will fail knowledge validation.

## What the Scaffold Generates

- All required fields pre-filled (name, version, uri, type, parent)
- Knowledge field stubs (aliases: [], triggers: [], body: "", sections: [])
- Script stubs for skill/sub types
- Correct parent derivation from URI
- Today's date for created/updated
- Status set to "draft"
