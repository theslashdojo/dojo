---
name: dojo-node-grinder
description: >
  Use when you need to batch-create missing Dojo ecosystem nodes, expand the
  knowledge graph at scale, or run continuous autonomous node generation. Drives
  codex exec --sandbox danger-full-access in a loop over grind-targets.json,
  auto-committing each completed ecosystem after validation. Supports priority
  filtering, retry logic, parallel execution, and loop mode.
license: MIT
compatibility: Requires Codex CLI, jq, git, and internet access for research.
metadata:
  author: dojo-community
  version: "2.0"
  scope: dojo-automation
allowed-tools: Bash Read Write Edit Glob Grep Agent WebFetch
---

# Dojo Node Grinder

Automation agent that generates Dojo knowledge nodes at scale.

Uses `dojo-grind.sh` and `grind-targets.json` to drive autonomous node creation via `codex exec --sandbox danger-full-access`. Each target ecosystem gets its own Codex session that researches docs, builds nodes, and creates Agent Skills packages.

## Architecture

```
scripts/
├── dojo-grind.sh          # Main automation script
├── grind-targets.json     # Target manifest — what to build
├── grind-status.json      # Build status tracking
└── grind-logs/            # Per-ecosystem run logs

skills/
├── dojo-node-builder/     # Research+authoring skill Codex uses
│   └── SKILL.md
└── dojo-node-grinder/     # This automation skill
    ├── SKILL.md
    ├── scripts/
    │   └── add-target.sh
    └── references/
        └── target-schema.md
```

## Running

```bash
# Run all targets
./scripts/dojo-grind.sh

# Priority 1 only (git, anthropic, mcp)
./scripts/dojo-grind.sh --priority 1

# Single ecosystem
./scripts/dojo-grind.sh --ecosystem git

# Skip already-built, keep going until done
./scripts/dojo-grind.sh --loop --priority 2

# Check what's built vs pending
./scripts/dojo-grind.sh --status

# Dry run — see prompts without running
./scripts/dojo-grind.sh --dry-run

# Parallel execution (2 at a time)
./scripts/dojo-grind.sh --continue --parallel 2

# Don't auto-commit
./scripts/dojo-grind.sh --no-commit
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--priority N` | all | Only targets with priority <= N |
| `--ecosystem NAME` | all | Only the named ecosystem |
| `--dry-run` | false | Print prompts, don't run |
| `--continue` | false | Skip ecosystems that already validate cleanly |
| `--loop` | false | Keep running passes until all targets built |
| `--parallel N` | 1 | Run N ecosystems concurrently |
| `--no-commit` | false | Don't auto-commit after each ecosystem |
| `--retries N` | 2 | Max retries per ecosystem on failure |
| `--status` | — | Show build status and exit |

## Adding Targets

Edit `scripts/grind-targets.json` directly or use the helper:

```bash
./skills/dojo-node-grinder/scripts/add-target.sh \
  --ecosystem "newapi" \
  --priority 2 \
  --reason "Agents need this for X" \
  --nodes "newapi:ecosystem newapi/auth:context newapi/query:skill"
```

## Priority Levels

| Priority | Meaning | Examples |
|----------|---------|---------|
| 1 | Critical — used in nearly every agent session | git, anthropic, mcp |
| 2 | Common — used multiple times per week | node, python, typescript, nextjs, prisma, tailwind |
| 3 | Valuable — domain-specific | supabase, linear, kubernetes, cloudflare, firebase |

## The Loop

```
grind-targets.json → dojo-grind.sh → codex exec → node.json + SKILL.md → git commit
                           ↑                                                      |
                           └── retry on failure ─ validate tree + skills ────────┘
```

1. Script reads targets from manifest
2. For each: builds a prompt and pipes it to `codex exec --sandbox danger-full-access`
3. Codex researches official docs, creates node.json files and SKILL.md packages
4. Script validates the expected tree, SKILL.md frontmatter, and referenced script entries, then retries on failure
5. Auto-commits each completed ecosystem
6. In loop mode, re-runs until all targets are built

## Quality Contract

Every node must be:
- **Discoverable**: context + aliases + triggers surface it in search
- **Teachable**: info + body + sections let agents learn without upstream docs
- **Executable**: scripts + schema + env vars let agents run the capability
- **Connected**: links + related + depends wire it into the graph
- **Portable**: SKILL.md follows the official Agent Skills spec for cross-platform use

Skeleton nodes are failures. Placeholder scripts are failures.

## Workflow

### Expand the graph

1. Check status: `./scripts/dojo-grind.sh --status`
2. Identify gaps: what tools/APIs are agents using that Dojo doesn't cover?
3. Add targets to `grind-targets.json`
4. Run: `./scripts/dojo-grind.sh --continue`
5. Review logs in `scripts/grind-logs/`
6. Re-run failures: `./scripts/dojo-grind.sh --ecosystem <name>`

### Full autonomous run

```bash
./scripts/dojo-grind.sh --loop --continue
```

This keeps running passes until every target is built, retrying failures.

## Edge Cases

- **Codex CLI not installed**: exits with error
- **Rate limits**: reduce parallelism with `--parallel 1`
- **Failed ecosystem**: retries up to `--retries` times, check log
- **Partial creation**: `--continue` checks the full expected tree and rebuilds if anything is missing or invalid
- **Invalid JSON or SKILL.md**: warns during validation, retries
