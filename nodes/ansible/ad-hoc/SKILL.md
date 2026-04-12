---
name: ad-hoc
description: >
  Execute one-off Ansible modules with the ansible CLI. Use when you need a quick
  change, connectivity check, or fact query that does not yet justify a full playbook.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Ad-Hoc

Use this skill for fast, single-module execution against an inventory pattern.

## When to Use

- Connectivity checks with `ansible.builtin.ping`
- One-off package, service, file, or user changes
- Fact gathering with `ansible.builtin.setup`
- Emergency or investigative commands that are not worth promoting to a playbook yet

## Workflow

1. Confirm the target hosts with `[[ansible/inventory]]`.
2. Prefer a purpose-built module over `shell`.
3. Add `--limit` for canaries or partial rollout.
4. Add `--check` when the module supports preview safely.
5. If the command repeats, move it into `[[ansible/playbooks]]`.

## Commands

```bash
ansible all -i inventory.yml -m ansible.builtin.ping
ansible web -i inventory.yml -b -m ansible.builtin.package -a 'name=nginx state=present'
ansible web -i inventory.yml -b -m ansible.builtin.service -a 'name=nginx state=restarted'
ansible all -i inventory.yml -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

## Examples

```bash
# Ping a group
ANSIBLE_PATTERN=web \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
./scripts/run-ad-hoc.sh

# Package install with become
ANSIBLE_PATTERN=web \
ANSIBLE_INVENTORY_SOURCE=inventory/prod.yml \
ANSIBLE_MODULE=ansible.builtin.package \
ANSIBLE_MODULE_ARGS='name=nginx state=present' \
ANSIBLE_BECOME=true \
./scripts/run-ad-hoc.sh
```

## Edge Cases

- `command` does not use a shell; use `shell` only when pipes or redirects are required.
- Ad-hoc commands are intentionally poor for review and reuse; convert recurring work into playbooks.
- SSH user, key, and sudo failures often look like module failures until you isolate transport first.
