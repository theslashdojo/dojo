---
name: validate
description: Validate Dojo manifests for schema, tree integrity, aliases, links, sections, and agent-learn quality. Use when authoring or reviewing a Dojo node before local smoke tests or publishing.
license: MIT
compatibility: Requires Node.js 18+ and access to the surrounding Dojo node tree.
metadata:
  canonical-uri: dojo/validate
  category: dojo
---

# Validate Dojo Nodes

Use `scripts/validate-node.js` when you need one command that checks both structural rules and knowledge quality.

## Fast path

- Run the root validator first:
  `node scripts/validate-node.js /abs/path/to/node.json --strict true --require-knowledge true`
- Bundle `dojo/validate/schema` when you only need hard schema checks.
- Bundle `dojo/validate/knowledge` when you only need discovery and learn-quality checks.

## Workflow

1. Validate after every meaningful manifest edit, not only before release.
2. Use `--strict true` before final smoke tests or publishing.
3. Fix structural errors first, then address knowledge warnings.
4. After validation passes, move to local rehearsal and bundle checks.

## Examples

- Basic validation:
  `node scripts/validate-node.js /workspaces/Contracts/dojo/nodes/dojo/skill/node.json`
- Structured input:
  `node scripts/validate-node.js --json '{"path":"./nodes/dojo/skill/node.json","strict":true,"requireKnowledge":true}'`

## Edge cases

- `--root-dir` should point at the directory containing `nodes/` or `examples/` when the manifest is outside the default tree.
- Validation warnings are intentionally non-fatal so agents can surface improvement work without blocking every draft.
- The output is JSON so another agent can gate CI or compose more targeted follow-up steps.

Read `references/checks.md` for the practical meaning of common errors and warnings.
