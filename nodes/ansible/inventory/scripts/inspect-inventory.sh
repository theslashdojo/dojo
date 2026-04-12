#!/usr/bin/env bash
set -euo pipefail

if ! command -v ansible-inventory >/dev/null 2>&1; then
  echo "Error: ansible-inventory is not installed." >&2
  exit 127
fi

action="${ANSIBLE_INVENTORY_ACTION:-list}"
source_path="${ANSIBLE_INVENTORY_SOURCE:-inventory}"
format="${ANSIBLE_INVENTORY_FORMAT:-json}"
host_name="${ANSIBLE_HOST_NAME:-}"

declare -a cmd
cmd=(ansible-inventory -i "$source_path")

case "$action" in
  list)
    cmd+=(--list)
    if [ "$format" = "yaml" ]; then
      cmd+=(--yaml)
    fi
    ;;
  graph)
    cmd+=(--graph)
    ;;
  host)
    if [ -z "$host_name" ]; then
      echo "Error: ANSIBLE_HOST_NAME is required when ANSIBLE_INVENTORY_ACTION=host." >&2
      exit 1
    fi
    cmd+=(--host "$host_name")
    if [ "$format" = "yaml" ]; then
      cmd+=(--yaml)
    fi
    ;;
  vars)
    cmd+=(--list --yaml)
    ;;
  *)
    echo "Error: unsupported ANSIBLE_INVENTORY_ACTION '$action'." >&2
    exit 1
    ;;
esac

exec "${cmd[@]}"
