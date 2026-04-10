# Contributing to Dojo

Dojo is a universal knowledge layer for AI agents — a registry of discoverable, composable, hierarchical nodes that agents query to learn and execute. This guide covers the project hierarchy, how to author nodes, how to publish, and how the core server pieces work.

---

## Project Structure

```
dojo/
├── nodes/          Canonical node tree — all ecosystems and their children
├── schema/         JSON Schema for validating node.json manifests
├── server/         Express registry server (REST API)
├── sdk/            JavaScript SDK for discovery, retrieval, and execution
├── web/            Vite + React browser UI
├── skills/         Bundled agent-facing skill packages
├── tests/          Server unit and integration tests
└── docker/         Dockerfile and docker-compose setup
```

### `nodes/`

The source of truth. Every ecosystem lives here as a directory tree of `node.json` manifests. The server reads this directory on startup and indexes everything into an in-memory store. If you are adding or editing knowledge, this is where you work.

```
nodes/
├── aws/            (iam, ec2, cloudformation, s3, rds, lambda)
├── database/
├── docker/
├── dojo/           (meta — Dojo documents itself)
├── ethereum/
├── frontend/
├── github/
├── notion/
├── openai/
├── postgres/
├── redis/
├── slack/
├── stripe/
├── twilio/
└── vercel/
```

### `server/`

Express app in `server/src/server.js`. Loads manifests from `nodes/`, indexes them with Fuse.js for full-text search, and exposes the `/v1` REST API. Run with:

```bash
cd server && npm install && npm run dev
```

### `sdk/`

JavaScript client in `sdk/src/index.js`. Wraps the registry API with methods like `need()`, `ask()`, `get()`, `search()`, `tree()`, `run()`, and `pipeline()`. Agents import this to interact with the registry programmatically.

### `web/`

Vite + React 19 + Tailwind CSS browser UI. Provides a visual explorer for the node tree. Build and serve through the registry:

```bash
cd web && npm install && npm run build
cd ../server && npm start
```

### `schema/`

`schema/node.schema.json` — the JSON Schema that all `node.json` manifests must validate against. The server and validation tools use this to enforce correctness.

---

## The Node Hierarchy

Dojo organizes knowledge into five node types. Together they form a tree (with cross-links making it a graph).

```
ecosystem (root)
│   Broad domain. No parent. Top of the tree.
│   Examples: openai, github, docker, aws
│
├── standard
│   A protocol, spec, or convention.
│   Can live under an ecosystem, skill, or another standard.
│   Examples: rest, graphql, oauth2
│
├── skill
│   A concrete, executable capability with scripts.
│   Can live under an ecosystem, standard, or another skill.
│   Examples: query, deploy, send, build
│
├── context
│   Info-only node. Wiki-like knowledge with no scripts.
│   Can live anywhere in the tree.
│   Examples: indexing-guide, caching-strategies, troubleshooting
│
└── sub
    Specialized variant of a skill.
    Must have a skill parent.
    Examples: deploy-preview, query-explain, build-multi-stage
```

### Nesting rules

1. An `ecosystem` has no parent — always the root
2. A `standard` can have any parent type except `sub`
3. A `skill` can have any parent type except `sub`
4. A `context` can have any parent type — most flexible
5. A `sub` must have a `skill` parent — always a leaf variant
6. Only `skill` and `sub` nodes may have `scripts`
7. Any node can have `depends` references to any other node

### What each type carries

| Type | `context` | `info` | `scripts` | `schema` | `sub` refs |
|------|:---------:|:------:|:---------:|:--------:|:----------:|
| `ecosystem` | yes | yes | no | no | yes |
| `standard` | yes | yes | no | no | yes |
| `skill` | yes | yes | yes | yes | yes |
| `context` | yes | yes | no | no | no |
| `sub` | yes | yes | yes | yes | no |

### Example tree

```
openai                                ecosystem
├── chat                              skill
│   ├── complete                      sub
│   └── stream                        sub
├── embeddings                        skill
├── assistants                        skill
│   └── threads                       skill (skill under skill)
│       ├── create                    sub
│       └── run                       sub
├── models                            context
└── rate-limits                       context
```

---

## How to Author a Node

### 1. Pick the right type

