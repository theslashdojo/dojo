---
name: aks
description: Create AKS clusters, fetch kubeconfig, and manage node pools with the Azure CLI. Use when Azure should provide the managed Kubernetes control plane and the next step is generic Kubernetes operations.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# aks

Use this skill when the workload requires managed Kubernetes rather than App Service or Functions.

## When to Use

- A new AKS cluster must be created in Azure
- `kubectl` needs credentials for an existing AKS cluster
- A specialized node pool must be added for a workload class
- The agent needs to inspect cluster-level Azure state before switching to Kubernetes tooling

## Workflow

1. Confirm the resource group, region, and cluster naming plan.
2. Create the cluster with node count and VM size sized for the expected workload.
3. Fetch credentials into kubeconfig and switch to kubectl or Helm.
4. Add node pools only when the scheduling model needs real isolation.

## Examples

~~~bash
AZURE_AKS_ACTION=cluster-create \
AZURE_RESOURCE_GROUP=rg-dojo-aks \
AZURE_LOCATION=eastus \
AZURE_AKS_CLUSTER_NAME=dojo-aks-prod \
./scripts/manage-aks.sh

AZURE_AKS_ACTION=get-credentials \
AZURE_RESOURCE_GROUP=rg-dojo-aks \
AZURE_AKS_CLUSTER_NAME=dojo-aks-prod \
AZURE_AKS_OVERWRITE_EXISTING=true \
./scripts/manage-aks.sh
~~~

## Edge Cases

- `get-credentials` mutates kubeconfig on the local machine.
- Treat the AKS-managed node resource group as provider-owned state.
- After credentials are fetched, most work belongs in generic Kubernetes skills, not Azure CLI.
