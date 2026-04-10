---
name: knowledge
description: Run knowledge-focused Dojo validation for aliases, triggers, body depth, sections, links, and actionability. Use when a node is structurally valid but still weak for search, learn, or agent follow-through.
license: MIT
compatibility: Requires Node.js 18+ and access to the surrounding Dojo node tree.
metadata:
  canonical-uri: dojo/validate/knowledge
  category: dojo
---

# Knowledge Validation

Use `scripts/knowledge-only.js` when the node already parses but still needs stronger discovery and reading quality.

## Examples

- Default thresholds:
  `node scripts/knowledge-only.js /abs/path/to/node.json`
- Stricter thresholds:
  `node scripts/knowledge-only.js /abs/path/to/node.json --min-sections 2 --min-body-length 240`
- Structured input:
  `node scripts/knowledge-only.js --json '{"path":"./nodes/dojo/skill/node.json","requireExecutableLink":true}'`

## Notes

- This validator checks aliases, triggers, body depth, sections, graph links, and next-step actionability.
- Use it after schema validation, not instead of it.
- Output is JSON with warnings and summary stats so agents can explain what feels thin.
