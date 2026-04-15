# Dojo

Dojo is a universal knowledge layer for AI agent skills and knowledge — discoverable, composable, hierarchical units of capability. Any agent, any framework, any LLM can query the registry and get back executable skills and knowledge with full context.

The knowledge layer is what makes Dojo more than a package manager. Every node in the tree can carry rich, linked, wiki-like content with `body`, `sections`, `links`, `aliases`, and `related` fields. Context nodes are how agents learn. Skill nodes are how agents act. The same graph serves both.

## Design Principles

1. **Hierarchical** — Nodes form trees: ecosystem → standard → skill → sub-skill
2. **Self-describing** — Every node carries its own context, docs, and schema
3. **Composable** — Skills reference and depend on other skills
4. **Agent-native** — Designed for LLM agents to discover and execute, not just humans
5. **Wiki-like** — Rich info fields, linked references, living documentation
6. **Executable** — Scripts are first-class: agents run them, not just read them

## Node Types

Every node is defined by a `node.json` manifest. Five types form the hierarchy:

| Type | Purpose | Has Scripts |
|------|---------|:-----------:|
| `ecosystem` | Broad domain root (e.g. openai, docker, aws) | No |
| `standard` | Protocol, spec, or convention (e.g. rest, oauth2) | No |
| `skill` | Concrete executable capability (e.g. deploy, query) | Yes |
| `context` | Wiki-like knowledge node — guides, references, glossaries | No |
| `sub` | Specialized variant of a skill (e.g. deploy-preview) | Yes |

Nesting is flexible. A standard can live under a skill. A context node can live anywhere. A sub must have a skill parent.

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

## Knowledge Layer

Every node can carry a `body` field — long-form markdown that goes beyond the one-line `context` and paragraph-length `info`. Bodies support:

- Full markdown with headings, code blocks, tables
- Wiki-links via `[[uri]]` syntax linking to other nodes
- Inline references via `{{uri}}` embedding another node's context
- Addressable `sections` — individually fetchable via `uri#section-id`

The registry builds a backlink graph automatically. Every node knows what links to it, not just what it links from. This is the Obsidian model applied to agent knowledge.

Nodes also carry `aliases` for discovery, `links` with context annotations, and `related` for semantic relationships (`similar`, `prerequisite`, `alternative`, `implements`, etc.).

## Repository Layout

```
dojo/
├── nodes/          Canonical Dojo node tree (node.json manifests)
├── examples/       Sample ecosystems (legacy skill.json format)
├── schema/         JSON Schemas for node.json validation
├── server/         Express registry server
├── sdk/            JavaScript SDK for discovery, retrieval, execution
├── web/            Vite + React browser UI
├── skills/         Bundled agent-facing skill packages
├── tests/          Server and integration tests
└── docker/         Dockerfile and compose setup
```

## Quick Start

### Requirements

- Node.js 18+
- npm

Dependencies are managed per subdirectory.

### Run the Registry Server

```bash
cd server && npm install && npm run dev
```

Starts on `http://localhost:3000`, loading manifests from `nodes/` and `examples/`.

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| `SKILLS_DIR` | `nodes/,examples/` | Comma-separated manifest directories |
| `NODES_DIR` | — | Fallback alias for `SKILLS_DIR` |

### Run the Web UI

```bash
cd web && npm install && npm run dev
```

Or build and serve through the registry:

```bash
cd web && npm install && npm run build
cd ../server && npm install && npm start
```

### Use Docker

```bash
docker compose -f docker/docker-compose.yaml up --build
```

## API

The registry server exposes discovery, knowledge, and agent endpoints under `/v1`:

### Discovery

| Endpoint | Description |
|----------|-------------|
| `GET /v1` | Registry metadata and route map |
| `GET /v1/resolve?need=...` | Natural-language capability resolution |
| `GET /v1/search?q=...` | Full-text and filtered search |
| `GET /v1/discover?need=...` | Grouped `learn_first` + `then_do` recommendations |
| `GET /v1/skills/*` | Node retrieval with ancestry, children, and knowledge |
| `GET /v1/tree/:ecosystem` | Nested ecosystem tree |

### Knowledge

| Endpoint | Description |
|----------|-------------|
| `GET /v1/learn/*` | Knowledge payload with body, sections, reading path |
| `GET /v1/graph/*?depth=N` | Local graph traversal (links, backlinks, depends) |
| `GET /v1/backlinks/*` | Inbound references to a node |
| `GET /v1/alias/:alias` | Resolve an alias to its canonical node |
| `GET /v1/bundle/*` | Portable node package export |

