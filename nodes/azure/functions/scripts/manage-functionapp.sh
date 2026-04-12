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

parse_settings() {
  SETTINGS_ARGS=()
  if [[ -n "${AZURE_FUNCTIONAPP_SETTINGS:-}" ]]; then
    read -r -a SETTINGS_ARGS <<<"${AZURE_FUNCTIONAPP_SETTINGS}"
  fi
}

require_az
action="${AZURE_FUNCTIONAPP_ACTION:?AZURE_FUNCTIONAPP_ACTION is required}"
set_subscription

case "$action" in
  app-create)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_LOCATION
    require_var AZURE_FUNCTIONAPP_NAME
    require_var AZURE_STORAGE_ACCOUNT
    cmd=(az functionapp create --resource-group "$AZURE_RESOURCE_GROUP" --consumption-plan-location "$AZURE_LOCATION" --runtime "${AZURE_FUNCTIONS_RUNTIME:-python}" --functions-version "${AZURE_FUNCTIONS_VERSION:-4}" --name "$AZURE_FUNCTIONAPP_NAME" --storage-account "$AZURE_STORAGE_ACCOUNT" --os-type Linux)
    if [[ -n "${AZURE_FUNCTIONS_RUNTIME_VERSION:-}" ]]; then
      cmd+=(--runtime-version "$AZURE_FUNCTIONS_RUNTIME_VERSION")
    fi
    exec "${cmd[@]}"
    ;;
  deploy-zip)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_FUNCTIONAPP_NAME
    require_var AZURE_FUNCTIONAPP_ARTIFACT_PATH
    cmd=(az functionapp deployment source config-zip --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_FUNCTIONAPP_NAME" --src "$AZURE_FUNCTIONAPP_ARTIFACT_PATH")
    if [[ "${AZURE_FUNCTIONAPP_BUILD_REMOTE:-false}" == "true" ]]; then
      cmd+=(--build-remote true)
    fi
    exec "${cmd[@]}"
    ;;
  publish-core-tools)
    require_var AZURE_FUNCTIONAPP_NAME
    src_path="${AZURE_FUNCTIONAPP_SRC_PATH:-.}"
    if ! command -v func >/dev/null 2>&1; then
      echo "Error: Azure Functions Core Tools (func) is required for publish-core-tools." >&2
      exit 127
    fi
    if [[ ! -d "$src_path" ]]; then
      echo "Error: source directory does not exist: $src_path" >&2
      exit 64
    fi
    (cd "$src_path" && exec func azure functionapp publish "$AZURE_FUNCTIONAPP_NAME")
    ;;
  settings-set)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_FUNCTIONAPP_NAME
    parse_settings
    if ((${#SETTINGS_ARGS[@]} == 0)); then
      echo "Error: AZURE_FUNCTIONAPP_SETTINGS is required for settings-set." >&2
      exit 64
    fi
    exec az functionapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_FUNCTIONAPP_NAME" --settings "${SETTINGS_ARGS[@]}"
    ;;
  show)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_FUNCTIONAPP_NAME
    exec az functionapp show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_FUNCTIONAPP_NAME"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
