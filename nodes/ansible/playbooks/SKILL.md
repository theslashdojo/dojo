---
name: playbooks
description: >
  Validate and execute Ansible playbooks with ansible-playbook. Use when the work
  is reusable, ordered, reviewable in Git, or needs tags, handlers, limits, and
  vault-backed secrets.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Playbooks

Use this skill when a task deserves durable YAML instead of a one-liner.

## When to Use

- Repeatable configuration or rollout workflows
- Multi-step changes with handlers or task ordering
- Changes that must be reviewed or staged through Git and CI
- Runs that need tags, limits, check mode, diff mode, or Vault integration

## Workflow

1. Validate targeting with `[[ansible/inventory]]`.
2. Install any required collections from `[[ansible/collections]]`.
3. Run `--syntax-check`.
4. Inspect `--list-tasks` or `--list-tags` if scope is unclear.
5. Run with `-C -D` on a limited host subset first.
6. Execute the full run only after the preview looks correct.

## Commands

```bash
ansible-playbook -i inventory site.yml
ansible-playbook -i inventory site.yml --syntax-check
ansible-playbook -i inventory site.yml --list-tasks --list-tags
ansible-playbook -i inventory site.yml -C -D
ansible-playbook -i inventory site.yml -l canary -t packages
ansible-playbook -i inventory site.yml --vault-id prod@prompt
```

## Examples

```bash
# Syntax check only
ANSIBLE_PLAYBOOK_FILE=site.yml \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
ANSIBLE_SYNTAX_CHECK=true \
./scripts/run-playbook.sh

# Canary preview with diff
ANSIBLE_PLAYBOOK_FILE=site.yml \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
ANSIBLE_LIMIT=app1.example.com \
ANSIBLE_PLAYBOOK_CHECK=true \
ANSIBLE_PLAYBOOK_DIFF=true \
./scripts/run-playbook.sh
```

## Edge Cases

- `--check` is useful but not every module implements preview behavior perfectly.
- `--diff` can expose secrets if templates render them; combine it with caution and `no_log`.
- If a task keeps failing late in a large run, use `--start-at-task` or tags to isolate it.
