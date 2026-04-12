---
name: collections
description: >
  Install, verify, list, and scaffold Ansible collections with ansible-galaxy. Use
  when playbooks depend on external modules or when you need reproducible collection state.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Collections

Use this skill to manage the collection layer on the Ansible control node.

## When to Use

- Before running playbooks that reference non-core modules
- When bootstrapping a fresh runner or CI environment
- When pinning collection versions with `requirements.yml`
- When verifying installed content or scaffolding a new collection

## Workflow

1. Check the project's `requirements.yml` or the fully qualified collection names in playbooks.
2. Install or update the required collections.
3. List or verify installed content if the environment has drifted.
4. Only then execute playbooks or ad-hoc commands that depend on that content.

## Commands

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install -r collections/requirements.yml
ansible-galaxy collection list
ansible-galaxy collection verify community.general
ansible-galaxy collection init acme.platform
```

## Examples

```bash
# Install from requirements
ANSIBLE_GALAXY_ACTION=install \
ANSIBLE_GALAXY_REQUIREMENTS_FILE=collections/requirements.yml \
./scripts/manage-collections.sh

# Verify one collection
ANSIBLE_GALAXY_ACTION=verify \
ANSIBLE_COLLECTION_NAME=community.general \
./scripts/manage-collections.sh
```

## Edge Cases

- Long-lived control nodes drift; list and verify before assuming modules exist.
- Pin versions in `requirements.yml` for CI and production reproducibility.
- Missing collections often surface as module resolution errors far away from the real cause.