| If the node... | Use |
|----------------|-----|
| Has executable scripts that do something | `skill` or `sub` |
| Defines a protocol others conform to | `standard` |
| Provides information only — no code | `context` |

### 2. Create the directory and `node.json`

Every node is a directory containing a `node.json` manifest. The directory name matches the node `name`.

```
nodes/
└── myeco/
    ├── node.json              # ecosystem root
    └── my-skill/
        ├── node.json          # skill manifest
        ├── scripts/
        │   └── run.js         # executable entry point
        ├── agents/
        │   └── openai.yaml    # agent configuration
        ├── references/
        │   └── guide.md       # supplementary docs
        ├── tests/
        │   └── run.test.js    # test cases
        └── SKILL.md           # agent-facing skill description
```

### 3. Fill in required fields

Every `node.json` must have these fields:

```jsonc
{
  "name": "my-skill",                           // unique within parent
  "version": "1.0.0",                           // semver
  "uri": "myeco/my-skill",                      // full slash-separated path
  "type": "skill",                              // ecosystem | standard | skill | context | sub
  "context": "One-line description — agents read this first",
  "info": "Detailed paragraph explaining what this node does and why",
  "tags": ["relevant", "searchable", "keywords"],
  "parent": "myeco"                             // null for ecosystem roots
}
```

### 4. Add discovery fields

Help agents find your node with aliases and triggers:

```jsonc
{
  "aliases": ["my skill", "the skill", "alt name"],
  "triggers": [
    "natural language phrase that should activate this",
    "another way someone might ask for this"
  ]
}
```

### 5. Add knowledge (the wiki layer)

Every node can carry rich, linked content. This is what makes Dojo more than a package registry.

**`body`** — Long-form markdown content with headings, code blocks, tables, and wiki-links:

```jsonc
{
  "body": "# My Skill\n\nDetailed explanation...\n\nSee [[openai/chat]] for related usage.\nUse {{redis/cache}} when you need caching."
}
```

- `[[uri]]` — wiki-link to another node
- `[[uri#section-id]]` — link to a specific section
- `{{uri}}` — inline embed of another node's `context` one-liner

**`sections`** — Addressable subsections, individually fetchable via `uri#section-id`:

```jsonc
{
  "sections": [
    {
      "id": "setup",
      "title": "Setup",
      "body": "How to set up this skill...",
      "tags": ["setup", "install"]
    }
  ]
}
```

**`links`** — Explicit outgoing references with context annotations:

```jsonc
{
  "links": [
    { "uri": "openai/chat", "context": "For generating text responses" },
    { "uri": "redis/cache", "context": "Caching layer to reduce API calls" }
  ]
}
```

**`related`** — Semantic relationships between nodes:

```jsonc
{
  "related": [
    { "uri": "other/node", "relation": "see-also", "note": "Why they're related" }
  ]
}
```

Relation types: `similar`, `evolution`, `equivalent`, `prerequisite`, `alternative`, `implements`, `extends`, `see-also`.

**`frontmatter`** — Metadata for the knowledge layer:

```jsonc
{
  "frontmatter": {
    "created": "2026-04-10",
    "updated": "2026-04-10",
    "author": "your-name",
    "audience": "developers",
    "status": "living",
    "confidence": "high",
    "estimated_reading_time": "5 min"
  }
}
```

### 6. Add scripts (for skill and sub nodes)

Scripts make nodes executable. Use `entry` for file-based scripts or `inline` for short ones:

```jsonc
{
  "scripts": [
    {
      "id": "run-task",
      "name": "Run Task",
      "description": "What this script does",
      "lang": "javascript",
      "runtime": "node>=18",
      "entry": "./scripts/run.js",
      "env": {
        "API_KEY": { "required": true, "secret": true, "description": "API key" }
      },
      "packages": ["ethers@6"]
    }
  ]
}
```

Scripts receive input as JSON on stdin and return output as JSON on stdout. Exit 0 for success, exit 1 for failure (stderr for error messages).

### 7. Add input/output schema

Define the contract so agents know what to send and what to expect:

