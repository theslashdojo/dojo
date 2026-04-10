---
name: publish
description: Publish Dojo nodes with version discipline. Use when preparing or releasing a manifest and you need dry-run previews, local rehearsal guidance, or live registry publish commands.
license: MIT
compatibility: Requires Bash, curl, Node.js, and a Dojo registry URL. Live publish also requires DOJO_TOKEN.
metadata:
  canonical-uri: dojo/publish
  category: dojo
---

# Publish Dojo Nodes

Use `scripts/publish-node.sh` for the top-level release entrypoint.

## Fast path

- Dry-run the release:
  `bash scripts/publish-node.sh /abs/path/to/node.json https://slashdojo.com true`
- Bundle `dojo/publish/local` to rehearse route health against a registry.
- Bundle `dojo/publish/registry` to perform the authenticated POST step.

## Workflow

1. Validate the node first.
2. Rehearse search, skill, learn, and bundle routes locally.
3. Keep version strings immutable.
4. Publish only after local read-side checks pass.

## Examples

- Dry-run preview:
  `bash scripts/publish-node.sh /workspaces/Contracts/dojo/nodes/dojo/skill/node.json https://slashdojo.com true`
- Live publish:
  `DOJO_TOKEN=... bash scripts/publish-node.sh /workspaces/Contracts/dojo/nodes/dojo/skill/node.json https://registry.example false`

## Edge cases

- A `201` only means the registry accepted the manifest. It does not prove the node is discoverable or readable.
- Keep auth in environment variables, not in the manifest.
- The script emits JSON so other automation can gate on it.

Read `references/release-flow.md` for the release sequence and post-publish checks.
