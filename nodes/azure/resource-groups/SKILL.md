---
name: resource-groups
description: Create, inspect, retag, and delete Azure resource groups with the Azure CLI. Use when an Azure environment needs a safe lifecycle boundary before provisioning workload resources or tearing them down.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# resource-groups

Use this skill when Azure work starts with environment boundaries rather than individual resources.

## When to Use

- A new Azure environment needs a resource group before other resources are created
- You need to inspect ownership tags or location before provisioning more services
- A temporary environment must be torn down in one destructive operation
- Cleanup logic depends on stable tags such as `owner=agent` or `env=preview`

## Workflow

1. Confirm the active subscription with `az account show`.
2. Create the resource group with tags if it does not exist.
3. Re-read the group with `az group show` before provisioning child resources.
4. Merge or replace tags when ownership or cost metadata changes.
5. Delete the group only after confirming the exact subscription and name.

## Examples

~~~bash
AZURE_RESOURCE_GROUP_ACTION=create \
AZURE_RESOURCE_GROUP_NAME=rg-dojo \
AZURE_LOCATION=eastus \
AZURE_RESOURCE_GROUP_TAGS="owner=agent env=dev" \
./scripts/manage-resource-group.sh

AZURE_RESOURCE_GROUP_ACTION=update-tags \
AZURE_RESOURCE_GROUP_NAME=rg-dojo \
AZURE_RESOURCE_GROUP_TAGS="owner=platform costcenter=eng" \
./scripts/manage-resource-group.sh
~~~

## Edge Cases

- `az group delete` is recursive and destructive; check subscription context first.
- Use `AZURE_DELETE_WAIT=true` when subsequent steps require confirmed teardown.
- Merge mode updates individual tags; replace mode rewrites the full tag set.
