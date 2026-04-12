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

require_env SSH_TUNNEL_MODE
require_env SSH_HOST

mode="${SSH_TUNNEL_MODE}"
destination="${SSH_HOST}"
if [[ -n "${SSH_USER:-}" ]]; then
  destination="${SSH_USER}@${SSH_HOST}"
fi

cmd=(ssh -N)

if [[ "${SSH_BACKGROUND:-false}" == "true" ]]; then
  cmd+=(-f -n)
fi

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

cmd+=(-o "ExitOnForwardFailure=${SSH_EXIT_ON_FORWARD_FAILURE:-yes}")

if [[ -n "${SSH_SERVER_ALIVE_INTERVAL:-}" ]]; then
  cmd+=(-o "ServerAliveInterval=${SSH_SERVER_ALIVE_INTERVAL}")
fi

if [[ -n "${SSH_SERVER_ALIVE_COUNT_MAX:-}" ]]; then
  cmd+=(-o "ServerAliveCountMax=${SSH_SERVER_ALIVE_COUNT_MAX}")
fi

forward_spec=""
case "$mode" in
  local)
    require_env SSH_LOCAL_PORT
    require_env SSH_DEST_HOST
    require_env SSH_DEST_PORT
    forward_spec="${SSH_LOCAL_PORT}:${SSH_DEST_HOST}:${SSH_DEST_PORT}"
    if [[ -n "${SSH_BIND_ADDRESS:-}" ]]; then
      forward_spec="${SSH_BIND_ADDRESS}:${forward_spec}"
    fi
    cmd+=(-L "$forward_spec")
    ;;

  remote)
    require_env SSH_REMOTE_PORT
    require_env SSH_DEST_HOST
    require_env SSH_DEST_PORT
    forward_spec="${SSH_REMOTE_PORT}:${SSH_DEST_HOST}:${SSH_DEST_PORT}"
    if [[ -n "${SSH_BIND_ADDRESS:-}" ]]; then
      forward_spec="${SSH_BIND_ADDRESS}:${forward_spec}"
    fi
    cmd+=(-R "$forward_spec")
    ;;

  dynamic)
    require_env SSH_LOCAL_PORT
    forward_spec="${SSH_LOCAL_PORT}"
    if [[ -n "${SSH_BIND_ADDRESS:-}" ]]; then
      forward_spec="${SSH_BIND_ADDRESS}:${forward_spec}"
    fi
    cmd+=(-D "$forward_spec")
    ;;

  *)
    echo "SSH_TUNNEL_MODE must be local, remote, or dynamic" >&2
    exit 64
    ;;
esac

append_extra_args

cmd+=("$destination")

printf 'Executing (%s forward):' "$mode" >&2
printf ' %q' "${cmd[@]}" >&2
printf '\n' >&2

exec "${cmd[@]}"
