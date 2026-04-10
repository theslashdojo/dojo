---
name: schema
description: Run schema-focused Dojo validation for required fields, semver, URI nesting, parent rules, and reference integrity. Use when a manifest should be checked structurally without the broader knowledge heuristics.
license: MIT
compatibility: Requires Node.js 18+ and access to the surrounding Dojo node tree.
metadata:
  canonical-uri: dojo/validate/schema
  category: dojo
---

# Schema Validation

Use `scripts/schema-only.js` when the job is to catch broken manifest structure quickly.

## Examples

- Basic check:
  `node scripts/schema-only.js /abs/path/to/node.json`
- With explicit tree root:
  `node scripts/schema-only.js /abs/path/to/node.json --root-dir /abs/path/to/nodes`
- Structured input:
  `node scripts/schema-only.js --json '{"path":"./nodes/dojo/skill/node.json","rootDir":"./nodes"}'`

## Notes

- This validator checks required fields, parent rules, and reference integrity.
- It does not enforce the broader knowledge-quality heuristics from `dojo/validate/knowledge`.
- Output is JSON so agents can pass failures directly into review or CI systems.
