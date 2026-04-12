---
name: key-vault
description: Create Azure Key Vaults, grant vault-scoped RBAC, and manage secret values with the Azure CLI. Use when automation needs a durable secret boundary for Azure-hosted workloads or deployment pipelines.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# key-vault

Use this skill when secrets should live in Azure rather than in source control, plaintext app settings, or CI logs.

## When to Use

- A new Key Vault must be created for an environment
- An identity needs `Key Vault Secrets Officer` at vault scope
- A secret must be set, rotated, retrieved, deleted, or purged
- App Service or Functions configuration should reference a real secret store

## Workflow

1. Create the vault with RBAC authorization enabled.
2. Grant the minimum role needed to the executing identity or runtime identity.
3. Set or rotate the secret value.
4. Read plaintext values only when a downstream tool truly requires them.
5. Delete or purge secrets deliberately during cleanup.

## Examples

~~~bash
AZURE_KEY_VAULT_ACTION=vault-create \
AZURE_RESOURCE_GROUP=rg-dojo-shared \
AZURE_LOCATION=eastus \
AZURE_KEY_VAULT_NAME=kv-dojo-prod \
./scripts/manage-key-vault.sh

AZURE_KEY_VAULT_ACTION=secret-set \
AZURE_KEY_VAULT_NAME=kv-dojo-prod \
AZURE_SECRET_NAME=OPENAI_API_KEY \
AZURE_SECRET_VALUE="$OPENAI_API_KEY" \
./scripts/manage-key-vault.sh
~~~

## Edge Cases

- RBAC must be in place before `secret-set` or `secret-show` succeeds.
- `secret-show` emits plaintext by design; avoid piping it into logs.
- `secret-delete` is soft delete; `secret-purge` is permanent.
