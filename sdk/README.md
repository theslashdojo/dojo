# slashdojo

`slashdojo` is the JavaScript SDK and CLI for the Dojo skill registry. It helps agents and apps discover skills, fetch node metadata, traverse the knowledge graph, and execute skill scripts from code or the terminal.

## Install

```bash
npm install slashdojo
```

Requirements:

- Node.js 18+
- npm

## Quick Start
### CLI
dojo — CLI for the Dojo skill registry

Discovery
  search <query>             Full-text search
  resolve <need>             Natural language resolution
  tree <ecosystem>           View ecosystem tree
  info <uri>                 Detailed skill info

Knowledge
  learn <uri>                Read a node's knowledge
  backlinks <uri>            Incoming references
  graph <uri>                Local knowledge graph
  alias <name>               Resolve an alias

Installation
  install <uri>[@version]    Install a skill
  uninstall <uri>            Remove an installed skill
  update <uri>|--all         Update skills
  list                       List installed skills
  outdated                   Show available updates

Execution
  run <uri> [script-id]      Run a skill's script

## When to use

| Goal | Operation | Why not the others |
|------|-----------|--------------------|
| Find a skill to do something | `search`, `resolve` | `learn` is for reading, not discovery. `tree` is for browsing ecosystems, not searching. |
| Understand a topic or how to do something | `learn` | `search` and `resolve` find nodes but don't return the knowledge excerpts. `tree` shows structure but not focused content. |
| Inspect graph context around a node | `graph`, `backlinks`, `alias` | `learn` returns the node's content but not its graph context. `search` and `resolve` return candidates but not the full graph. |
| Export a skill for another runtime | `bundle` | | The CLI's `install` is for installing into the Dojo runtime, not exporting. `bundle` gives the full package for external use. |

## Install

```bash
# CLI (recommended)
npm install -g slashdojo

# Install this skill locally
dojo install dojo/skill
```

## Workflow
1. **Discover** a node using `search` or `resolve` with a natural language need.
Text search
dojo search "deploy to vercel"

Filter by tag
dojo search "deploy" --tag vercel

Filter by type
dojo search "auth" --type context
dojo search "frontend" --type ecosystem

Limit results
dojo search "kubernetes" --limit 5

2. **Learn** about the node and its context with `learn`, `graph`, and `backlinks`.
3. **Explore** related nodes via `routes` in the response or `tree` for the ecosystem.
4. **Install** the skill with `install` or export it with `bundle` for use in another runtime.
## Operations reference

| Operation | Required | Optional | Returns |
|-----------|----------|----------|---------|
| `search` | `q` (string) | `type` (string), `tag` (string), `limit` (number) | List of matching nodes with relevance scores and excerpts |
| `resolve` | `need` (string) | `current_context` (string[]) | Best-matching node URI with reasons and relevance |
| `learn` | `uri` (string) | `field` (string), `json` (boolean) | Node content, optionally filtered to a specific field or as raw JSON |
| `graph` | `uri` (string) | `depth` (number) | Local graph context around the node, including neighbors and backlinks |
| `backlinks` | `uri` (string) |  | List of nodes linking to the given node, with excerpts and routes |
| `alias` | `name` (string) |  | URI that the alias resolves to, with graph context |
| `bundle` | `uri` (string) |  | A portable package of the node, including manifest, scripts, and dependencies |

## Examples
Agents can use this skill to discover capabilities, learn about topics, inspect graph context, and export bundles for external use. Here are some example interactions:
First, the agent searches for relevant n

```$ dojo search ui

452 results
 frontend [ecosystem] Frontend web development: React, CSS/Tailwind, state management, accessibility, bundling, and component testing```
Then inspect:

```$ dojo info frontend

frontend
 type ecosystem
 version 1.0.0
 context Frontend web development: React, CSS/Tailwind, state management, accessibility, bundling, and component testing
 tags frontend, react, css, tailwind, state-management, accessibility, bundling, testing, web, ui
 children frontend/accessibility, frontend/bundling, frontend/css, frontend/react, frontend/state, frontend/testing
 ```
Then learn:

$ dojo learn frontend/react

Output:

frontend/react
Build React components: hooks, context, server components, and common patterns

# React Components

React is a component-based UI library. Components are functions that return JSX describing what to render. React 19 adds server components, the `use()` hook, and Actions for form mutations.

## Components and JSX

