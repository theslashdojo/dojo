# Dojo Specification v0.1.0

## 1. Overview

Dojo defines a universal format for AI agent skills and knowledge, discoverable, composable, hierarchical units of capability. Any agent, any framework, any LLM can query the registry and get back executable skills  and knowledge with full context.


The knowledge layer is what makes Dojo more than npm. Every node in the tree eco, standard, skill, context, sub can carry rich, linked, wiki-like content. They are the Obsidian notes of the agent world. Context nodes are how agents learn.

### 1.1 Design Principles

1. **Hierarchical** — Skills form trees, ecosystem → standard → skill → sub-skill
2. **Self-describing** — Every skill carries its own context, docs, and schema
3. **Composable** — Skills reference and depend on other skills
4. **Agent-native** — Designed for LLM agents to discover and execute, not just humans
5. **Wiki-like** — Rich info fields, linked references, living documentation
6. **Executable** — Scripts are first-class: agents run them, not just read them

---

## 2. Node Manifest (`node.json`)

Every node is defined by a `node.json` file. This is the atomic unit of the ecosystem.

### 2.1 Full Schema

```jsonc
{
  // ─── Identity ───────────────────────────────────────
  "name": "deploy",                          // REQUIRED — unique within parent
  "version": "1.2.0",                        // REQUIRED — semver
  "uri": "vercel/deployments/deploy",        // REQUIRED — full path in tree
  "type": "skill",                             // REQUIRED — "ecosystem" | "standard" | "skill" | "context" | "sub"

  // ─── Context (what agents read first) ───────────────
  "context": "Deploy a web application to Vercel — production, preview, or rollback",
  "info": "Handles project detection, build configuration, environment variable injection, and deployment to Vercel's edge network. Supports Next.js, React, Svelte, static sites, and any framework with a build command.",

  // ─── Hierarchy ──────────────────────────────────────
  "parent": "vercel/deployments",
  "skills": [],                              // inline child skills (full manifests)
  "sub": [                                   // references to sub-skills
    "vercel/deployments/deploy/production",
    "vercel/deployments/deploy/preview",
    "vercel/deployments/deploy/rollback"
  ],

  // ─── Discovery ──────────────────────────────────────
  "tags": ["vercel", "deploy", "nextjs", "production", "preview", "hosting"],
  "triggers": [
    "deploy to vercel",
    "push to production",
    "deploy my website",
    "create a preview deployment"
  ],

  // ─── Documentation ─────────────────────────────────
  "more": {
    "docs": "https://vercel.com/docs/deployments",
    "examples": "https://github.com/dojo/examples/vercel",
    "wiki": "https://dojo.dev/wiki/vercel/deployments/deploy"
  },

  // ─── Scripts (the executable parts) ─────────────────
  "scripts": [
    {
      "id": "deploy-production",
      "name": "Deploy to Production",
      "description": "Deploy the current project to production on Vercel",
      "lang": "bash",
      "runtime": "node>=18",
      "entry": "./scripts/deploy.sh",
      "inline": null,
      "env": {
        "VERCEL_TOKEN": { "required": true, "secret": true, "description": "Vercel API token" },
        "VERCEL_ORG_ID": { "required": false, "description": "Vercel organization ID" },
        "VERCEL_PROJECT_ID": { "required": false, "description": "Vercel project ID" }
      }
    },
    {
      "id": "deploy-preview",
      "name": "Preview Deploy",
      "description": "Create a preview deployment with a unique URL",
      "lang": "bash",
      "inline": "vercel deploy --token $VERCEL_TOKEN"
    }
  ],

  // ─── Schema (input/output contract) ─────────────────
  "schema": {
    "input": {
      "type": "object",
      "properties": {
        "directory": { "type": "string", "description": "Project directory to deploy" },
        "environment": { "type": "string", "enum": ["production", "preview", "development"] },
        "env_vars": { "type": "object", "description": "Environment variables to inject" },
        "framework": { "type": "string", "description": "Override framework detection" }
      },
      "required": ["directory"]
    },
    "output": {
      "type": "object",
      "properties": {
        "url": { "type": "string", "description": "Deployment URL" },
        "deployment_id": { "type": "string" },
        "status": { "type": "string" },
        "created_at": { "type": "string", "format": "date-time" }
      }
    }
  },

  // ─── Dependencies ───────────────────────────────────
  "depends": [
    { "uri": "openai/embeddings", "optional": true },
    { "uri": "docker/images", "optional": false }
  ],

  // ─── Meta ───────────────────────────────────────────
  "author": "dojo-community",
  "license": "MIT",
  "repository": "https://github.com/dojo-registry/vercel",
  "created": "2026-04-05T00:00:00Z",
  "updated": "2026-04-05T00:00:00Z"
}
```

### 2.2 Field Reference

#### Identity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Unique name within parent scope |
| `version` | string | ✅ | Semantic version (semver) |
| `uri` | string | ✅ | Full slash-separated path: `ecosystem/standard/skill/sub` |
| `type` | enum | ✅ | One of: `ecosystem`, `standard`, `skill`, `context`, `sub` |

#### Context Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `context` | string | ✅ | One-line description — this is what agents read first to decide relevance |
| `info` | string | ✅ | Detailed wiki-like description with full capability explanation |

#### Hierarchy Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `parent` | string | ✅* | URI of parent skill (null for ecosystem roots) |
| `skills` | array | ❌ | Inline child skill manifests (full `skill.json` objects) |
| `sub` | array | ❌ | URI references to sub-skills |

#### Discovery Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tags` | array | ✅ | Searchable tags for discovery |
| `triggers` | array | ❌ | Natural language phrases that should activate this skill |

#### Script Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `scripts` | array | ❌ | Executable code blocks |
| `scripts[].id` | string | ✅ | Unique script identifier |
| `scripts[].lang` | string | ✅ | Language: `javascript`, `python`, `bash`, `typescript` |
| `scripts[].entry` | string | ❌ | Path to script file (relative to skill root) |
| `scripts[].inline` | string | ❌ | Inline script content (alternative to entry) |
| `scripts[].env` | object | ❌ | Environment variables with metadata |

---

## 3. Type Hierarchy

Five node types. The nesting is **flexible** — any type can appear at any depth, with a few constraints.

```
ecosystem (root)
│   Broad domain. No parent. The top of the tree.
│   Examples: openai, github, docker, aws, postgres
│
├── standard
│   A protocol, spec, or convention. Can live under an eco,
│   a skill, or even another standard.
│   Examples: rest, graphql, oauth2, openapi
│
├── skill
│   A concrete, executable capability with scripts.
│   Can live under an eco, a standard, or another skill.
│   Examples: query, deploy, send, build
│
├── context
│   An info-only node. Wiki-like documentation with no scripts.
│   Used for reference material, guides, specs, or grouping.
│   Can live anywhere in the tree.
│   Examples: indexing-guide, caching-strategies, troubleshooting
│
└── sub
    A specialized variant of a skill.
    Must have a skill parent.
    Examples: deploy-preview, query-explain, build-multi-stage
```

### 3.1 Rules

