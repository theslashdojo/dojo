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
  if [[ -n "${AZURE_WEBAPP_SETTINGS:-}" ]]; then
    read -r -a SETTINGS_ARGS <<<"${AZURE_WEBAPP_SETTINGS}"
  fi
}

require_az
action="${AZURE_APP_SERVICE_ACTION:?AZURE_APP_SERVICE_ACTION is required}"
set_subscription

case "$action" in
  up)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_LOCATION
    require_var AZURE_WEBAPP_NAME
    src_path="${AZURE_WEBAPP_SRC_PATH:-.}"
    if [[ ! -d "$src_path" ]]; then
      echo "Error: source directory does not exist: $src_path" >&2
      exit 64
    fi
    (
      cd "$src_path"
      cmd=(az webapp up --name "$AZURE_WEBAPP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION")
      if [[ -n "${AZURE_WEBAPP_RUNTIME:-}" ]]; then
        cmd+=(--runtime "$AZURE_WEBAPP_RUNTIME")
      fi
      if [[ -n "${AZURE_WEBAPP_SKU:-}" ]]; then
        cmd+=(--sku "$AZURE_WEBAPP_SKU")
      fi
      exec "${cmd[@]}"
    )
    ;;
  deploy-zip)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_WEBAPP_NAME
    require_var AZURE_WEBAPP_ARTIFACT_PATH
    exec az webapp deploy --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_WEBAPP_NAME" --src-path "$AZURE_WEBAPP_ARTIFACT_PATH" --type zip
    ;;
  settings-set)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_WEBAPP_NAME
    parse_settings
    if ((${#SETTINGS_ARGS[@]} == 0)); then
      echo "Error: AZURE_WEBAPP_SETTINGS is required for settings-set." >&2
      exit 64
    fi
    exec az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_WEBAPP_NAME" --settings "${SETTINGS_ARGS[@]}"
    ;;
  log-tail)
    require_var AZURE_RESOURCE_GROUP
    require_var AZURE_WEBAPP_NAME
    exec az webapp log tail --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_WEBAPP_NAME"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
