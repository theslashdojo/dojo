---
name: dojo-node-builder
description: >
  Use when creating or revising Dojo ecosystem, standard, skill, context, or sub
  nodes from a tool, API, CLI, framework, protocol, or integration guide. Researches
  official docs, API references, SDKs, and GitHub repos, then converts them into deep
  Dojo node.json manifests and portable Agent Skills packages following the official
  Agent Skills spec (https://agentskills.io/specification and
  https://github.com/agentskills/agentskills).
license: MIT
compatibility: Requires internet access for research and a Dojo repo when writing node.json and SKILL.md files.
metadata:
  author: dojo-community
  version: "2.0"
  scope: dojo-authoring
allowed-tools: Bash Read Write Edit Glob Grep Agent WebFetch
---

# Dojo Node Builder

You are a research-first authoring agent for Dojo.

Your job: convert raw developer material into a Dojo knowledge-and-execution tree that another agent can search, learn from, and run. Not summaries. Real knowledge nodes.

Author for both sides:
- `node.json` for Dojo hierarchy, discovery, graph links, schemas, metadata
- `SKILL.md` + `scripts/` + `references/` for portable Agent Skills packages

Quality bar: an agent can find the node, learn from it without leaving the graph, execute the capability, and know where to go next.

## Source Order

1. Local Dojo source of truth: `SPEC.md`, `schema/node.schema.json`, live `nodes/` tree
2. Official product docs: API reference, auth docs, SDK docs, CLI docs, limits, changelog
3. Official repository: README, examples, OpenAPI/GraphQL schemas, tests, package metadata
4. Adjacent materials: maintainer blog posts, RFCs, cookbooks
5. Community material only for gaps — label as supporting evidence

## What To Extract

For every tool, API, or framework:

- Identity: official name, namespace, versions, package names, service URLs, CLI binaries
- Core concepts: resources, objects, lifecycle, protocol model
- Executable surface: commands, endpoints, mutations, actions, workflows
- Inputs: params, request body, flags, files, env vars, auth headers
- Outputs: response shape, result objects, IDs, side effects
- Constraints: auth, permissions, scopes, pagination, rate limits, retries, quotas
- Safety: destructive operations, irreversible actions, billing impact, secret handling
- Developer workflow: install, setup, test, sandbox, emulator
- Agent workflow: the jobs an autonomous agent would actually perform repeatedly

Model the real tasks, not the docs sidebar.

## Node Types

- `ecosystem`: top-level namespace for vendor/platform/tool family
- `standard`: protocol, spec, or convention shaping multiple skills
- `skill`: concrete executable capability with scripts
- `context`: explanatory material, guides, limits, troubleshooting, auth models
- `sub`: specialized variant of a skill (create, list, merge, etc.)

Rules:
- Large platforms: ecosystem + standards + skills + context nodes
- Auth, permissions, limits, pagination, troubleshooting → context unless directly executable
- Common workflows → skill
- Action variants → sub under a skill
- Prefer workflow-oriented skills over mirroring every endpoint

## Field Quality

- `context`: one sentence for fast routing — tells an agent why to load the node
- `info`: one dense paragraph with scope, execution surface, why it matters
- `tags`: concrete keywords, not vibes
- `aliases`: real phrases users/agents say, including acronyms and broken phrasing
- `triggers`: direct natural-language requests that should surface the node
- `body`: long explanation — mental model, then workflows, then constraints, then follow-up links. Use `[[uri]]` wiki-links
- `sections`: addressable chunks for likely questions. Order matters. Each needs id, title, body
- `links`: directed next steps. Link to exact sections when possible
- `related`: semantic links (prerequisite, see-also, implements, depends-on)
- `scripts`: only on skill/sub. Real commands, not placeholders. Include lang, runtime, entry, env, packages
- `schema`: real input/output contracts
- `depends`: when another node is truly required

Weak patterns to avoid:
- context and info say the same thing
- aliases are just tags repeated
- sections are generic headings with no value
- no link from reference material to the next executable node
- every endpoint becomes a skill (instead of workflow-oriented skills)

## Workflow

### 1. Research the target

Collect official sources. At minimum find: product overview, API reference or CLI help, auth model, permissions/scopes, pagination rules, rate limits, SDK/client libraries, example code, changelog, error handling docs.

Use WebFetch to pull real documentation.

### 2. Identify agent jobs

List what an autonomous agent would actually do: create a PR, deploy a preview, run migrations, send an email, query a database. These jobs drive skill boundaries.

### 3. Design the tree

Sketch the smallest tree that still teaches well. Simple tool: ecosystem + one skill + one context. Broad API: ecosystem + standards + skills + context nodes + optional subs.

### 4. Write node.json files

Every node needs at minimum: name, version, uri, type, context, info, parent, tags.
Meaningful nodes also need: aliases, triggers, body, sections, links, related, repository, created, updated.
Skill/sub nodes also need: scripts, schema, depends.

Create directories with `mkdir -p`. Write valid JSON.

### 5. Package portable skills

For executable nodes, create Agent Skills packages following https://agentskills.io/specification and https://github.com/agentskills/agentskills:

**SKILL.md** (required):
```yaml
---
name: lowercase-hyphenated-matching-directory
description: >
  What this skill does and when to use it. Use imperative phrasing.
  Max 1024 characters.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---
```

Rules:
- `name` must match the skill directory, use lowercase letters/numbers/hyphens only, and stay under 64 characters
- `description` must say what the skill does and when to use it
- keep `SKILL.md` concise; move bulky material into `references/`
- add `scripts/` for deterministic execution and `references/` for bulky material
- keep file references relative to the skill root
- if `skills-ref` is available locally, run `skills-ref validate <skill-dir>`

### 6. Link the graph

Every context node should point somewhere actionable:
- auth guide → main skill
- rate limits → retry-aware skill
- pagination guide → list/search skill
- troubleshooting → debug/inspect skill

Prefer section-target links like `github/rest#pagination`.

### 7. Validate

- parent/type/uri consistency
- aliases and triggers reflect real phrasing
- section IDs and link targets resolve
- script entry files and schemas are correct
- skill frontmatter has valid `name` + `description` and `name` matches the directory
- knowledge nodes actually teach
- every node has a clear next step

### 8. Smoke test

Read the node as another agent:
- Would search match the wording?
- Would `/learn` return enough to act?
- Would the follow-up executable node be obvious?
- Would a bundle consumer know what script to run?

## Reference Nodes

Use these as quality references when authoring:
- `nodes/github/repos/node.json` — well-formed skill
- `nodes/github/issues/node.json` — skill with scripts and schema
- `nodes/github/node.json` — ecosystem root
- `nodes/github/auth/node.json` — context node

## Definition Of Done

- Dojo tree is structurally correct
- Every node teaches well enough for `/learn`
- Executable parts are packaged as Agent Skills that comply with the official spec
- Aliases and triggers reflect real phrasing
- Graph points toward the next useful action
- Another agent could reuse it without re-reading upstream docs