1. An `ecosystem` has no parent — it is always the root
2. A `standard` can have any parent type except `sub`
3. A `skill` can have any parent type except `sub`
4. A `context` can have any parent type — it is the most flexible node
5. A `sub` must have a `skill` parent — it is always a leaf variant
6. Only `skill` and `sub` nodes may have `scripts` — standards and contexts never execute
7. Inline `skills` array can nest to any depth
8. Any node can have `depends` references to any other node

For contributor ergonomics, the docs recommend the simpler layout `ecosystem -> standard -> skill -> sub`, but the rules above are the source of truth for validity.

### 3.2 What Each Type Carries

| Type | `context` field | `info` field | `scripts` | `schema` | `sub` refs |
|------|:-:|:-:|:-:|:-:|:-:|
| `ecosystem` | ✅ | ✅ | ❌ | ❌ | ✅ |
| `standard` | ✅ | ✅ | ❌ | ❌ | ✅ |
| `skill` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `context` | ✅ | ✅ | ❌ | ❌ | ❌ |
| `sub` | ✅ | ✅ | ✅ | ✅ | ❌ |

### 3.3 Nesting Examples

**OpenAI** — standards and skills under the eco, with context nodes for guides:

```
openai                                eco
├── chat                              skill
│   ├── complete                      sub
│   └── stream                        sub
├── embeddings                        skill
├── assistants                        skill
│   └── threads                       skill (skill under skill)
│       ├── create                    sub
│       └── run                       sub
├── models                            context (info about available models)
└── rate-limits                       context (guide to rate limit handling)
```

**Docker** — skills directly under eco, standards nested under skills:

```
docker                                eco
├── images                            skill
│   ├── build                         sub
│   ├── push                          sub
│   └── multi-stage                   sub
├── containers                        skill
│   ├── run                           sub
│   ├── exec                          sub
│   └── logs                          sub
├── compose                           skill
│   └── profiles                      standard (nested under a skill!)
│       └── activate                  skill
├── best-practices                    context (Dockerfile tips, no scripts)
└── networking                        context (bridge, host, overlay modes)
```

**GitHub** — skills directly under eco, context node grouping auth:

```
github                                eco
├── repos                             skill
│   ├── create                        sub
│   ├── clone                         sub
│   └── settings                      sub
├── issues                            skill
├── pulls                             skill
├── actions                           skill
│   └── workflows                     skill (skill under skill)
│       ├── deploy                    sub
│       └── test                      sub
└── auth                              context (info about GitHub auth)
    └── oauth2                        standard
        └── authorize                 skill
```

**Key insight**: `docker/compose/profiles` is a standard that lives under a skill. This is valid — standards describe *what protocol* a skill or its children follow, regardless of where they sit in the tree. Similarly, `github/auth` is a context node that groups auth-related info and children, even though it has no scripts itself.

### 3.4 URI Format

URIs are slash-separated paths. The type is not encoded in the URI — it lives in the manifest.

```
openai                                → eco
openai/chat                           → skill
openai/chat/stream                    → sub
openai/models                         → context
docker                                → eco
docker/images                         → skill
docker/images/build                   → sub
docker/compose                        → skill
docker/compose/profiles               → standard (under a skill)
docker/best-practices                 → context
github/repos                          → skill
github/repos/create                   → sub
github/auth                           → context
github/auth/oauth2                    → standard
github/auth/oauth2/authorize          → skill
```

### 3.5 The `context` Type

Context nodes are first-class citizens — not secondary to skills. Dojo is a **knowledge graph with executable skills**, not a skill registry with docs attached. Context nodes are how agents learn.

---

## 4. Knowledge Layer

The knowledge layer is what makes Dojo more than npm. Every node in the tree — eco, standard, skill, context, sub — can carry rich, linked, wiki-like content. But `context` nodes exist *purely* for knowledge. They are the Obsidian notes of the agent world.

### 4.1 The `body` Field

Every node can carry a `body` — long-form markdown content that goes far beyond the one-line `context` and paragraph-length `info`:

```json
{
  "name": "indexing",
  "type": "context",
  "uri": "postgres/indexing",
  "context": "PostgreSQL indexing strategies — B-tree, GIN, GiST, and partial indexes",
  "info": "How to choose and create indexes for common query patterns.",
  "body": "# PostgreSQL Indexing\n\nIndexes speed up queries by creating sorted data structures...\n\n## B-tree (default)\n\nThe default index type. Works for equality and range queries...\n\n## Partial Indexes\n\nIndex only a subset of rows with a WHERE clause...\n\n## See also\n\n- [[postgres/queries/explain]] — use EXPLAIN ANALYZE to verify index usage\n- [[redis/cache]] — caching as an alternative to indexing"
}
```

The `body` supports:
- Full markdown (headings, code blocks, tables, lists)
- Wiki-links via `[[uri]]` syntax — links to other nodes in the graph
- Inline references via `{{uri}}` — embeds the `context` one-liner of another node
- Code examples with language tags
- Math notation (LaTeX)

### 4.2 Sections

Long bodies can be split into addressable sections:

```json
{"body":"",
  "sections": [
    {
      "id": "btree",
      "title": "B-tree indexes",
      "body": "The default index type in PostgreSQL. Supports =, <, >, <=, >=, BETWEEN, IN, IS NULL...",
      "tags": ["btree", "default", "range", "equality"]
    },
    {
      "id": "partial",
      "title": "Partial indexes",
      "body": "Index only rows matching a WHERE clause. Saves disk space and speeds up queries on common filters...",
      "tags": ["partial", "where", "conditional", "space"]
    },
    {
      "id": "gin",
      "title": "GIN indexes",
      "body": "Generalized Inverted Index. Best for full-text search, JSONB containment, and array operations...",
      "tags": ["gin", "fulltext", "jsonb", "arrays"]
    }
  ]
}
```

Sections are individually addressable: `postgres/indexing#btree`. Agents can fetch a specific section without loading the entire body. The registry API supports section-level queries.

### 4.3 Wiki-Links

Nodes link to each other using `[[uri]]` syntax inside `body`, `info`, or section content:

```markdown
Use [[postgres/queries/explain]] to check whether your index is being used.
For write-heavy workloads, consider [[redis/cache]] instead of adding more indexes.
See [[postgres/indexing#partial]] for conditional indexes.
```

The registry resolves these links and builds a **backlink graph** — every node knows what links *to* it, not just what it links *from*. This is the Obsidian model.

### 4.4 Links and Backlinks

Every node carries explicit link metadata:

```json
{
  "links": [
    { "uri": "postgres/queries/explain", "context": "verify index usage with EXPLAIN" },
    { "uri": "redis/cache", "context": "caching as alternative to indexing" },
    { "uri": "postgres/indexing#partial", "context": "partial index section" }
  ]
}
```

The registry computes backlinks automatically:

```
GET /v1/backlinks/postgres/queries/explain

{
  "backlinks": [
    { "from": "postgres/indexing", "context": "Verify index usage with EXPLAIN ANALYZE" },
    { "from": "postgres/queries", "context": "Performance debugging" },
    { "from": "redis/cache", "context": "Decide whether to cache or index" }
  ]
}
```

This lets agents navigate the knowledge graph in both directions — "what does this node reference?" and "what references this node?"

### 4.5 Aliases

Nodes can have aliases — alternative names agents might use to find them:

```json
{
  "name": "postgres",
  "aliases": ["postgresql", "pg", "psql", "postgres database"],
  "uri": "postgres"
}
```

