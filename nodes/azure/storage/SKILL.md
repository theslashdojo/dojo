---
name: storage
description: Create Azure Storage accounts, create blob containers, and upload or download artifacts with Azure CLI. Use when deployments or workloads need object storage, artifact transfer, or a Function App backing store.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# storage

Use this skill when an agent needs a storage account, blob container, or artifact transfer path inside Azure.

## When to Use

- A workload needs a storage account before deployment
- CI produced a zip artifact that must be uploaded to blob storage
- A Function App depends on a backing storage account
- A downstream tool still needs a connection string instead of login-based auth

## Workflow

1. Create the storage account in the intended resource group and region.
2. Prefer login-based auth with RBAC when creating containers or moving blobs.
3. Upload the exact artifact you intend to deploy.
4. List blobs before cleanup or promotion so names are confirmed.
5. Hand off to Functions, App Service, or another consumer once the object exists.

## Examples

~~~bash
AZURE_STORAGE_ACTION=account-create \
AZURE_RESOURCE_GROUP=rg-dojo \
AZURE_LOCATION=eastus \
AZURE_STORAGE_ACCOUNT=dojobuildstore \
./scripts/manage-storage.sh

AZURE_STORAGE_ACTION=blob-upload \
AZURE_STORAGE_ACCOUNT=dojobuildstore \
AZURE_STORAGE_CONTAINER=artifacts \
AZURE_STORAGE_SOURCE=./dist/app.zip \
./scripts/manage-storage.sh
~~~

## Edge Cases

- Storage account names are globally unique and lower-case.
- `--auth-mode login` requires RBAC on the account; otherwise use a connection string.
- If blob name is omitted on upload, the script uses the source file basename.