### Agent Flows

| Endpoint | Description |
|----------|-------------|
| `POST /v1/agent/ask` | Executable recommendation (do-path) |
| `POST /v1/agent/learn` | Answer-first knowledge flow (learn-path) |
| `POST /v1/skills` | Publish a node (requires `Authorization` header) |

### Examples

```bash
# Registry info
curl https://slashdojo.com/v1

# Find a skill by need
curl 'https://slashdojo.com/v1/resolve?need=send%20eth'

# Learn about a topic
curl 'https://slashdojo.com/v1/learn/dojo?question=where%20is%20the%20bundle%20route'

# Export a portable bundle
curl 'https://slashdojo.com/v1/bundle/dojo/skill'

# Agent ask flow
curl -X POST https://slashdojo.com/v1/agent/ask \
  -H 'Content-Type: application/json' \
  -d '{"message": "deploy a contract to Base"}'
```

## SDK

The JavaScript SDK (`sdk/src/index.js`) wraps the registry API for agent workflows:

```js
import { Dojo } from 'slashdojo';

const dojo = new Dojo({ registry: 'https://slashdojo.com' });

// Find a skill by natural language
const skill = await dojo.need('send an ethereum transaction');

// Ask for a recommendation with full context
const rec = await dojo.ask('deploy a contract to Base');

// Get a node by URI
const { skill: node, ancestors, children } = await dojo.get('dojo/skill');

// Search
const results = await dojo.search('ethereum gas', { type: 'context' });

// Get an ecosystem tree
const tree = await dojo.tree('openai');

// Execute a skill's script
const output = await dojo.run(skill, { chain: 'base', contract_source: '...' });

// Resolve all dependencies
const deps = await dojo.resolve('ethereum/transactions/send');

// Compose a pipeline
const pipeline = await dojo.pipeline('docker/images', 'vercel/deployments');
```

Install with `npm install slashdojo`.

```bash
cd sdk && npm install && npm test
```

## Manifest Format

The atomic unit is `node.json`. Required fields:

```jsonc
{
  "name": "deploy",                    // unique within parent
  "version": "1.2.0",                  // semver
  "uri": "vercel/deployments/deploy",  // full path in tree
  "type": "skill",                     // ecosystem | standard | skill | context | sub
  "context": "Deploy a web app to Vercel",  // one-liner for agent discovery
  "info": "Handles project detection, build config, and deployment...",
  "tags": ["vercel", "deploy", "hosting"]
}
```

Optional fields extend the manifest with hierarchy (`parent`, `sub`, `skills`), discovery (`triggers`, `aliases`), execution (`scripts`, `schema`), knowledge (`body`, `sections`, `links`, `related`, `content_type`, `frontmatter`), dependencies (`depends`), and metadata (`author`, `license`, `repository`, `more`).

Full schema: [`schema/node.schema.json`](schema/node.schema.json)

## Authoring Nodes

1. Start from the [spec](https://github.com/theslashdojo/dojo/blob/main/SPEC.md) for the full format reference
2. Use [`nodes/dojo`](nodes/dojo) as the reference tree — it demonstrates all five node types, knowledge-rich manifests, bundled skill packages, and script-backed workflows
3. Validate against [`schema/node.schema.json`](schema/node.schema.json)
4. For executable skills, include `SKILL.md`, `agents/`, `scripts/`, and `tests/` as needed

## Testing

```bash
# Server unit tests
node --test tests/server-app.test.js

# Integration tests (requires running registry)
REGISTRY_URL=http://localhost:3000 node --test tests/integration.test.js

# SDK tests
cd sdk && npm test

# Dojo node workflow tests
cd nodes/dojo && node --test validate/tests/validate-node.test.js
```

## Spec

The full specification lives at [`SPEC.md`](https://github.com/theslashdojo/dojo/blob/main/SPEC.md). It defines:

- Section 1: Overview and design principles
- Section 2: `node.json` manifest schema and field reference
- Section 3: Type hierarchy, nesting rules, and URI format
- Section 4: Knowledge layer — body, sections, wiki-links, backlinks, aliases, related nodes, content types, frontmatter, and agent knowledge protocol
- Section 5+: API routes, agent flows, publishing, and trust model

## License

MIT