When an agent searches for "psql" or "postgresql", it matches `postgres` via aliases even if those words don't appear in tags or context.

### 4.6 Related Nodes

Beyond explicit links and dependencies, nodes declare semantic relationships:

```json
{
  "related": [
    { "uri": "postgres/queries", "relation": "similar", "note": "Same concept for PostgreSQL specifically" },
    { "uri": "redis/cache", "relation": "alternative", "note": "Cache layer to reduce database queries" },
    { "uri": "openai/embeddings", "relation": "prerequisite", "note": "Generate embeddings before storing in vector DB" }
  ]
}
```

Relation types: `similar`, `evolution`, `equivalent`, `prerequisite`, `alternative`, `implements`, `extends`, `see-also`.

### 4.7 Knowledge-Only Queries

The registry API has dedicated endpoints for knowledge retrieval:

```
GET /v1/learn/{uri}
```

Returns the full knowledge payload — body, sections, links, backlinks, related, ancestry — optimized for an agent that wants to *understand* something, not execute it:

```json
{
  "node": {
    "uri": "postgres/indexing",
    "type": "context",
    "context": "PostgreSQL indexing strategies — B-tree, GIN, GiST, and partial indexes",
    "body": "# PostgreSQL Indexing\n\n...",
    "sections": [ ... ]
  },
  "backlinks": [ ... ],
  "related": [ ... ],
  "ancestors": [
    { "uri": "postgres", "context": "PostgreSQL ecosystem" }
  ],
  "reading_path": [
    { "uri": "postgres/indexing#btree", "why": "Understand the default index type first" },
    { "uri": "postgres/indexing#partial", "why": "Then learn when to use partial indexes" },
    { "uri": "postgres/queries/explain", "why": "Apply knowledge with EXPLAIN ANALYZE" }
  ]
}
```

The `reading_path` is computed from section order + outgoing links — it suggests the optimal order for an agent to consume the knowledge.

```
GET /v1/graph/{uri}?depth=2
```

Returns the local knowledge graph around a node — all nodes within N hops via links, backlinks, depends, and related:

```json
{
  "center": "postgres/indexing",
  "nodes": [
    { "uri": "postgres/indexing", "type": "context", "context": "..." },
    { "uri": "postgres/queries", "type": "skill", "context": "..." },
    { "uri": "postgres/queries/explain", "type": "sub", "context": "..." },
    { "uri": "postgres/indexing#btree", "type": "section", "context": "..." }
  ],
  "edges": [
    { "from": "postgres/indexing", "to": "postgres/queries", "type": "link" },
    { "from": "postgres/indexing", "to": "postgres/queries/explain", "type": "depends" },
    { "from": "redis/cache", "to": "postgres/indexing", "type": "backlink" }
  ]
}
```

### 4.8 Agent Knowledge Protocol

When an agent encounters something it doesn't understand, it queries the knowledge layer:

```
POST /v1/agent/learn
{
  "question": "How do I optimize slow PostgreSQL queries?",
  "current_context": ["postgres/queries"]
}
```

Response:

```json
{
  "answer_nodes": [
    {
      "uri": "postgres/indexing",
      "relevance": 0.95,
      "sections": ["btree", "partial"],
      "excerpt": "Use EXPLAIN ANALYZE to identify missing indexes. B-tree indexes cover most cases. Partial indexes save space when you only query a subset of rows."
    }
  ],
  "then_do": [
    {
      "uri": "postgres/queries/explain",
      "type": "sub",
      "reason": "Run EXPLAIN ANALYZE on the slow query to see the execution plan"
    }
  ]
}
```

The `then_do` field bridges knowledge → action. The agent reads, understands, then executes.

### 4.9 Content Types

Context nodes support different content types for different kinds of knowledge:

| Content Type | Use Case | Example |
|-------------|----------|---------|
| `reference` | Factual documentation, specs, API references | openai/models, postgres/datatypes |
| `guide` | Step-by-step walkthroughs, tutorials | docker/getting-started, vercel/quickstart |
| `explainer` | Conceptual explanations, mental models | redis/caching-strategies, postgres/indexing |
| `comparison` | Side-by-side analysis of alternatives | database/sql-vs-nosql, aws/lambda-vs-ecs |
| `changelog` | Version history, migration notes | openai/chat/changelog |
| `faq` | Common questions and answers | docker/troubleshooting |
| `glossary` | Term definitions | kubernetes/glossary, postgres/glossary |

```json
{
  "name": "sql-vs-nosql",
  "type": "context",
  "content_type": "comparison",
  "uri": "database/sql-vs-nosql",
  "context": "SQL vs NoSQL — when to use relational vs document databases",
  "body": "| | SQL (Postgres, MySQL) | NoSQL (MongoDB, DynamoDB) |\n|---|---|---|\n| Schema | Rigid, enforced | Flexible, schemaless |\n| Joins | Native, efficient | Manual, application-level |\n| Scale | Vertical (+ read replicas) | Horizontal (sharding) |\n| Best for | Complex queries, transactions | High throughput, flexible data |",
  "comparison": {
    "subjects": ["sql", "nosql"],
    "dimensions": ["schema", "joins", "scaling", "transactions", "flexibility"]
  }
}
```

### 4.10 Frontmatter

Context nodes support Obsidian-style frontmatter for metadata that doesn't fit standard fields:

```json
{
  "frontmatter": {
    "created": "2026-01-15",
    "updated": "2026-04-05",
    "author": "dojo-community",
    "status": "living",
    "confidence": "high",
    "source": "https://www.postgresql.org/docs/current/indexes.html",
    "audience": "developers",
    "prerequisites": ["postgres", "database/sql"],
    "estimated_reading_time": "8 min"
  }
}
```

### 4.11 Knowledge vs Skills — The Full Picture

Dojo is a single graph with two faces:

```
                    ┌─────────────────────────┐
                    │      Dojo Graph      │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
    ┌─────────▼──────────┐  ┌───▼────┐  ┌──────────▼──────────┐
    │   Knowledge Layer  │  │  Links │  │   Execution Layer   │
    │                    │  │        │  │                     │
    │  context nodes     │◀─┤ wiki   ├─▶│  skill nodes        │
    │  body / sections   │  │ links  │  │  scripts / schema   │
    │  guides            │  │ back   │  │  env / runtime      │
    │  comparisons       │  │ links  │  │  sandbox            │
    │  references        │  │ deps   │  │  I/O                │
    │  glossaries        │  │related │  │                     │
    └────────────────────┘  └────────┘  └─────────────────────┘
```

An agent's workflow:
1. **Discover** — "I need to set up a caching layer for my API"
2. **Learn** — Read `redis/caching-strategies` (context: when to cache, TTL patterns, invalidation)
3. **Understand** — Follow links to `postgres/indexing` (context: maybe indexing solves it without a cache)
4. **Plan** — See related skills: `redis/cache`, `postgres/queries/explain`
5. **Execute** — Run `redis/cache` with full understanding of what it does and why

This is the fundamental difference from npm: npm gives you a package to install. Dojo gives you the knowledge to understand *what you're doing* and *then* the code to do it.

### 3.6 Standard vs Skill vs Context — When to Use Which

