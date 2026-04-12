#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 64
  fi
}

append_extra_args() {
  if [[ -z "${SSH_EXTRA_ARGS:-}" ]]; then
    return
  fi

  while IFS= read -r arg; do
    [[ -n "$arg" ]] && cmd+=("$arg")
  done < <(printf '%s\n' "$SSH_EXTRA_ARGS")
}

require_env SSH_HOST

destination="${SSH_HOST}"
if [[ -n "${SSH_USER:-}" ]]; then
  destination="${SSH_USER}@${SSH_HOST}"
fi

cmd=(ssh)

if [[ -n "${SSH_PORT:-}" ]]; then
  cmd+=(-p "$SSH_PORT")
fi

if [[ -n "${SSH_KEY_PATH:-}" ]]; then
  cmd+=(-i "$SSH_KEY_PATH")
fi

if [[ -n "${SSH_PROXY_JUMP:-}" ]]; then
  cmd+=(-J "$SSH_PROXY_JUMP")
fi

if [[ -n "${SSH_CONFIG_FILE:-}" ]]; then
  cmd+=(-F "$SSH_CONFIG_FILE")
fi

if [[ "${SSH_BATCH_MODE:-false}" == "true" ]]; then
  cmd+=(-o BatchMode=yes)
fi

if [[ -n "${SSH_STRICT_HOST_KEY_CHECKING:-}" ]]; then
  cmd+=(-o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING}")
fi

if [[ -n "${SSH_KNOWN_HOSTS_FILE:-}" ]]; then
  cmd+=(-o "UserKnownHostsFile=${SSH_KNOWN_HOSTS_FILE}")
fi

if [[ -n "${SSH_CONTROL_PATH:-}" ]]; then
  cmd+=(-S "$SSH_CONTROL_PATH")
fi

if [[ "${SSH_DISABLE_TTY:-false}" == "true" ]]; then
  cmd+=(-T)
elif [[ "${SSH_TTY:-false}" == "true" ]]; then
  cmd+=(-tt)
fi

append_extra_args

cmd+=("$destination")

mode="interactive"
if [[ -n "${SSH_COMMAND:-}" ]]; then
  mode="command"
  cmd+=("$SSH_COMMAND")
fi

printf 'Executing (%s):' "$mode" >&2
printf ' %q' "${cmd[@]}" >&2
printf '\n' >&2

exec "${cmd[@]}"
