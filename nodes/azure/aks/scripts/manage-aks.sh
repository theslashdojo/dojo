#!/usr/bin/env bash
set -euo pipefail

require_az() {
  if ! command -v az >/dev/null 2>&1; then
    echo "Error: az CLI is required." >&2
    exit 127
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Error: $name is required for this action." >&2
    exit 64
  fi
}

set_subscription() {
  if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
    az account set --subscription "$AZURE_SUBSCRIPTION_ID" >/dev/null
  fi
}

require_az
action="${AZURE_AKS_ACTION:?AZURE_AKS_ACTION is required}"
set_subscription

case "$action" in
  cluster-create)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_LOCATION
    require_var AZURE_AKS_CLUSTER_NAME
    cmd=(az aks create --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_AKS_CLUSTER_NAME" --location "$AZURE_LOCATION" --node-count "${AZURE_AKS_NODE_COUNT:-3}" --node-vm-size "${AZURE_AKS_NODE_VM_SIZE:-Standard_D4s_v5}" --generate-ssh-keys)
    if [[ -n "${AZURE_AKS_KUBERNETES_VERSION:-}" ]]; then
      cmd+=(--kubernetes-version "$AZURE_AKS_KUBERNETES_VERSION")
    fi
    if [[ -n "${AZURE_AKS_ATTACH_ACR:-}" ]]; then
      cmd+=(--attach-acr "$AZURE_AKS_ATTACH_ACR")
    fi
    exec "${cmd[@]}"
    ;;
  get-credentials)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_AKS_CLUSTER_NAME
    cmd=(az aks get-credentials --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_AKS_CLUSTER_NAME")
    if [[ "${AZURE_AKS_OVERWRITE_EXISTING:-false}" == "true" ]]; then
      cmd+=(--overwrite-existing)
    fi
    exec "${cmd[@]}"
    ;;
  nodepool-add)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_AKS_CLUSTER_NAME
    require_var AZURE_AKS_NODEPOOL_NAME
    cmd=(az aks nodepool add --resource-group "$AZURE_RESOURCE_GROUP" --cluster-name "$AZURE_AKS_CLUSTER_NAME" --name "$AZURE_AKS_NODEPOOL_NAME" --node-count "${AZURE_AKS_NODE_COUNT:-1}" --node-vm-size "${AZURE_AKS_NODE_VM_SIZE:-Standard_D4s_v5}")
    exec "${cmd[@]}"
    ;;
  show)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_AKS_CLUSTER_NAME
    exec az aks show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_AKS_CLUSTER_NAME"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