| Use... | When the node... | Example |
|--------|-----------------|---------|
| `standard` | Defines a protocol or spec that other skills implement | oauth2, graphql, rest, openapi |
| `skill` | Has executable scripts that do something | deploy, query, send-message, build |
| `context` | Provides information only — no code, just knowledge | caching-strategies, indexing, auth-guide, troubleshooting |

Rule of thumb: if it has scripts, it's a `skill` or `sub`. If it defines a standard that others conform to, it's a `standard`. If it's purely informational, it's a `context`. Most real ecosystems will have **more context nodes than skills** — the knowledge graph is bigger than the executable surface.

---

## 5. Registry API

The registry is a REST API that agents call to discover and resolve skills.

### 4.1 Endpoints

#### Resolve a skill need (agent-facing)

```
GET /v1/resolve?need={description}&tags={tags}&type={type}
```

The primary endpoint. An agent describes what it needs in natural language or tags, and gets back matching skills ranked by relevance.

**Request:**
```
GET /v1/resolve?need=deploy+nextjs+app&tags=vercel,production&type=sub
```

**Response:**
```json
{
  "results": [
    {
      "uri": "vercel/deployments/deploy/production",
      "score": 0.95,
      "context": "Deploy a web app to Vercel production",
      "skill": { /* full skill.json */ }
    }
  ],
  "total": 3,
  "resolved_in_ms": 42
}
```

#### Get a skill by URI

```
GET /v1/skills/{uri}
```

Returns the full skill manifest with resolved parent chain.

**Response:**
```json
{
  "skill": { /* full skill.json */ },
  "ancestors": [
    { "uri": "vercel", "context": "Vercel — deploy web apps, manage domains" },
    { "uri": "vercel/deployments", "context": "Deploy projects — production, preview, rollback" }
  ],
  "children": [
  "children": [
    { "uri": "vercel/deployments/deploy/production", "context": "Deploy to production" },
    { "uri": "vercel/deployments/deploy/preview", "context": "Create preview deployment" }
  ]
}
```

#### Search skills

```
GET /v1/search?q={query}&eco={ecosystem}&limit={n}
```

Full-text + tag search across the registry.

#### List ecosystem tree

```
GET /v1/tree/{ecosystem}
```

Returns the full hierarchy for an ecosystem.

#### Publish a skill

```
POST /v1/skills
Authorization: Bearer {token}
Content-Type: application/json

{ /* skill.json */ }
```

### 4.2 Agent Protocol

For LLM agents that want to use Dojo as a tool, the registry exposes a simplified endpoint:

```
POST /v1/agent/ask
Content-Type: application/json

{
  "message": "I need to deploy a Next.js app to production and send a Slack notification when it's done",
  "agent_context": {
    "capabilities": ["javascript", "bash"],
    "has_env": ["VERCEL_TOKEN"]
  }
}
```

**Response:**
```json
{
  "recommendation": "vercel/deployments/deploy",
  "explanation": "Deploys web applications to Vercel's edge network with support for Next.js, React, and static sites.",
  "install": "dojo install vercel/deployments/deploy",
  "skill": { /* full manifest */ },
  "missing_env": ["SLACK_TOKEN"],
  "alternatives": [
    { "uri": "docker/images/build", "reason": "Build a Docker image instead of deploying to Vercel" }
  ]
}
```

---

## 6. Inline Skills (Obsidian-style)

Skills can embed full child skills inline, creating self-contained trees:

```json
{
  "name": "docker",
  "type": "ecosystem",
  "uri": "docker",
  "context": "Docker — build images, run containers, compose services",
  "info": "Full Docker lifecycle: images, containers, Compose, registries.",
  "tags": ["docker", "containers", "devops"],
  "skills": [
    {
      "name": "images",
      "type": "skill",
      "uri": "docker/images",
      "context": "Build, tag, and push Docker images",
      "parent": "docker",
      "scripts": [
        {
          "id": "build",
          "name": "Build Image",
          "lang": "bash",
          "inline": "docker build -t $IMAGE_TAG ."
        }
      ],
      "skills": [
        {
          "name": "multi-stage",
          "type": "sub",
          "uri": "docker/images/multi-stage",
          "context": "Multi-stage builds for smaller production images",
          "parent": "docker/images",
          "scripts": [
            {
              "id": "build-multi",
              "name": "Multi-stage Build",
              "lang": "bash",
              "inline": "docker build --target production -t $IMAGE_TAG ."
            }
          ]
        }
      ]
    },
    {
      "name": "compose",
      "type": "skill",
      "uri": "docker/compose",
      "context": "Multi-container apps with Docker Compose",
      "parent": "docker",
      "scripts": [
        {
          "id": "up",
          "name": "Start Services",
          "lang": "bash",
          "inline": "docker compose up -d"
        }
      ]
    },
    {
      "name": "best-practices",
      "type": "context",
      "uri": "docker/best-practices",
      "context": "Dockerfile best practices — layer caching, security, image size",
      "parent": "docker",
      "body": "# Dockerfile Best Practices\n\n1. Use specific base image tags\n2. Order layers by change frequency\n3. Use multi-stage builds\n4. Don't run as root\n5. Use .dockerignore"
    }
  ]
}
```

---

## 7. Cross-Skill References

Skills can reference skills from other ecosystems using the `depends` field:

```json
{
  "uri": "vercel/deployments/deploy",
  "depends": [
    { "uri": "docker/images/build", "optional": true, "reason": "Build Docker image for containerized deploys" },
    { "uri": "github/repos", "optional": true, "reason": "Auto-deploy from GitHub repo" },
    { "uri": "slack/messages/send", "optional": true, "reason": "Notify team on deployment" }
  ]
}
```

This creates a graph (not just a tree), enabling skills to compose across ecosystem boundaries.

---

## 8. Versioning

Skills use semantic versioning (semver). The registry supports multiple resolution strategies:

### 7.1 Version Specifiers

```
openai/chat@1.2.0     → exact version
openai/chat@^1.0.0    → compatible range (>=1.0.0 <2.0.0)
openai/chat@~1.2.0    → patch range (>=1.2.0 <1.3.0)
openai/chat@>=1.0.0   → minimum version
openai/chat@latest    → latest stable release
openai/chat@next      → latest pre-release
```

### 7.2 Semver Semantics for Skills

Skill versioning has specific meaning beyond code changes:

| Bump | Meaning | Example |
|------|---------|---------|
| **Major** (2.0.0) | Breaking change to `schema.input`, `schema.output`, or `env` requirements. Agents depending on previous schema will break. | Required env var added, output field renamed |
| **Minor** (1.1.0) | New scripts added, new optional input/output fields, new sub-skills. Backward compatible. | New `stream` script added alongside existing `complete` |
| **Patch** (1.0.1) | Bug fixes, documentation updates, performance improvements. No schema changes. | Fixed token counting in streaming mode |

### 7.3 Version Resolution

When a skill has dependencies, versions are resolved using a lockfile (`skill-lock.json`):

```json
{
  "resolved": {
    "openai/chat": "1.2.0",
    "slack/messages": "1.0.0",
    "vercel/deployments/deploy": "1.0.0"
  },
  "resolved_at": "2026-04-05T00:00:00Z",
  "registry": "https://api.dojo.dev"
}
```

