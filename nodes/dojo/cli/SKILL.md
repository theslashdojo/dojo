---
name: cli
description: >
  Use the dojo CLI to search, inspect, validate, scaffold, and publish nodes
  from the terminal. Use when performing dojo operations without writing code.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: dojo-tools
allowed-tools: Bash Read
---

# Dojo CLI

Terminal interface for the Dojo knowledge graph.

## When to Use

- Searching for nodes from the command line
- Inspecting node manifests without opening files
- Validating nodes before publishing
- Scaffolding new nodes quickly
- Publishing nodes to the registry

## Installation

```bash
npm install -g @dojo/cli
# or
npx @dojo/cli <command>
```

## Commands

### search — Find nodes

```bash
dojo search "deploy to vercel"
dojo search "auth" --type context
dojo search "kubernetes" --tag pods --limit 5
```

### inspect — View node details

```bash
dojo inspect github/repos
dojo inspect github/repos --field context
dojo inspect github/repos --field scripts --json
```

### validate — Check node quality

```bash
dojo validate nodes/github/repos/node.json
dojo validate nodes/github/ --recursive
dojo validate nodes/github/repos/node.json --schema-only
dojo validate nodes/github/repos/node.json --knowledge-only
```

### scaffold — Create new nodes

```bash
dojo scaffold ecosystem redis
dojo scaffold skill github/actions/workflows
dojo scaffold context kubernetes/troubleshooting
```

### publish — Release nodes

```bash
dojo publish nodes/github/repos/ --local
dojo publish nodes/github/repos/ --registry https://registry.dojo.dev
```

### learn — Read node knowledge

```bash
dojo learn github/repos
dojo learn github/repos#create
```

## Modes

- **Local mode** (default): Reads directly from `nodes/` directory
- **Online mode**: Queries `DOJO_URL` server when set and reachable

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DOJO_URL` | Server URL for online mode |
| `DOJO_ROOT` | Path to dojo repository root |
| `DOJO_AUTH_TOKEN` | Auth token for publish |