tsx
interface ButtonProps {
  variant: "primary" | "secondary";
  children: React.ReactNode;
  onClick?: () => void;
}

Sections
  #components-jsx  Components and JSX
  #hooks  React hooks
  #context  React context
  #server-components  Server components
  #patterns  Common patterns

Reading path
  → frontend/react#components-jsx  Read Components and JSX before moving on
  → frontend/react#hooks  Read React hooks before moving on
  → frontend/react#context  Read React context before moving on

The agent can explore the tree, find new ecosystems and skills, and expand each section in the workflow with the → links, which are designed to be read as a path through the graph. The sections themselves can link out to other nodes in the graph for deeper dives on specific topics, and the body text can be as rich as needed to teach the concept without forcing the agent to jump to another node. This is the power of dojo: every node is a potential learning opportunity, and agents can navigate it in a way that feels natural for them to build knowledge and install skills incrementally without getting lost in disconnected docs or external tools.

## Package shape

This skill follows the [Agent Skills directory format](https://github.com/agentskills/agentskills):

```
skill/
├── SKILL.md                      # This file
├── node.json                     # Dojo manifest (graph semantics)
├── agents/openai.yaml            # Agent integration metadata
├── references/workflows.md       # Route decision tree + response field guide
├── scripts/use-dojo-skill.js     # CLI + in-process entry point
└── tests/use-dojo-skill.test.js  # Verification tests
```

By default the client tries `https://slashdojo.com` first and falls back to `http://localhost:3000`. You can override that with constructor options or `DOJO_REGISTRY`.

## Create a Client

```js
import Dojo, { createClient } from 'slashdojo';

const dojo = new Dojo({
  registry: 'https://slashdojo.com',
  token: process.env.DOJO_TOKEN,
  capabilities: ['shell', 'node', 'git']
});

const sameClient = createClient({
  registries: ['https://slashdojo.com', 'http://localhost:3000']
});
```

Constructor options:

- `registry`: preferred registry URL
- `registries`: ordered registry fallback list
- `token`: auth token for publishing
- `capabilities`: agent capability hints sent to `ask()`
- `envKeys`: override detected environment variable names

## Common API

```js
import { Dojo } from 'slashdojo';

const dojo = new Dojo();

const recommendation = await dojo.ask('deploy a contract to Base');
const { skill, ancestors, children } = await dojo.get('dojo/skill');
const results = await dojo.search('ethereum gas', { type: 'context', limit: 5 });
const tree = await dojo.tree('openai');
const deps = await dojo.resolve('ethereum/transactions/send');
const pipeline = await dojo.pipeline('docker/images', 'vercel/deployments');
```

Main methods:

- `need(description, opts)`: resolve a natural-language need to the best matching skill
- `ask(message)`: get a recommendation with missing env vars and alternatives
- `get(uri, version)`: fetch a node plus its ancestors and children
- `search(query, opts)`: search the registry with filters
- `tree(ecosystem, depth)`: fetch an ecosystem tree
- `run(skillOrUri, input, scriptId)`: execute the first or named script for a skill
- `checkRequirements(skill)`: inspect missing env vars and package requirements
- `publish(skill)`: publish a node manifest with auth
- `resolve(uri)`: flatten required dependencies
- `pipeline(...uris)`: compose multiple skills into an execution plan

## Environment Requirements

When a script declares required environment variables, `run()` checks both process env and your input object. These input shapes all satisfy an env key like `RPC_URL`:

- `input.RPC_URL`
- `input.rpc_url`
- `input.rpcUrl`

Publishing requires a token via `DOJO_TOKEN` or `new Dojo({ token })`.

## CLI

The package also ships a `dojo` CLI.

Run it without installing globally:

```bash
npx slashdojo --help
```

Or install it globally:

```bash
npm install -g slashdojo
dojo --help
```

Examples:

```bash
dojo resolve "deploy a contract to Base"
dojo search "ethereum gas" --type context
dojo info dojo/skill
dojo learn dojo --question "where is the bundle route"
dojo run <uri> --input '{"foo":"bar"}'
dojo install <uri>
```

Useful flags:

- `--json` for machine-readable output
- `--dry-run` to preview install or run behavior without side effects

## Development

```bash
cd sdk
npm install
npm test
```

## Links

- Registry: https://slashdojo.com
- Registry API root: https://slashdojo.com/v1
- Repository: https://github.com/theslashdojo/dojo/tree/main/sdk