Resolution rules:
1. Exact versions always win
2. Range specifiers resolve to the latest matching version
3. If two dependencies require incompatible versions of the same skill, the install fails with a conflict error
4. `optional` dependencies never cause conflict failures — they are skipped if unresolvable

### 7.4 Deprecation

Skills can be deprecated without removal:

```json
{
  "deprecated": true,
  "deprecated_message": "Use openai/chat-v2 instead (supports structured outputs)",
  "deprecated_replacement": "openai/chat-v2"
}
```

Deprecated skills remain discoverable but are ranked lower in search results. The registry returns a deprecation warning in API responses.

### 7.5 Yanking

A published version can be yanked (soft-deleted) if it contains a critical bug or security issue. Yanked versions:
- Cannot be installed by new consumers
- Continue to resolve for existing lockfiles (to avoid breaking deployments)
- Are hidden from search results
- Show a yank notice in `dojo info`

---

## 9. Skill Lifecycle

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Draft    │───▶│ Published │───▶│ Verified │───▶│  Trusted │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     local         registry        community       audited
     only          indexed         tested           + signed
```

### 8.1 Draft

- Exists only on the author's machine or in a git repo
- Not indexed in any registry
- Can be used locally with `dojo run ./path/to/skill.json`
- No validation requirements beyond valid JSON

### 8.2 Published

- Submitted to a registry via `dojo publish`
- Must pass schema validation (all required fields present, valid URI, valid semver)
- Indexed for search and resolution
- Immutable once published — a version string cannot be reused with different content
- Author can yank but not delete

### 8.3 Verified

Community-verified skills meet additional criteria:
- Test coverage: a `tests/` directory with passing test cases
- At least 3 successful runs reported by distinct agents
- All `env` variables documented with descriptions
- `schema.input` and `schema.output` fully specified
- No `inline` scripts exceed 500 lines (use `entry` files for long scripts)
- Reviewed by at least one community maintainer

### 8.4 Trusted

The highest trust level. Trusted skills are:
- Audited by ecosystem maintainers for security and correctness
- Cryptographically signed with a maintainer key
- Pinned in the registry — cannot be yanked without governance vote
- Eligible for inclusion in the "blessed" skill set (default installs)

Signature format:

```json
{
  "signature": {
    "signer": "dojo-core",
    "algorithm": "ed25519",
    "public_key": "base64...",
    "signature": "base64...",
    "signed_at": "2026-04-05T00:00:00Z",
    "covers": ["name", "version", "uri", "scripts", "schema"]
  }
}
```

---

## 10. Runtime Execution Model

How agents actually execute skill scripts.

### 9.1 Execution Environments

Scripts declare their runtime requirements:

```json
{
  "lang": "javascript",
  "runtime": "node>=18",
  "packages": ["ethers@6", "solc@0.8.28"]
}
```

The skill runner:
1. Checks that the required runtime is available
2. Installs packages into an isolated directory
3. Sets environment variables from `env` declarations
4. Executes the script with the skill's `schema.input` as arguments
5. Validates the output against `schema.output`
6. Returns the result to the agent

### 9.2 Execution Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Inline** | Script source is embedded in the manifest as `inline` | Short, self-contained scripts (<100 lines) |
| **Entry** | Script lives in a separate file referenced by `entry` | Larger scripts, multi-file projects |
| **Remote** | Script is fetched from a URL at runtime | Dynamic scripts, frequently updated logic |

### 9.3 Sandboxing

Scripts execute in a sandboxed environment with limited capabilities:

```
┌─────────────────────────────────────────┐
│  Sandbox                                │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │  Script      │  │  Environment     │  │
│  │  (isolated)  │  │  DATABASE_URL=...     │  │
│  │              │  │  OPENAI_API_KEY=sk-...   │  │
│  └──────┬───────┘  └────────┬─────────┘  │
│         │                   │            │
│  ┌──────▼───────────────────▼─────────┐  │
│  │  Allowed:                          │  │
│  │  • Network (outbound HTTP/WS)      │  │
│  │  • File read (skill directory)     │  │
│  │  • Temp file write (/tmp)          │  │
│  │  • Stdout/stderr                   │  │
│  │                                    │  │
│  │  Denied:                           │  │
│  │  • File write outside /tmp         │  │
│  │  • Process spawn (unless declared) │  │
│  │  • System calls                    │  │
│  │  • Inbound network                 │  │
│  └────────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 9.4 Capability Declarations

Scripts can declare additional capabilities they need beyond the default sandbox:

```json
{
  "capabilities": {
    "network": true,
    "filesystem": "read",
    "spawn": ["forge", "cast"],
    "max_runtime_seconds": 300,
    "max_memory_mb": 512
  }
}
```

The agent runtime can accept or reject these capability requests based on its security policy.

### 9.5 Script Communication

Scripts receive input and return output via stdin/stdout JSON:

```
stdin  → { "contract_source": "...", "connection_string": "postgresql://localhost/testdb" }
stdout → { "address": "0x...", "tx_hash": "0x...", "abi": [...] }
stderr → log messages (not parsed as output)
exit 0 → success
exit 1 → failure (stderr contains error message)
```

For languages that don't naturally support stdin/stdout JSON (like bash), the runner passes input as environment variables and captures stdout.

---

## 11. Composition Patterns

Skills compose in several ways. These patterns let agents build complex workflows from atomic skills.

### 11.1 Pipeline

Sequential execution where output of one skill feeds into the next:

```json
{
  "name": "build-deploy-notify",
  "type": "sub",
  "composition": {
    "type": "pipeline",
    "steps": [
      {
        "skill": "docker/images",
        "script": "build",
        "output_map": { "image_tag": "$.tag", "digest": "$.digest" }
      },
      {
        "skill": "vercel/deployments",
        "script": "deploy-production",
        "input_map": { "image": "$.previous.image_tag" },
        "output_map": { "url": "$.url", "deployment_id": "$.id" }
      },
      {
        "skill": "slack/messages",
        "script": "send",
        "input_map": { "text": "Deployed to $.previous.url" }
      }
    ]
  }
}
```

### 11.2 Fallback

Try skills in order until one succeeds:

```json
{
  "composition": {
    "type": "fallback",
    "attempts": [
      { "skill": "vercel/deployments", "script": "deploy-production" },
      { "skill": "aws/lambda", "script": "deploy" },
      { "skill": "docker/containers", "script": "run" }
    ]
  }
}
```

### 11.3 Fan-out

Execute multiple skills in parallel and merge results:

```json
{
  "composition": {
    "type": "fan-out",
    "parallel": [
      { "skill": "postgres/queries", "input": { "sql": "SELECT count(*) FROM users" }, "key": "users" },
      { "skill": "postgres/queries", "input": { "sql": "SELECT count(*) FROM orders" }, "key": "orders" },
      { "skill": "redis/cache", "input": { "key": "active_sessions" }, "key": "sessions" }
    ],
    "merge": "object"
  }
}
```

Result: `{ "users": { "rows": [{"count": 15420}] }, "orders": { "rows": [{"count": 8301}] }, "sessions": { "value": 342 } }`

### 11.4 Conditional

Branch based on input or previous output:

