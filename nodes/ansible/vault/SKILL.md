---
name: vault
description: >
  Manage encrypted Ansible secrets with ansible-vault. Use when you need to encrypt
  vars files, rekey secret material, or supply vault identities safely during playbook runs.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Vault

Use this skill to keep secrets encrypted in Git while still feeding them into playbooks safely.

## When to Use

- Encrypting `group_vars`, `host_vars`, or dedicated secret files
- Rekeying secrets between environments or after rotation events
- Generating encrypted inline values with `encrypt_string`
- Running playbooks with one or more vault identities

## Workflow

1. Decide whether the secret belongs in a file or an inline encrypted value.
2. Encrypt or rekey it with `ansible-vault`.
3. Store vault password files outside Git with restrictive permissions.
4. Execute playbooks with `--vault-id` or `--vault-password-file`.
5. Apply `no_log: true` to tasks that may surface secret values.

## Commands

```bash
ansible-vault encrypt group_vars/prod/secrets.yml --vault-id prod@prompt
ansible-vault view group_vars/prod/secrets.yml --vault-id prod@~/.ansible/prod.vault
ansible-vault rekey group_vars/prod/secrets.yml --vault-id prod@prompt --new-vault-id prod@~/.ansible/new-prod.vault
ansible-vault encrypt_string --vault-id prod@prompt --name db_password supersecret
```

## Examples

```bash
# Encrypt a file
ANSIBLE_VAULT_ACTION=encrypt \
ANSIBLE_VAULT_TARGET=group_vars/prod/secrets.yml \
ANSIBLE_VAULT_ID=prod@prompt \
./scripts/manage-vault.sh

# Encrypt a single inline variable
ANSIBLE_VAULT_ACTION=encrypt-string \
ANSIBLE_VAULT_ID=prod@prompt \
ANSIBLE_VAULT_NAME=db_password \
ANSIBLE_VAULT_STRING=supersecret \
./scripts/manage-vault.sh
```

## Edge Cases

- `create` and `edit` are interactive and require a terminal.
- Rekeying across environments is safer when vault IDs are explicit.
- Secrets can still leak through stdout, diff output, or shell history if tasks are careless.
