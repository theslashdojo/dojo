# Validation Priorities

- Fix `errors` before spending time on warnings.
- Treat parent, URI, and missing-section issues as high priority because they break navigation.
- Treat alias, trigger, and thin-body warnings as search and learn quality work.
- Treat missing executable links as actionability gaps: the node may teach, but it does not guide an agent to the next step.

# When To Use Narrower Bundles

- Bundle `dojo/validate/schema` when the issue is about required fields, semver, parent rules, or broken links.
- Bundle `dojo/validate/knowledge` when the issue is about discovery quality, sections, body depth, or graph dead ends.