```json
{
  "composition": {
    "type": "conditional",
    "condition": "$.input.platform",
    "branches": {
      "vercel": { "skill": "vercel/deployments/deploy" },
      "docker": { "skill": "docker/images/build" },
      "aws": { "skill": "aws/lambda/deploy" },
      "default": { "skill": "vercel/deployments/deploy" }
    }
  }
}
```

### 11.5 Loop

Repeat a skill with different inputs:

```json
{
  "composition": {
    "type": "loop",
    "over": "$.input.channels",
    "skill": "slack/messages",
    "input_map": { "channel": "$.item", "text": "$.input.message" },
    "collect": "array"
  }
}
```

---

## 12. Security Model

### 12.1 Trust Levels

Every skill has a trust level that determines what it can do:

| Level | Network | File System | Secrets | Spawn | Auto-execute |
|-------|---------|-------------|---------|-------|-------------|
| Draft | Denied | Read-only | None | None | Never |
| Published | Outbound | Read-only | Declared | Declared | With confirmation |
| Verified | Outbound | Read + /tmp | Declared | Declared | With confirmation |
| Trusted | Outbound | Read + /tmp | Declared | Declared | Allowed |

### 11.2 Secret Management

Skills declare secrets they need but never contain them:

```json
{
  "env": {
    "DATABASE_URL": {
      "required": true,
      "secret": true,
      "description": "Database connection string"
    }
  }
}
```

Secrets are:
- Provided by the agent runtime, never stored in skill manifests
- Passed as environment variables at execution time
- Never logged, never included in error messages
- Scoped to the specific script execution (not shared between scripts)

### 11.3 Content Integrity

Published skills are content-addressed. The registry stores a hash of the manifest:

```json
{
  "integrity": {
    "algorithm": "sha256",
    "hash": "a1b2c3d4e5f6...",
    "covers": ["scripts", "schema", "depends"]
  }
}
```

On install, the CLI verifies the hash matches. Any tampering between publish and install is detected.

### 11.4 Permission Prompts

When an agent encounters a skill that requires elevated capabilities, it must present the requirements to the user before execution:

```
Skill: vercel/deployments/deploy
Requires:
  ✦ Network access (outbound HTTPS to Vercel API)
  ✦ Secret: VERCEL_TOKEN (deployment API token)
  ✦ Spawn: none
  ✦ Max runtime: 300s

Proceed? [y/N]
```

Trusted skills may skip this prompt based on agent configuration.

---

## 13. Capability Negotiation

Agents declare their capabilities when querying the registry. The registry uses this to filter and rank results.

### 12.1 Agent Context

```json
{
  "agent_context": {
    "capabilities": ["javascript", "python", "bash"],
    "runtimes": {
      "node": "20.11.0",
      "python": "3.12.0"
    },
    "has_env": ["OPENAI_API_KEY", "GITHUB_TOKEN"],
    "missing_env": [],
    "framework": "claude-code",
    "os": "linux",
    "arch": "x64",
    "sandbox": "docker",
    "max_runtime_seconds": 600,
    "trust_level": "verified"
  }
}
```

### 12.2 Compatibility Scoring

The registry scores each skill against the agent context:

```
score = relevance × compatibility

compatibility = (
  lang_supported     ? 1.0 : 0.0    ← hard requirement
  × runtime_version  ? 1.0 : 0.8    ← soft: older runtime may work
  × env_available    ? 1.0 : 0.6    ← soft: agent can prompt for env
  × trust_accepted   ? 1.0 : 0.5    ← soft: agent may accept lower trust
)
```

If `lang_supported` is false, the skill is excluded entirely. Other factors reduce the score but don't eliminate the skill.

### 12.3 Missing Capability Responses

When the best skill requires capabilities the agent doesn't have, the response includes remediation steps:

```json
{
  "recommendation": "vercel/deployments/deploy",
  "score": 0.72,
  "missing": {
    "env": ["DATABASE_URL"],
    "runtime": null,
    "packages": ["solc@0.8.28"],
    "capabilities": ["spawn:forge"]
  },
  "remediation": [
    "Set DATABASE_URL environment variable with database connection string",
    "Install solc: npm install -g solc",
    "Install forge: curl -L https://foundry.paradigm.xyz | bash"
  ]
}
```

---

## 14. Registries & Federation

### 13.1 Registry Types

| Type | Description | Example |
|------|-------------|---------|
| **Public** | Open registry, anyone can publish | `https://api.dojo.dev` |
| **Private** | Organization-internal, auth required | `https://skills.mycompany.com` |
| **Mirror** | Read-only copy of a public registry | `https://mirror.dojo.dev` |
| **Local** | File-system registry for development | `file:///home/user/.dojo` |

### 13.2 Registry Configuration

Agents and CLIs can be configured to query multiple registries:

```json
{
  "registries": [
    {
      "url": "https://skills.mycompany.com",
      "priority": 1,
      "auth": "bearer",
      "scopes": ["internal/*"]
    },
    {
      "url": "https://api.dojo.dev",
      "priority": 2,
      "scopes": ["*"]
    }
  ]
}
```

Resolution order:
1. Query all registries in parallel
2. Merge results, preferring higher-priority registries for duplicate URIs
3. Private registry skills shadow public ones when scopes overlap

### 13.3 Federation Protocol

Registries can federate — a registry can proxy requests to upstream registries:

```
Agent → Company Registry → Dojo Public
                         → Partner Registry
```

The company registry:
- Serves internal skills directly
- Proxies external skill requests to upstream registries
- Caches upstream responses
- Can block specific skills or ecosystems via deny lists
- Can enforce additional trust requirements on upstream skills

### 13.4 Mirroring

A mirror syncs all published skills from an upstream registry:

```bash
dojo mirror sync --from https://api.dojo.dev --to ./local-mirror/
```

Useful for:
- Air-gapped environments
- Compliance requirements (audit all skills before use)
- Performance (local access)

---

## 15. Skill Testing

### 14.1 Test Manifest

Skills can include a test configuration:

```json
{
  "tests": {
    "runner": "node --test",
    "fixtures": "./tests/fixtures/",
    "cases": [
      {
        "id": "query-success",
        "script": "deploy-contract",
        "input": {
          "sql": "SELECT * FROM users WHERE id = $1",
          "params": ["123"],
          "connection_string": "postgresql://localhost/testdb"
        },
        "expected_output": {
          "rows": { "type": "array", "minItems": 1 },
          "rowCount": { "type": "integer", "minimum": 1 }
        },
        "env_override": {
          "DATABASE_URL": "postgresql://localhost/testdb",
          "TEST_MODE": "true"
        },
        "timeout_seconds": 60
      },
      {
        "id": "query-missing-sql",
        "script": "deploy-contract",
        "input": { "connection_string": "postgresql://localhost/testdb" },
        "expected_error": "sql parameter is required",
        "exit_code": 1
      }
    ]
  }
}
```

### 14.2 Test Environments

Test cases can specify mock environments:

```json
{
  "test_env": {
    "type": "docker-compose",
    "setup": "docker compose -f tests/docker-compose.yml up -d",
    "teardown": "docker compose -f tests/docker-compose.yml down",
    "provides": {
      "DATABASE_URL": "postgresql://localhost/testdb",
      "PG_PORT": "5433"
    }
  }
}
```

### 14.3 Running Tests

