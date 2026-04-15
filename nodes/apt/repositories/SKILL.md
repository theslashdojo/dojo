---
name: repositories
description: >
  Add, inspect, or remove APT repositories using deb822 source files, explicit
  Signed-By keyrings, and controlled update behavior. Use when a package requires an
  external repository or when old apt-key instructions need modernization.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: apt-repositories
---

# repositories

Use this skill for repository lifecycle management on Debian and Ubuntu hosts.

## When to use

- adding a vendor package repository
- replacing deprecated `apt-key` instructions
- converting one-line sources to deb822
- removing a third-party repository cleanly
- auditing source files under `/etc/apt/sources.list.d`

## Workflow

The script entrypoint is `./scripts/manage-repository.sh`.

### Add a deb822 source

```bash
APT_REPO_ACTION=add-deb822 \
APT_REPO_NAME=hashicorp \
APT_REPO_URI=https://apt.releases.hashicorp.com \
APT_REPO_SUITES=noble \
APT_REPO_COMPONENTS=main \
APT_REPO_KEY_URL=https://apt.releases.hashicorp.com/gpg \
./scripts/manage-repository.sh
```

### Add a legacy one-line source

```bash
APT_REPO_ACTION=add-line \
APT_REPO_NAME=vendor \
APT_REPO_URI=https://packages.vendor.example/apt \
APT_REPO_SUITES=stable \
APT_REPO_COMPONENTS=main \
APT_REPO_KEY_URL=https://packages.vendor.example/key.asc \
./scripts/manage-repository.sh
```

### List or remove repositories

```bash
APT_REPO_ACTION=list ./scripts/manage-repository.sh

APT_REPO_ACTION=remove \
APT_REPO_NAME=vendor \
APT_REMOVE_KEY=true \
APT_REMOVE_PIN=true \
./scripts/manage-repository.sh
```

## Environment

- `APT_REPO_ACTION`: `add-deb822`, `add-line`, `remove`, `list`
- `APT_REPO_NAME`: basename for source and keyring files
- `APT_REPO_URI`: repository base URL
- `APT_REPO_SUITES`: suites or pockets
- `APT_REPO_COMPONENTS`: components, default `main`
- `APT_REPO_KEY_URL`: optional key download URL
- `APT_REPO_SIGNED_BY`: explicit keyring path override
- `APT_ENABLE_SOURCE=true`: also add `deb-src`
- `APT_NO_UPDATE=true`: skip `apt-get update`

## Edge cases

- If you add a third-party repository, consider [[apt/pinning]] immediately.
- The script does not infer trust; if `Signed-By` is omitted, it warns rather than silently inventing a policy.
- Use [[apt/repositories/ppa]] when instructions are specifically for Launchpad PPAs.
