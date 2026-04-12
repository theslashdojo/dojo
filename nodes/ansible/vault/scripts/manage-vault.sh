#!/usr/bin/env bash
set -euo pipefail

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo "Error: ansible-vault is not installed." >&2
  exit 127
fi

action="${ANSIBLE_VAULT_ACTION:-}"
if [ -z "$action" ]; then
  echo "Error: ANSIBLE_VAULT_ACTION is required." >&2
  exit 1
fi

target="${ANSIBLE_VAULT_TARGET:-}"
vault_id="${ANSIBLE_VAULT_ID:-}"
password_file="${ANSIBLE_VAULT_PASSWORD_FILE:-}"
value="${ANSIBLE_VAULT_STRING:-}"
name="${ANSIBLE_VAULT_NAME:-secret_value}"
new_vault_id="${ANSIBLE_VAULT_NEW_ID:-}"
new_password_file="${ANSIBLE_VAULT_NEW_PASSWORD_FILE:-}"
encrypt_vault_id="${ANSIBLE_VAULT_ENCRYPT_ID:-}"

declare -a common
common=()

if [ -n "$vault_id" ]; then
  common+=(--vault-id "$vault_id")
fi
if [ -n "$password_file" ]; then
  common+=(--vault-password-file "$password_file")
fi

declare -a cmd

case "$action" in
  encrypt|decrypt|view|edit)
    if [ -z "$target" ]; then
      echo "Error: ANSIBLE_VAULT_TARGET is required for action=$action." >&2
      exit 1
    fi
    cmd=(ansible-vault "$action")
    cmd+=("${common[@]}")
    cmd+=("$target")
    ;;
  create)
    if [ -z "$target" ]; then
      echo "Error: ANSIBLE_VAULT_TARGET is required for action=create." >&2
      exit 1
    fi
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "Error: action=create requires an interactive terminal." >&2
      exit 1
    fi
    cmd=(ansible-vault create)
    cmd+=("${common[@]}")
    cmd+=("$target")
    ;;
  rekey)
    if [ -z "$target" ]; then
      echo "Error: ANSIBLE_VAULT_TARGET is required for action=rekey." >&2
      exit 1
    fi
    cmd=(ansible-vault rekey)
    cmd+=("${common[@]}")
    if [ -n "$new_vault_id" ]; then
      cmd+=(--new-vault-id "$new_vault_id")
    fi
    if [ -n "$new_password_file" ]; then
      cmd+=(--new-vault-password-file "$new_password_file")
    fi
    cmd+=("$target")
    ;;
  encrypt-string)
    if [ -z "$value" ]; then
      echo "Error: ANSIBLE_VAULT_STRING is required for action=encrypt-string." >&2
      exit 1
    fi
    cmd=(ansible-vault encrypt_string)
    cmd+=("${common[@]}")
    if [ -n "$encrypt_vault_id" ]; then
      cmd+=(--encrypt-vault-id "$encrypt_vault_id")
    fi
    cmd+=(--name "$name" "$value")
    ;;
  *)
    echo "Error: unsupported ANSIBLE_VAULT_ACTION '$action'." >&2
    exit 1
    ;;
esac

exec "${cmd[@]}"