```bash
dojo test ./skill.json                    # Run all test cases
dojo test ./skill.json --case query-success  # Run specific case
dojo test ./skill.json --env production   # Run with production env
```

### 14.4 Test Coverage Reporting

The runner tracks which scripts and schema paths are exercised:

```
Test Results: postgres/queries
  ✓ query-success (2.3s)
  ✓ query-missing-sql (0.1s)
  ✗ query-transaction (timeout after 60s)

Coverage:
  Scripts: 2/4 (50%)    compile ✓  deploy-contract ✓  query-transaction ✗  verify ✗
  Input fields: 3/5     sql ✓  params ✓  connection_string ✓
  Output fields: 2/5    rows ✓  rowCount ✓
```

---

## 16. Environment & Secrets

### 15.1 Environment Variable Hierarchy

Environment variables are resolved in order of precedence:

```
1. Script-level env override (highest)
2. Skill-level env defaults
3. Agent runtime environment
4. System environment
5. .env file in skill directory (lowest, development only)
```

### 15.2 Secret Storage

Agents must implement a secret store. The spec defines the interface but not the implementation:

```typescript
interface SecretStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
  delete(key: string): Promise<void>;
  has(key: string): Promise<boolean>;
}
```

Implementations may use:
- OS keychain (macOS Keychain, Linux libsecret, Windows Credential Manager)
- Environment variables
- Encrypted `.env` files
- Vault services (HashiCorp Vault, AWS Secrets Manager)
- Interactive prompts

### 15.3 Environment Validation

Before executing a script, the runner validates all required env vars are present:

```
Checking environment for postgres/queries#query:
  ✓ DATABASE_URL = postgresql://user:pass@host:5432/mydb
  ✓ QUERY_TIMEOUT = 30000 (default)
  ✗ DATABASE_URL — MISSING (required)

Error: Missing required variable: DATABASE_URL
  Set it with: export DATABASE_URL=postgresql://...
  Or use: dojo secrets set DATABASE_URL
```

---

## 17. Skill Packaging

### 16.1 Package Format

A skill package is a gzipped tarball containing:

```
skill-package.tar.gz
├── skill.json          # manifest (required)
├── scripts/            # script files (if using entry references)
│   ├── deploy.js
│   └── verify.sh
├── tests/              # test cases
│   ├── fixtures/
│   └── test.js
├── README.md           # human-readable documentation
└── LICENSE             # license file
```

### 16.2 Package Integrity

Packages are content-addressed using SHA-256. The registry stores:

```json
{
  "uri": "postgres/queries",
  "version": "1.2.0",
  "package": {
    "tarball": "https://registry.dojo.dev/packages/postgres-queries-1.0.0.tar.gz",
    "shasum": "a1b2c3d4e5f6...",
    "size": 4096,
    "file_count": 6
  }
}
```

### 16.3 Install Layout

Installed skills live in a predictable directory structure:

```
~/.dojo/
├── skills/
│   ├── openai/
│   │   ├── skill.json
│   │   └── chat/
│   │       ├── skill.json
│   │       ├── scripts/
│   │       │   ├── complete.js
│   │       │   └── stream.js
│   │       └── node_modules/  (auto-installed)
│   ├── postgres/
│   │   ├── skill.json
│   │   └── queries/
│   │       └── skill.json
│   └── docker/
│       └── ...
├── skill-lock.json
└── config.json
```

---

## 18. Agent Protocol (detailed)

### 17.1 Discovery Flow

The full flow from agent need to skill execution:

```
Agent                          Registry                      Runtime
  │                               │                             │
  │  POST /v1/agent/ask           │                             │
  │  { message, agent_context }   │                             │
  │──────────────────────────────▶│                             │
  │                               │  fuzzy search               │
  │                               │  capability filter           │
  │                               │  rank by score               │
  │  { recommendation, skill,    │                             │
  │    missing_env, alternatives }│                             │
  │◀──────────────────────────────│                             │
  │                               │                             │
  │  GET /v1/skills/{uri}         │                             │
  │──────────────────────────────▶│                             │
  │  { skill, ancestors, children}│                             │
  │◀──────────────────────────────│                             │
  │                               │                             │
  │  resolve dependencies         │                             │
  │  check env vars               │                             │
  │  prompt user for secrets      │                             │
  │                               │                             │
  │  execute(skill, script_id, input, env)                      │
  │─────────────────────────────────────────────────────────────▶│
  │                               │                   sandbox   │
  │                               │                   install pkgs
  │                               │                   run script │
  │  { output }                   │                             │
  │◀─────────────────────────────────────────────────────────────│
  │                               │                             │
  │  validate output vs schema    │                             │
  │  return result to user        │                             │
```

### 17.2 Batch Resolution

Agents can resolve multiple needs in a single request:

```json
{
  "needs": [
    { "message": "deploy my app to production", "tags": ["vercel"] },
    { "message": "send deployment notification", "tags": ["slack"] },
    { "message": "create github repo", "tags": ["github"] }
  ],
  "agent_context": { "capabilities": ["javascript", "bash"] }
}
```

Response includes a dependency-ordered execution plan:

```json
{
  "plan": [
    { "order": 1, "skill": "github/repos", "script": "create-repo" },
    { "order": 2, "skill": "vercel/deployments/deploy", "script": "deploy-production" },
    { "order": 3, "skill": "slack/messages", "script": "send" }
  ],
  "dependencies_resolved": true,
  "total_env_required": ["GITHUB_TOKEN", "VERCEL_TOKEN", "SLACK_TOKEN"]
}
```

### 17.3 Streaming Execution

For long-running scripts, the runtime supports streaming progress:

```
Event: progress
Data: { "stage": "compiling", "percent": 30 }

Event: progress
Data: { "stage": "deploying", "percent": 70, "tx_hash": "0x..." }

Event: progress
Data: { "stage": "confirming", "percent": 90, "confirmations": 2 }

Event: complete
Data: { "address": "0x7a3f...e2b1", "block": 18204831 }
```

### 17.4 Error Taxonomy

Standardized error types so agents can handle failures programmatically:

```json
{
  "error": {
    "type": "execution_failed",
    "code": "ENV_MISSING",
    "message": "Required environment variable DATABASE_URL is not set",
    "script": "deploy-contract",
    "recoverable": true,
    "remediation": "Set DATABASE_URL with your database connection string"
  }
}
```

Error types:

| Type | Description | Recoverable |
|------|-------------|-------------|
| `skill_not_found` | URI doesn't exist in registry | No |
| `version_conflict` | Dependencies require incompatible versions | No |
| `env_missing` | Required environment variable not set | Yes — prompt user |
| `runtime_unavailable` | Required runtime not installed | Yes — install it |
| `execution_failed` | Script threw an error | Depends on script |
| `timeout` | Script exceeded max runtime | Yes — increase timeout |
| `schema_mismatch` | Output doesn't match declared schema | No — skill bug |
| `permission_denied` | Capability not granted | Yes — grant capability |
| `network_error` | External service unreachable | Yes — retry |

---

## 19. Example Ecosystems

