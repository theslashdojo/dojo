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

parse_tags() {
  TAG_ARGS=()
  if [[ -n "${AZURE_RESOURCE_GROUP_TAGS:-}" ]]; then
    read -r -a TAG_ARGS <<<"${AZURE_RESOURCE_GROUP_TAGS}"
  fi
}

require_az
action="${AZURE_RESOURCE_GROUP_ACTION:?AZURE_RESOURCE_GROUP_ACTION is required}"
set_subscription

case "$action" in
  list)
    if [[ -n "${AZURE_RESOURCE_GROUP_TAG_FILTER:-}" ]]; then
      exec az group list --tag "${AZURE_RESOURCE_GROUP_TAG_FILTER}"
    fi
    exec az group list
    ;;
  show)
    require_var AZURE_RESOURCE_GROUP_NAME
    exec az group show --name "$AZURE_RESOURCE_GROUP_NAME"
    ;;
  create)
    require_var AZURE_RESOURCE_GROUP_NAME
    require_var AZURE_LOCATION
    parse_tags
    cmd=(az group create --name "$AZURE_RESOURCE_GROUP_NAME" --location "$AZURE_LOCATION")
    if ((${#TAG_ARGS[@]})); then
      cmd+=(--tags "${TAG_ARGS[@]}")
    fi
    exec "${cmd[@]}"
    ;;
  update-tags)
    require_var AZURE_RESOURCE_GROUP_NAME
    parse_tags
    if ((${#TAG_ARGS[@]} == 0)); then
      echo "Error: AZURE_RESOURCE_GROUP_TAGS is required for update-tags." >&2
      exit 64
    fi
    if [[ "${AZURE_RESOURCE_GROUP_TAG_MODE:-merge}" == "replace" ]]; then
      exec az group update --resource-group "$AZURE_RESOURCE_GROUP_NAME" --tags "${TAG_ARGS[@]}"
    fi
    cmd=(az group update --resource-group "$AZURE_RESOURCE_GROUP_NAME")
    for pair in "${TAG_ARGS[@]}"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      cmd+=(--set "tags.${key}=${value}")
    done
    exec "${cmd[@]}"
    ;;
  delete)
    require_var AZURE_RESOURCE_GROUP_NAME
    cmd=(az group delete --name "$AZURE_RESOURCE_GROUP_NAME" --yes)
    if [[ "${AZURE_DELETE_WAIT:-false}" != "true" ]]; then
      cmd+=(--no-wait)
    fi
    exec "${cmd[@]}"
    ;;
  *)
    echo "Error: unsupported action: $action" >&2
    exit 64
    ;;
esac
