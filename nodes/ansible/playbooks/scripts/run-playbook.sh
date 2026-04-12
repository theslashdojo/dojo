#!/usr/bin/env bash
set -euo pipefail

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed." >&2
  exit 127
fi

playbook_file="${ANSIBLE_PLAYBOOK_FILE:-}"
if [ -z "$playbook_file" ]; then
  echo "Error: ANSIBLE_PLAYBOOK_FILE is required." >&2
  exit 1
fi

inventory_source="${ANSIBLE_INVENTORY_SOURCE:-inventory}"

declare -a cmd
cmd=(ansible-playbook "$playbook_file" -i "$inventory_source")

if [ "${ANSIBLE_SYNTAX_CHECK:-false}" = "true" ]; then
  cmd+=(--syntax-check)
fi
if [ "${ANSIBLE_LIST_TASKS:-false}" = "true" ]; then
  cmd+=(--list-tasks)
fi
if [ "${ANSIBLE_LIST_TAGS:-false}" = "true" ]; then
  cmd+=(--list-tags)
fi
if [ "${ANSIBLE_LIST_HOSTS:-false}" = "true" ]; then
  cmd+=(--list-hosts)
fi
if [ -n "${ANSIBLE_LIMIT:-}" ]; then
  cmd+=(-l "$ANSIBLE_LIMIT")
fi
if [ -n "${ANSIBLE_TAGS:-}" ]; then
  cmd+=(-t "$ANSIBLE_TAGS")
fi
if [ -n "${ANSIBLE_SKIP_TAGS:-}" ]; then
  cmd+=(--skip-tags "$ANSIBLE_SKIP_TAGS")
fi
if [ -n "${ANSIBLE_START_AT_TASK:-}" ]; then
  cmd+=(--start-at-task "$ANSIBLE_START_AT_TASK")
fi
if [ "${ANSIBLE_PLAYBOOK_CHECK:-false}" = "true" ]; then
  cmd+=(-C)
fi
if [ "${ANSIBLE_PLAYBOOK_DIFF:-false}" = "true" ]; then
  cmd+=(-D)
fi
if [ "${ANSIBLE_BECOME:-false}" = "true" ]; then
  cmd+=(-b)
fi
if [ -n "${ANSIBLE_BECOME_USER:-}" ]; then
  cmd+=(--become-user "$ANSIBLE_BECOME_USER")
fi
if [ -n "${ANSIBLE_REMOTE_USER:-}" ]; then
  cmd+=(-u "$ANSIBLE_REMOTE_USER")
fi
if [ -n "${ANSIBLE_PRIVATE_KEY_FILE:-}" ]; then
  cmd+=(--private-key "$ANSIBLE_PRIVATE_KEY_FILE")
fi
if [ -n "${ANSIBLE_FORKS:-}" ]; then
  cmd+=(-f "$ANSIBLE_FORKS")
fi
if [ -n "${ANSIBLE_EXTRA_VARS:-}" ]; then
  cmd+=(-e "$ANSIBLE_EXTRA_VARS")
fi
if [ -n "${ANSIBLE_VAULT_ID:-}" ]; then
  cmd+=(--vault-id "$ANSIBLE_VAULT_ID")
fi
if [ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]; then
  cmd+=(--vault-password-file "$ANSIBLE_VAULT_PASSWORD_FILE")
fi

exec "${cmd[@]}"