| Ecosystem | Type | Standards / Skills | Example Capabilities |
|-----------|------|-------------------|---------------------|
| `openai` | AI/ML | chat, embeddings, assistants, images | complete, stream, embed, fine-tune |
| `github` | DevOps | rest, graphql | repos/create, issues, pr/merge, actions |
| `aws` | Cloud | s3, lambda, iam, ec2, dynamodb | upload, invoke, deploy, configure |
| `vercel` | Hosting | deployments, domains, edge | deploy, preview, rollback, promote |
| `docker` | DevOps | containers, images, compose | run, build, push, up/down |
| `postgres` | Database | queries, migrations | query, explain, migrate, seed |
| `redis` | Cache | cache, pubsub, streams | get/set, publish, subscribe, queue |
| `slack` | Comms | messages, channels, workflows | send, create-channel, bot |
| `notion` | Productivity | pages, databases, blocks | create-page, query-db, update |
| `twilio` | Comms | sms, voice, verify | send-sms, call, verify-otp |
| `stripe` | Payments | payments, subscriptions, connect | charge, refund, webhook |
| `kubernetes` | Infra | pods, services, deployments | apply, scale, rollout |
| `ethereum` | Blockchain | erc20, x402, contracts | transfer, deploy, verify |
| `database` | Data | sql, nosql, vector, graph | query, embed, search |
| `cloudflare` | Edge | workers, r2, d1, kv | deploy-worker, upload |
| `figma` | Design | files, components | export, inspect, generate |
| `linear` | PM | issues, projects, cycles | create-issue, update, triage |

---

## 20. CLI Reference

```bash
# ─── Discovery ─────────────────────────────────────────
dojo search <query>                 # Full-text search
dojo search <query> --eco openai  # Filter by ecosystem
dojo search <query> --type sub      # Filter by type
dojo resolve <need>                 # Natural language resolution
dojo tree <ecosystem>               # View ecosystem tree
dojo tree <ecosystem> --depth 2     # Limit tree depth
dojo info <uri>                     # Detailed skill info
dojo info <uri> --json              # Machine-readable output

# ─── Knowledge ─────────────────────────────────────────
dojo learn <uri>                    # Read a node's full knowledge
dojo learn <uri> --section <id>     # Read a specific section
dojo learn <uri>#<section>          # Shorthand for section
dojo backlinks <uri>                # Show what references this node
dojo graph <uri>                    # Local knowledge graph
dojo graph <uri> --depth 3          # Expand graph radius
dojo alias <name>                   # Resolve an alias to a URI

# ─── Installation ──────────────────────────────────────
dojo install <uri>                  # Install a skill
dojo install <uri>@1.2.0            # Install specific version
dojo install <uri> --chain base     # Install with variant
dojo install <uri> --dry-run        # Preview without installing
dojo uninstall <uri>                # Remove an installed skill
dojo update <uri>                   # Update to latest compatible
dojo update --all                   # Update all installed skills
dojo list                           # List installed skills
dojo outdated                       # Show available updates

# ─── Execution ─────────────────────────────────────────
dojo run <uri> [script-id]          # Execute a skill's script
dojo run <uri> --env KEY=VALUE      # Pass environment variables
dojo run <uri> --input '{"k":"v"}'  # Pass JSON input
dojo run <uri> --dry-run            # Show what would execute

# ─── Authoring ─────────────────────────────────────────
dojo init [name]                    # Scaffold a new skill
dojo init [name] --type standard    # Scaffold specific type
dojo init [name] --parent <uri>     # Set parent
dojo validate <path>                # Validate manifest
dojo test <path>                    # Run skill tests
dojo test <path> --case <id>        # Run specific test case
dojo pack <path>                    # Create distributable tarball

# ─── Publishing ────────────────────────────────────────
dojo publish <path>                 # Publish to registry
dojo publish <path> --registry <url> # Publish to specific registry
dojo yank <uri>@<version>           # Soft-delete a version
dojo deprecate <uri> --message "..."  # Mark deprecated

# ─── Configuration ─────────────────────────────────────
dojo config set registry <url>      # Set default registry
dojo config set token <token>       # Set auth token
dojo config list                    # Show all config
dojo secrets set <key>              # Store a secret
dojo secrets list                   # List stored secret keys

# ─── Registry ─────────────────────────────────────────
dojo registry list                  # List configured registries
dojo registry add <url>             # Add a registry
dojo registry remove <url>          # Remove a registry
dojo mirror sync --from <url>       # Sync a mirror

# ─── Utilities ─────────────────────────────────────────
dojo link <from-uri> <to-uri>       # Create a cross-skill reference
dojo diff <uri>@v1 <uri>@v2        # Compare versions
dojo audit                          # Security audit installed skills
dojo completions <shell>            # Generate shell completions
```

---

## 21. Glossary

| Term | Definition |
|------|-----------|
| **Ecosystem** | Top-level domain (openai, docker, postgres, github, aws). No parent. |
| **Standard** | A protocol or convention within an ecosystem (rest, graphql, oauth2, openapi). |
| **Skill** | A concrete, executable capability (deploy, transfer, query). |
| **Sub-skill** | A specialized variant of a skill (deploy-base, query-postgres). |
| **URI** | Slash-separated path identifying a node: `ecosystem/standard/skill/sub`. Section addressing: `uri#section-id`. |
| **Manifest** | The `skill.json` file defining a node's metadata, content, scripts, and schema. |
| **Context** (field) | One-line description agents read first to determine relevance (≤200 chars). |
| **Context** (type) | An info-only node with no scripts. Used for documentation, guides, references, glossaries. |
| **Info** | Paragraph-length description of a node's capabilities and constraints. |
| **Body** | Long-form markdown content with wiki-links. The main knowledge payload for context nodes. |
| **Section** | An addressable sub-unit of a body, accessible via `uri#section-id`. |
| **Wiki-link** | A `[[uri]]` reference inside body/info text that creates a link in the knowledge graph. |
| **Backlink** | An incoming reference — node A backlinks to node B if A contains a wiki-link, depends, or related reference to B. |
| **Alias** | An alternative name for a node, used for discovery (e.g. "postgresql" → `postgres`, "gpt" → `openai`). |
| **Related** | A semantic relationship between nodes (similar, equivalent, prerequisite, etc.). |
| **Content type** | The kind of knowledge a context node carries: reference, guide, explainer, comparison, changelog, faq, glossary. |
| **Frontmatter** | Obsidian-style metadata: author, confidence, audience, prerequisites, reading time. |
| **Reading path** | A suggested order for consuming a node's sections and outgoing links. |
| **Knowledge graph** | The full network of nodes connected by wiki-links, backlinks, depends, and related edges. |
| **Script** | An executable code block within a skill (inline source or file reference). |
| **Schema** | Typed input/output contract using JSON Schema. |
| **Trigger** | Natural language phrase that should activate a skill. |
| **Depends** | Cross-node dependency reference. |
| **Registry** | Server that indexes, serves, and resolves nodes (both knowledge and skills). |
| **Resolve** | The process of matching an agent's need to the best node. |
| **Learn** | The process of reading a node's knowledge payload (body, sections, links). |
| **Composition** | Combining multiple skills into a workflow (pipeline, fallback, fan-out). |
| **Sandbox** | Isolated execution environment for running skill scripts. |
| **Trust level** | Lifecycle stage indicating how thoroughly a node has been vetted. |
| **Yank** | Soft-delete a published version without breaking existing installs. |
