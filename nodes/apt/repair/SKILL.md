---
name: repair
description: >
  Repair broken APT and dpkg state with diagnostics, fix-broken installs, pending
  configuration recovery, and lock inspection. Use when package work was interrupted or
  when apt reports broken dependencies or lock errors.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: apt-repair
---

# repair

Use this skill after a package operation has already failed.

## When to use

- interrupted installs or upgrades
- half-configured packages
- unmet dependency errors
- `Could not get lock` failures
- local `.deb` installs that left the host inconsistent

## Workflow

The script entrypoint is `./scripts/repair-apt.sh`.

### 1. Diagnose

```bash
APT_REPAIR_ACTION=check ./scripts/repair-apt.sh
```

### 2. Finish pending configuration if needed

```bash
APT_REPAIR_ACTION=configure-pending ./scripts/repair-apt.sh
```

### 3. Let APT repair the dependency graph

```bash
APT_REPAIR_ACTION=fix-broken ./scripts/repair-apt.sh
```

### 4. Inspect locks instead of deleting them

```bash
APT_REPAIR_ACTION=locks ./scripts/repair-apt.sh
```

### 5. Retry specific packages with missing downloads

```bash
APT_REPAIR_ACTION=fix-missing \
APT_PACKAGES="docker-ce docker-ce-cli" \
./scripts/repair-apt.sh
```

## Edge cases

- `fix-broken` is solver-driven. Read the proposed changes before confirming.
- Lock files are symptoms; the owning process is the real decision point.
- Debian notes that severely corrupted dependency graphs can still require manual package removal with `dpkg`.
