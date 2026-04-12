---
name: functions
description: Provision and deploy Azure Function Apps with Azure CLI zip deployment or Azure Functions Core Tools publishing. Use when the workload is serverless and needs Azure-managed triggers, runtime config, and storage-backed execution.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# functions

Use this skill when the workload fits Azure Functions rather than a persistent web app or Kubernetes deployment.

## When to Use

- A Function App must be created against an existing storage account
- CI produced a zip artifact for Kudu deployment
- A local Function project should be published with Core Tools
- Runtime or build flags need to change through app settings

## Workflow

1. Create or verify the backing storage account.
2. Create the Function App with runtime, runtime version, and Functions version.
3. Deploy either via zip artifact or Core Tools depending on what the agent currently holds.
4. Update app settings and then validate with Azure Monitor.

## Examples

~~~bash
AZURE_FUNCTIONAPP_ACTION=app-create \
AZURE_RESOURCE_GROUP=rg-dojo-func \
AZURE_LOCATION=eastus \
AZURE_FUNCTIONAPP_NAME=dojo-func-prod \
AZURE_STORAGE_ACCOUNT=dojobuildstore \
./scripts/manage-functionapp.sh

AZURE_FUNCTIONAPP_ACTION=deploy-zip \
AZURE_RESOURCE_GROUP=rg-dojo-func \
AZURE_FUNCTIONAPP_NAME=dojo-func-prod \
AZURE_FUNCTIONAPP_ARTIFACT_PATH=./dist/functionapp.zip \
./scripts/manage-functionapp.sh
~~~

## Edge Cases

- Every Function App needs a backing storage account.
- `publish-core-tools` requires the `func` binary to be installed locally.
- `config-zip` can skip build steps unless remote build behavior is explicitly enabled.
