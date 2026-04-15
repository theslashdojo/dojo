---
name: upgrade
description: >
  Refresh package indexes, apply upgrades, and clean caches with apt-get. Use when
  patching a Debian or Ubuntu host, preparing a base image, or investigating packages
  that are being kept back.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: apt-upgrades
---

# upgrade

Use this skill for system-wide package maintenance.

## When to use

- patching a host
- refreshing metadata before install work
- running a full dependency-changing upgrade
- cleaning package caches in images
- investigating kept-back packages on Ubuntu

## Workflow

The script entrypoint is `./scripts/upgrade-system.sh`.

```bash
# refresh indexes only
APT_UPGRADE_ACTION=update ./scripts/upgrade-system.sh

# preview an upgrade
APT_UPGRADE_ACTION=preview ./scripts/upgrade-system.sh

# routine upgrade
APT_UPGRADE_ACTION=upgrade ./scripts/upgrade-system.sh

# dependency-changing upgrade
APT_UPGRADE_ACTION=dist-upgrade ./scripts/upgrade-system.sh
```

## Cleanup actions

```bash
APT_UPGRADE_ACTION=autoremove ./scripts/upgrade-system.sh
APT_UPGRADE_ACTION=autoclean ./scripts/upgrade-system.sh
APT_UPGRADE_ACTION=clean ./scripts/upgrade-system.sh
```

## Important behavior

- `upgrade` will not remove installed packages.
- `dist-upgrade` can remove packages if the solver needs to.
- `preview` runs `apt-get -s upgrade`.
- Ubuntu phased updates can cause packages to be kept back temporarily; inspect with [[apt/search]] before forcing them.

## Edge cases

- For automation-sensitive systems, simulate first with `APT_SIMULATE=true` or `preview`.
- `distclean` is mainly for finalizing images, not everyday host maintenance.
