# Release Flow

1. Validate the manifest and fix structural issues first.
2. Rehearse the read-side routes locally, including `search`, `skills`, `learn`, and `bundle`.
3. Confirm the version string is new for the content being released.
4. Publish with bearer auth.
5. Re-check discovery and learnability against the live registry.

# Failure Handling

- If the dry run looks wrong, stop and fix the manifest before rehearsing.
- If local rehearsal fails, do not publish.
- If publish succeeds but read-side checks regress, treat the release as incomplete until discovery and learn flows are healthy.
