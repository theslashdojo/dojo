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
action="${AZURE_KEY_VAULT_ACTION:?AZURE_KEY_VAULT_ACTION is required}"
set_subscription

case "$action" in
  vault-create)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_LOCATION
    require_var AZURE_KEY_VAULT_NAME
    exec az keyvault create --name "$AZURE_KEY_VAULT_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION" --enable-rbac-authorization true
    ;;
  grant-secrets-officer)
    require_var AZURE_KEY_VAULT_NAME
    require_var AZURE_KEY_VAULT_ASSIGNEE
    scope="$(az keyvault show --name "$AZURE_KEY_VAULT_NAME" --query id --output tsv)"
    exec az role assignment create --role "Key Vault Secrets Officer" --assignee "$AZURE_KEY_VAULT_ASSIGNEE" --scope "$scope"
    ;;
  secret-set)
    require_var AZURE_KEY_VAULT_NAME
    require_var AZURE_SECRET_NAME
    require_var AZURE_SECRET_VALUE
    exec az keyvault secret set --vault-name "$AZURE_KEY_VAULT_NAME" --name "$AZURE_SECRET_NAME" --value "$AZURE_SECRET_VALUE"
    ;;
  secret-show)
    require_var AZURE_KEY_VAULT_NAME
    require_var AZURE_SECRET_NAME
    exec az keyvault secret show --vault-name "$AZURE_KEY_VAULT_NAME" --name "$AZURE_SECRET_NAME"
    ;;
  secret-delete)
    require_var AZURE_KEY_VAULT_NAME
    require_var AZURE_SECRET_NAME
    exec az keyvault secret delete --vault-name "$AZURE_KEY_VAULT_NAME" --name "$AZURE_SECRET_NAME"
    ;;
  secret-purge)
    require_var AZURE_KEY_VAULT_NAME
    require_var AZURE_SECRET_NAME
    exec az keyvault secret purge --vault-name "$AZURE_KEY_VAULT_NAME" --name "$AZURE_SECRET_NAME"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