```jsonc
{
  "schema": {
    "input": {
      "type": "object",
      "properties": {
        "query": { "type": "string", "description": "The search query" }
      },
      "required": ["query"]
    },
    "output": {
      "type": "object",
      "properties": {
        "results": { "type": "array", "description": "Search results" }
      }
    }
  }
}
```

### 8. Declare dependencies

Reference other nodes your skill depends on:

```jsonc
{
  "depends": [
    { "uri": "openai", "reason": "Requires an OpenAI API key" },
    { "uri": "docker/images", "optional": true, "reason": "For containerized execution" }
  ]
}
```

### 9. Validate

Validate your manifest against the schema before publishing:

```bash
# Run the validation tests
cd nodes/dojo && node --test validate/tests/validate-node.test.js

# Or start the server and check that your node loads
cd server && npm run dev
curl http://localhost:3000/v1/skills/myeco/my-skill
```

---

## URI Format

URIs are slash-separated paths matching the directory structure. The type is not encoded in the URI — it lives in the manifest.

```
openai                          → ecosystem
openai/chat                     → skill
openai/chat/stream              → sub
openai/models                   → context
docker/compose/profiles         → standard (under a skill)
github/auth/oauth2/authorize    → skill (under a standard, under a context)
```

The URI must match the node's actual location in `nodes/`. A node at `nodes/openai/chat/node.json` has URI `openai/chat`.

---


## Quick Reference: Minimal Node Templates

### Ecosystem

```json
{
  "name": "myeco",
  "version": "1.0.0",
  "uri": "myeco",
  "type": "ecosystem",
  "context": "One-line description of this domain",
  "info": "Detailed explanation of what this ecosystem covers.",
  "parent": null,
  "tags": ["myeco", "relevant", "keywords"],
  "author": "your-name",
  "license": "MIT"
}
```

### Skill

```json
{
  "name": "my-skill",
  "version": "1.0.0",
  "uri": "myeco/my-skill",
  "type": "skill",
  "context": "What this skill does in one line",
  "info": "Detailed explanation of the skill's capabilities.",
  "parent": "myeco",
  "tags": ["skill", "keywords"],
  "scripts": [
    {
      "id": "main",
      "name": "Run",
      "description": "What the script does",
      "lang": "javascript",
      "runtime": "node>=18",
      "entry": "./scripts/main.js"
    }
  ],
  "author": "your-name",
  "license": "MIT"
}
```

### Context

```json
{
  "name": "my-guide",
  "version": "1.0.0",
  "uri": "myeco/my-guide",
  "type": "context",
  "context": "Guide to understanding X",
  "info": "Detailed explanation of the topic this guide covers.",
  "parent": "myeco",
  "tags": ["guide", "reference"],
  "body": "# My Guide\n\nFull markdown content here...\n\nSee [[myeco/my-skill]] for the executable version.",
  "author": "your-name",
  "license": "MIT"
}
```

### Sub-skill

```json
{
  "name": "variant",
  "version": "1.0.0",
  "uri": "myeco/my-skill/variant",
  "type": "sub",
  "context": "Specialized variant of my-skill for a specific use case",
  "info": "When and why to use this variant instead of the parent skill.",
  "parent": "myeco/my-skill",
  "tags": ["variant", "specialized"],
  "scripts": [
    {
      "id": "main",
      "name": "Run Variant",
      "lang": "bash",
      "inline": "echo 'running variant'"
    }
  ],
  "author": "your-name",
  "license": "MIT"
}
```

---

## Checklist Before Submitting

- [ ] `node.json` has all required fields (`name`, `version`, `uri`, `type`, `context`, `info`, `tags`)
- [ ] `uri` matches the directory path under `nodes/`
- [ ] `parent` matches the actual parent node's URI (null for ecosystems)
- [ ] `version` is valid semver
- [ ] `type` is one of: `ecosystem`, `standard`, `skill`, `context`, `sub`
- [ ] Scripts only exist on `skill` or `sub` nodes
- [ ] `sub` nodes have a `skill` parent
- [ ] Knowledge fields (`body`, `sections`, `links`) use valid `[[uri]]` wiki-link syntax
- [ ] Validates against `schema/node.schema.json`
- [ ] Server loads your node without errors (`npm run dev` and check the logs)
- [ ] For executable skills: scripts run, env vars are documented, input/output schema is defined
