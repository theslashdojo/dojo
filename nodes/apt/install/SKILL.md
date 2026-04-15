---
name: install
description: >
  Install, reinstall, remove, or purge Debian and Ubuntu packages with stable
  apt-get automation patterns. Use when a task needs to change package state on a host
  and interactive apt behavior would be risky or noisy.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: apt-package-management
---

# install

Use this skill for deterministic package state changes on Debian-family systems.

## When to use

- provisioning host dependencies
- installing tools in CI or cloud-init
- reinstalling a damaged package
- removing or purging packages during image hardening
- selecting a specific package version or target release

## Workflow

### 1. Inspect first when precision matters

Use [[apt/search]] if you are choosing between versions, releases, or repositories.

### 2. Run the package action

The script entrypoint is `./scripts/manage-package.sh`.

```bash
APT_ACTION=install \
APT_PACKAGES="curl jq" \
APT_SKIP_UPDATE=false \
DEBIAN_FRONTEND=noninteractive \
./scripts/manage-package.sh
```

### 3. Use minimal dependency expansion when needed

```bash
APT_ACTION=install \
APT_PACKAGES="ripgrep fd-find" \
APT_NO_RECOMMENDS=true \
./scripts/manage-package.sh
```

### 4. Remove or purge intentionally

```bash
APT_ACTION=remove APT_PACKAGES="nginx" ./scripts/manage-package.sh
APT_ACTION=purge APT_PACKAGES="nginx" ./scripts/manage-package.sh
```

## Environment

- `APT_ACTION`: `install`, `reinstall`, `remove`, or `purge`
- `APT_PACKAGES`: space-separated package specs
- `APT_TARGET_RELEASE`: optional `-t` release such as `noble-backports`
- `APT_NO_RECOMMENDS=true`: minimize install set
- `APT_SKIP_UPDATE=true`: skip metadata refresh for install and reinstall
- `APT_SIMULATE=true`: dry-run the action
- `DEBIAN_FRONTEND=noninteractive`: automation-safe prompt behavior

## Examples

```bash
# reinstall a package
APT_ACTION=reinstall APT_PACKAGES="ca-certificates" ./scripts/manage-package.sh

# exact version
APT_ACTION=install APT_PACKAGES="openssl=3.0.2-0ubuntu1.20" ./scripts/manage-package.sh

# target release
APT_ACTION=install APT_PACKAGES="neovim" APT_TARGET_RELEASE="noble-backports" ./scripts/manage-package.sh
```

## Edge cases

- `remove` keeps package-managed configuration files; `purge` deletes them.
- Exact versions and target releases can downgrade dependencies if policy allows it.
- Local `.deb` files should generally be followed by [[apt/repair]] if dependency resolution fails.
