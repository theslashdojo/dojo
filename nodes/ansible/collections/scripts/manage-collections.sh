#!/usr/bin/env bash
set -euo pipefail

if ! command -v ansible-galaxy >/dev/null 2>&1; then
  echo "Error: ansible-galaxy is not installed." >&2
  exit 127
fi

action="${ANSIBLE_GALAXY_ACTION:-}"
if [ -z "$action" ]; then
  echo "Error: ANSIBLE_GALAXY_ACTION is required." >&2
  exit 1
fi

collection_name="${ANSIBLE_COLLECTION_NAME:-}"
requirements_file="${ANSIBLE_GALAXY_REQUIREMENTS_FILE:-}"
collections_path="${ANSIBLE_COLLECTIONS_PATH:-}"
galaxy_token="${ANSIBLE_GALAXY_TOKEN:-}"
galaxy_server="${ANSIBLE_GALAXY_SERVER:-}"
force="${ANSIBLE_FORCE:-false}"
init_path="${ANSIBLE_COLLECTION_INIT_PATH:-}"

declare -a common
common=()

if [ -n "$collections_path" ]; then
  common+=(--collections-path "$collections_path")
fi
if [ -n "$galaxy_token" ]; then
  common+=(--token "$galaxy_token")
fi
if [ -n "$galaxy_server" ]; then
  common+=(--server "$galaxy_server")
fi
if [ "$force" = "true" ]; then
  common+=(--force)
fi

declare -a cmd

case "$action" in
  install)
    cmd=(ansible-galaxy collection install)
    cmd+=("${common[@]}")
    if [ -n "$requirements_file" ]; then
      cmd+=(-r "$requirements_file")
    elif [ -n "$collection_name" ]; then
      cmd+=("$collection_name")
    else
      echo "Error: set ANSIBLE_GALAXY_REQUIREMENTS_FILE or ANSIBLE_COLLECTION_NAME for install." >&2
      exit 1
    fi
    ;;
  list)
    cmd=(ansible-galaxy collection list)
    cmd+=("${common[@]}")
    if [ -n "$collection_name" ]; then
      cmd+=("$collection_name")
    fi
    ;;
  verify)
    if [ -z "$collection_name" ]; then
      echo "Error: ANSIBLE_COLLECTION_NAME is required for verify." >&2
      exit 1
    fi
    cmd=(ansible-galaxy collection verify)
    cmd+=("${common[@]}")
    cmd+=("$collection_name")
    ;;
  init)
    if [ -z "$collection_name" ]; then
      echo "Error: ANSIBLE_COLLECTION_NAME is required for init." >&2
      exit 1
    fi
    cmd=(ansible-galaxy collection init)
    if [ "$force" = "true" ]; then
      cmd+=(--force)
    fi
    if [ -n "$init_path" ]; then
      cmd+=(--init-path "$init_path")
    fi
    cmd+=("$collection_name")
    ;;
  *)
    echo "Error: unsupported ANSIBLE_GALAXY_ACTION '$action'." >&2
    exit 1
    ;;
esac

exec "${cmd[@]}"
