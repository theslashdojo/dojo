# Dojo Node Tree

This directory is the live package-style Dojo node tree. It is intentionally richer than the sample ecosystems so contributors can copy a tree that is aligned with [`SPEC.md`](https://github.com/theslashdojo/dojo/blob/main/SPEC.md), not just a minimal manifest.

It demonstrates:

- all five node types: `ecosystem`, `standard`, `skill`, `context`, and `sub`
- long-form knowledge fields: `body`, `sections`, `links`, `related`, and aliases
- section-target links such as `dojo/spec#manifest-core`
- `entry`-based scripts for larger nodes, with tests for the JavaScript and bash workflow skills
- release metadata like `repository`, `created`, and `updated`

## Layout

- `node.json` is the ecosystem root
- `api/` shows a `standard` with a child `skill`
- `authoring/`, `skill/`, `api/query/`, `validate/`, and `publish/` all ship portable Agent Skills packages with `SKILL.md`, agent metadata, scripts, and focused references where useful
- `validate/` shows a `skill` with both `sub` children and a `context` child
- `publish/` shows a release workflow split into `sub` variants that are also individually bundleable
- `scripts/` folders demonstrate package-style `entry` files
- `tests/` folders demonstrate the "verified" lifecycle expectations from the spec

## Why `node.json`?

`SPEC.md` defines `node.json` as the atomic manifest. The runtime loads this `nodes/dojo` tree as the canonical Dojo content and still accepts legacy `skill.json` manifests from `examples/` so the sample ecosystems keep working during the transition.

## Local Checks

Run the node tests directly with Node's built-in runner:

```bash
node --test \
  /workspaces/Contracts/dojo/nodes/dojo/api/query/tests/query-registry.test.js \
  /workspaces/Contracts/dojo/nodes/dojo/skill/tests/use-dojo-skill.test.js \
  /workspaces/Contracts/dojo/nodes/dojo/validate/tests/validate-node.test.js \
  /workspaces/Contracts/dojo/nodes/dojo/validate/schema/tests/schema-only.test.js \
  /workspaces/Contracts/dojo/nodes/dojo/validate/knowledge/tests/knowledge-only.test.js \
  /workspaces/Contracts/dojo/nodes/dojo/publish/tests/publish-scripts.test.js
```

These tests cover the entry-based authoring, query, validation, and publish workflow scripts that justify the `verified` lifecycle status on the live Dojo skills.
