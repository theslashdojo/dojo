---
name: search
description: >
  Search the APT cache, show package metadata, inspect dependencies, and explain
  candidate selection. Use when you need package facts without changing system state.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: apt-inspection
---

# search

Use this skill for read-only package inspection.

## When to use

- finding the right package name
- checking available versions
- understanding reverse dependencies before removal
- validating pinning and source precedence
- confirming whether a package is phased or held back

## Workflow

The script entrypoint is `./scripts/inspect-package.sh`.

```bash
# search by package name
APT_SEARCH_ACTION=search APT_QUERY=postgres ./scripts/inspect-package.sh

# show metadata
APT_SEARCH_ACTION=show APT_PACKAGE=nginx ./scripts/inspect-package.sh

# show candidate selection
APT_SEARCH_ACTION=policy APT_PACKAGE=openssl ./scripts/inspect-package.sh
```

## Common actions

- `search`: full-text cache search
- `show`: full package record
- `depends`: forward dependencies
- `rdepends`: reverse dependencies
- `policy`: candidate version and source priorities
- `madison`: compact version table
- `unmet`: unresolved dependencies in the cache
- `list-installed`: installed package inventory via `dpkg-query`

## Examples

```bash
APT_SEARCH_ACTION=depends APT_PACKAGE=nginx ./scripts/inspect-package.sh
APT_SEARCH_ACTION=rdepends APT_PACKAGE=libssl3 APT_RECURSE=true ./scripts/inspect-package.sh
APT_SEARCH_ACTION=madison APT_PACKAGE=docker-ce ./scripts/inspect-package.sh
```

## Edge cases

- Answers are only as current as the last successful `apt-get update`.
- `policy` with no package shows source priorities instead of a package-specific table.
- Use `APT_NAMES_ONLY=true` when `search` should not match descriptions.
