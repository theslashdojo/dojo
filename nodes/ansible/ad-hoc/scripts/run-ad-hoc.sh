#!/usr/bin/env bash
set -euo pipefail

if ! command -v ansible >/dev/null 2>&1; then
  echo "Error: ansible is not installed." >&2
  exit 127
fi

pattern="${ANSIBLE_PATTERN:-}"
if [ -z "$pattern" ]; then
  echo "Error: ANSIBLE_PATTERN is required." >&2
  exit 1
fi

inventory_source="${ANSIBLE_INVENTORY_SOURCE:-inventory}"
module_name="${ANSIBLE_MODULE:-ansible.builtin.ping}"

declare -a cmd
cmd=(ansible "$pattern" -i "$inventory_source" -m "$module_name")

if [ -n "${ANSIBLE_MODULE_ARGS:-}" ]; then
  cmd+=(-a "$ANSIBLE_MODULE_ARGS")
fi
if [ -n "${ANSIBLE_REMOTE_USER:-}" ]; then
  cmd+=(-u "$ANSIBLE_REMOTE_USER")
fi
if [ -n "${ANSIBLE_PRIVATE_KEY_FILE:-}" ]; then
  cmd+=(--private-key "$ANSIBLE_PRIVATE_KEY_FILE")
fi
if [ "${ANSIBLE_BECOME:-false}" = "true" ]; then
  cmd+=(-b)
fi
if [ -n "${ANSIBLE_BECOME_USER:-}" ]; then
  cmd+=(--become-user "$ANSIBLE_BECOME_USER")
fi
if [ "${ANSIBLE_CHECK_MODE:-false}" = "true" ]; then
  cmd+=(--check)
fi
if [ -n "${ANSIBLE_LIMIT:-}" ]; then
  cmd+=(--limit "$ANSIBLE_LIMIT")
fi
if [ -n "${ANSIBLE_FORKS:-}" ]; then
  cmd+=(-f "$ANSIBLE_FORKS")
fi
if [ -n "${ANSIBLE_TIMEOUT:-}" ]; then
  cmd+=(-T "$ANSIBLE_TIMEOUT")
fi
if [ -n "${ANSIBLE_EXTRA_VARS:-}" ]; then
  cmd+=(-e "$ANSIBLE_EXTRA_VARS")
fi
if [ "${ANSIBLE_ONE_LINE:-false}" = "true" ]; then
  cmd+=(-o)
fi

exec "${cmd[@]}"
