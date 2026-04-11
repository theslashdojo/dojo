# Grind Target Schema

Each target in `grind-targets.json` tells the grinder what ecosystem to build.

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ecosystem` | string | yes | Top-level ecosystem name (lowercase, hyphens ok) |
| `priority` | integer | yes | 1 = critical, 2 = common, 3 = useful |
| `reason` | string | yes | Why agents need this — drives the prompt context |
| `tree` | array | yes | Sketch of nodes to create |

## Tree Entry

Each item in the `tree` array:

| Field | Type | Description |
|-------|------|-------------|
| `uri` | string | Full Dojo URI path (e.g., `git/commit`) |
| `type` | string | One of: `ecosystem`, `standard`, `skill`, `context`, `sub` |

## Type Rules

- `ecosystem` — one per target, the root node
- `standard` — protocols or specs (e.g., REST, GraphQL, OAuth2)
- `skill` — executable capabilities (e.g., commit, deploy, query)
- `context` — knowledge nodes (e.g., auth, rate-limits, troubleshooting)
- `sub` — variants of a skill (e.g., create, list, merge under pulls)

## Nesting Rules

- `ecosystem` has no parent (null)
- `standard` nests under ecosystem
- `skill` nests under ecosystem or standard
- `context` nests under anything except sub
- `sub` nests only under skill

## Example

```json
{
  "ecosystem": "git",
  "priority": 1,
  "reason": "Every code agent uses git constantly",
  "tree": [
    { "uri": "git", "type": "ecosystem" },
    { "uri": "git/commit", "type": "skill" },
    { "uri": "git/branch", "type": "skill" },
    { "uri": "git/hooks", "type": "context" }
  ]
}
```

## What Makes a Good Reason

The `reason` field drives the prompt. Good reasons:
- State what agent jobs depend on this tool
- Are specific: "agents commit code after every edit" not "git is useful"
- Mention frequency: "used in nearly every session" vs "used occasionally"

## Priority Guide

| Priority | When to use |
|----------|-------------|
| 1 | Agent can't function without this (git, AI APIs, MCP) |
| 2 | Agent uses this multiple times per week (npm, python, testing) |
| 3 | Agent uses this for specific domains (k8s, terraform, linear) |
