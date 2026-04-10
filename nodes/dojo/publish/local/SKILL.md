---
name: local
description: Rehearse a Dojo release against a registry by checking search, skill, learn, and bundle routes before publishing. Use when a manifest should prove read-side health locally or in staging.
license: MIT
compatibility: Requires Bash, curl, and access to a Dojo registry URL; defaults to https://slashdojo.com.
metadata:
  canonical-uri: dojo/publish/local
  category: dojo
---

# Local Publish Rehearsal

Use `scripts/rehearse-release.sh` to verify that a changed node is visible and usable before live publish.

## Example

`bash scripts/rehearse-release.sh /workspaces/Contracts/dojo/nodes/dojo/skill/node.json dojo/skill dojo https://slashdojo.com`

## Notes

- The script checks search, tree, skill, learn, and bundle routes.
- The output is JSON so release tooling can fail fast on route regressions.
- Use this after validation and before the live registry publish step.
