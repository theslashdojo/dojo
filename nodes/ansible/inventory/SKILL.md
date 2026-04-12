---
name: inventory
description: >
  Inspect and validate Ansible inventory with ansible-inventory. Use when you need
  to confirm which hosts, groups, and variables Ansible will resolve before running
  ad-hoc commands or playbooks.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Inventory

Use this skill to answer the question "what will Ansible actually target?"

## When to Use

- Before any production run that depends on host groups or limits
- When inventory is dynamic, merged from multiple sources, or backed by plugins
- When a host is unexpectedly missing, present, or carrying the wrong variables
- When you need a graph or machine-readable dump of the resolved inventory

## Workflow

1. Pick the exact inventory source: file, directory, or plugin source.
2. Run `--graph` to confirm group membership and hierarchy.
3. Run `--list` for the resolved machine-readable inventory.
4. Run `--host <name>` if one host has suspicious variables or connection settings.
5. Only then move on to `[[ansible/ad-hoc]]` or `[[ansible/playbooks]]`.

## Commands

```bash
ansible-inventory -i inventory.yml --graph
ansible-inventory -i inventory.yml --list
ansible-inventory -i inventory.yml --host app1.example.com
```

## Examples

```bash
# Graph groups and children
ANSIBLE_INVENTORY_ACTION=graph \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
./scripts/inspect-inventory.sh

# Inspect one host in YAML form
ANSIBLE_INVENTORY_ACTION=host \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
ANSIBLE_INVENTORY_FORMAT=yaml \
ANSIBLE_HOST_NAME=app1.example.com \
./scripts/inspect-inventory.sh
```

## Edge Cases

- Multiple inventory sources can merge in surprising ways; inspect the resolved output, not just raw files.
- Directory inventory often pulls in `group_vars/` and `host_vars/` beside the main source.
- Use separate sources for `dev`, `staging`, and `prod` to reduce blast radius.
- `localhost,` with a trailing comma is an inline inventory source, not a typo.
