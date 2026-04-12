#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 64
  fi
}

require_agent() {
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    echo "SSH_AUTH_SOCK must be set. Start an agent first." >&2
    exit 64
  fi
}

action="${SSH_AGENT_ACTION:-start}"

case "$action" in
  start)
    cmd=(ssh-agent -s)
    if [[ -n "${SSH_AGENT_SOCKET:-}" ]]; then
      cmd=(ssh-agent -s -a "$SSH_AGENT_SOCKET")
    fi
    if [[ -n "${SSH_AGENT_LIFETIME:-}" ]]; then
      cmd+=(-t "$SSH_AGENT_LIFETIME")
    fi

    printf 'Executing:' >&2
    printf ' %q' "${cmd[@]}" >&2
    printf '\n' >&2
    exec "${cmd[@]}"
    ;;

  add)
    require_agent
    cmd=(ssh-add)
    if [[ "${SSH_ADD_CONFIRM:-false}" == "true" ]]; then
      cmd+=(-c)
    fi
    if [[ -n "${SSH_ADD_LIFETIME:-}" ]]; then
      cmd+=(-t "$SSH_ADD_LIFETIME")
    fi
    if [[ -n "${SSH_DESTINATION_CONSTRAINT:-}" ]]; then
      cmd+=(-h "$SSH_DESTINATION_CONSTRAINT")
    fi
    if [[ -n "${SSH_KEY_PATH:-}" ]]; then
      cmd+=("$SSH_KEY_PATH")
    fi
    printf 'Executing:' >&2
    printf ' %q' "${cmd[@]}" >&2
    printf '\n' >&2
    exec "${cmd[@]}"
    ;;

  list)
    require_agent
    exec ssh-add -l
    ;;

  clear)
    require_agent
    exec ssh-add -D
    ;;

  remove)
    require_agent
    require_env SSH_KEY_PATH
    exec ssh-add -d "$SSH_KEY_PATH"
    ;;

  lock)
    require_agent
    exec ssh-add -x
    ;;

  unlock)
    require_agent
    exec ssh-add -X
    ;;

  *)
    echo "SSH_AGENT_ACTION must be start, add, list, clear, remove, lock, or unlock" >&2
    exit 64
    ;;
esac
