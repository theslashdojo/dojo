#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 64
  fi
}

escape_sftp_path() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

append_extra_args() {
  local -n target="$1"
  if [[ -z "${SSH_EXTRA_ARGS:-}" ]]; then
    return
  fi

  while IFS= read -r arg; do
    [[ -n "$arg" ]] && target+=("$arg")
  done < <(printf '%s\n' "$SSH_EXTRA_ARGS")
}

require_env SSH_HOST

mode="${SSH_COPY_MODE:-scp}"
direction="${SSH_DIRECTION:-upload}"
remote_target="${SSH_HOST}"
if [[ -n "${SSH_USER:-}" ]]; then
  remote_target="${SSH_USER}@${SSH_HOST}"
fi

case "$mode" in
  scp)
    require_env SSH_LOCAL_PATH
    require_env SSH_REMOTE_PATH

    cmd=(scp)

    if [[ -n "${SSH_PORT:-}" ]]; then
      cmd+=(-P "$SSH_PORT")
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
    if [[ -n "${SSH_BANDWIDTH_LIMIT:-}" ]]; then
      cmd+=(-l "$SSH_BANDWIDTH_LIMIT")
    fi
    if [[ "${SSH_RECURSIVE:-false}" == "true" ]]; then
      cmd+=(-r)
    fi
    if [[ "${SSH_PRESERVE_TIMES:-false}" == "true" ]]; then
      cmd+=(-p)
    fi
    if [[ "${SSH_LEGACY_SCP:-false}" == "true" ]]; then
      cmd+=(-O)
    fi

    append_extra_args cmd

    if [[ "$direction" == "upload" ]]; then
      cmd+=("$SSH_LOCAL_PATH" "${remote_target}:${SSH_REMOTE_PATH}")
    elif [[ "$direction" == "download" ]]; then
      cmd+=("${remote_target}:${SSH_REMOTE_PATH}" "$SSH_LOCAL_PATH")
    else
      echo "SSH_DIRECTION must be upload or download" >&2
      exit 64
    fi

    printf 'Executing:' >&2
    printf ' %q' "${cmd[@]}" >&2
    printf '\n' >&2
    exec "${cmd[@]}"
    ;;

  sftp)
    cmd=(sftp)

    if [[ -n "${SSH_PORT:-}" ]]; then
      cmd+=(-P "$SSH_PORT")
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
    if [[ -n "${SSH_BANDWIDTH_LIMIT:-}" ]]; then
      cmd+=(-l "$SSH_BANDWIDTH_LIMIT")
    fi

    append_extra_args cmd

    if [[ -n "${SSH_BATCH_FILE:-}" ]]; then
      cmd+=(-b "$SSH_BATCH_FILE" "$remote_target")
      printf 'Executing:' >&2
      printf ' %q' "${cmd[@]}" >&2
      printf '\n' >&2
      exec "${cmd[@]}"
    fi

    require_env SSH_LOCAL_PATH
    require_env SSH_REMOTE_PATH

    op="put"
    if [[ "$direction" == "download" ]]; then
      op="get"
    elif [[ "$direction" != "upload" ]]; then
      echo "SSH_DIRECTION must be upload or download" >&2
      exit 64
    fi

    flags=()
    if [[ "${SSH_RECURSIVE:-false}" == "true" ]]; then
      flags+=(-R)
    fi
    if [[ "${SSH_PRESERVE_TIMES:-false}" == "true" ]]; then
      flags+=(-p)
    fi

    batch_line="$op"
    for flag in "${flags[@]}"; do
      batch_line+=" $flag"
    done
    batch_line+=" $(escape_sftp_path "$SSH_LOCAL_PATH") $(escape_sftp_path "$SSH_REMOTE_PATH")"

    cmd+=(-b - "$remote_target")

    printf 'Executing:' >&2
    printf ' %q' "${cmd[@]}" >&2
    printf '\n' >&2
    printf '%s\n' "$batch_line" | "${cmd[@]}"
    ;;

  *)
    echo "SSH_COPY_MODE must be scp or sftp" >&2
    exit 64
    ;;
esac
