---
name: registry
description: Publish a Dojo manifest to a registry with bearer auth. Use when validation and local rehearsal are already complete and the node is ready for the authenticated POST step.
license: MIT
compatibility: Requires Bash, curl, a Dojo registry URL, and DOJO_TOKEN for live publish.
metadata:
  canonical-uri: dojo/publish/registry
  category: dojo
---

# Registry Publish

Use `scripts/publish-registry.sh` for the final authenticated publish step.

## Example

- Dry-run:
  `bash scripts/publish-registry.sh /workspaces/Contracts/dojo/nodes/dojo/skill/node.json https://slashdojo.com true`
- Live publish:
  `DOJO_TOKEN=... bash scripts/publish-registry.sh /workspaces/Contracts/dojo/nodes/dojo/skill/node.json https://registry.example false`

## Notes

- The request body is the manifest itself.
- Secrets belong in environment variables, not in `node.json`.
- Re-run search, learn, and bundle checks after a successful publish.
