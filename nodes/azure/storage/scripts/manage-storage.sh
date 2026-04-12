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

storage_auth_args() {
  STORAGE_AUTH_ARGS=()
  if [[ -n "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
    STORAGE_AUTH_ARGS+=(--connection-string "$AZURE_STORAGE_CONNECTION_STRING")
    return
  fi
  require_var AZURE_STORAGE_ACCOUNT
  STORAGE_AUTH_ARGS+=(--account-name "$AZURE_STORAGE_ACCOUNT" --auth-mode "${AZURE_STORAGE_AUTH_MODE:-login}")
}

require_az
action="${AZURE_STORAGE_ACTION:?AZURE_STORAGE_ACTION is required}"
set_subscription

case "$action" in
  account-create)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_LOCATION
    require_var AZURE_STORAGE_ACCOUNT
    exec az storage account create \
      --name "$AZURE_STORAGE_ACCOUNT" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --location "$AZURE_LOCATION" \
      --sku "${AZURE_STORAGE_SKU:-Standard_LRS}" \
      --kind StorageV2
    ;;
  container-create)
    require_var AZURE_STORAGE_CONTAINER
    storage_auth_args
    exec az storage container create --name "$AZURE_STORAGE_CONTAINER" "${STORAGE_AUTH_ARGS[@]}"
    ;;
  blob-upload)
    require_var AZURE_STORAGE_CONTAINER
    require_var AZURE_STORAGE_SOURCE
    storage_auth_args
    blob_name="${AZURE_STORAGE_BLOB_NAME:-$(basename "$AZURE_STORAGE_SOURCE")}"
    exec az storage blob upload \
      --container-name "$AZURE_STORAGE_CONTAINER" \
      --name "$blob_name" \
      --file "$AZURE_STORAGE_SOURCE" \
      --overwrite true \
      "${STORAGE_AUTH_ARGS[@]}"
    ;;
  blob-download)
    require_var AZURE_STORAGE_CONTAINER
    require_var AZURE_STORAGE_BLOB_NAME
    require_var AZURE_STORAGE_DESTINATION
    storage_auth_args
    exec az storage blob download \
      --container-name "$AZURE_STORAGE_CONTAINER" \
      --name "$AZURE_STORAGE_BLOB_NAME" \
      --file "$AZURE_STORAGE_DESTINATION" \
      "${STORAGE_AUTH_ARGS[@]}"
    ;;
  blob-list)
    require_var AZURE_STORAGE_CONTAINER
    storage_auth_args
    exec az storage blob list --container-name "$AZURE_STORAGE_CONTAINER" "${STORAGE_AUTH_ARGS[@]}"
    ;;
  show-connection-string)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_STORAGE_ACCOUNT
    exec az storage account show-connection-string --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_STORAGE_ACCOUNT"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
