#!/usr/bin/env bash
set -euo pipefail

json_escape() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

scope="${SYSTEMD_SCOPE:-system}"
action="${SYSTEMD_ACTION:-${1:-}}"
unit="${SYSTEMD_UNIT:-${2:-}}"

if [[ -z "$action" ]]; then
  echo "Usage: manage-unit.sh <action> [unit]" >&2
  echo "Actions: start stop restart try-restart reload reload-or-restart enable disable reenable mask unmask reset-failed daemon-reload" >&2
  exit 64
fi

cmd=(systemctl --no-pager)
if [[ "$scope" == "user" ]]; then
  cmd+=(--user)
fi
if [[ -n "${SYSTEMD_HOST:-}" ]]; then
  cmd+=(-H "$SYSTEMD_HOST")
fi

inspect_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/inspect-unit.sh"

run_and_report() {
  local state_json
  if state_json="$("$inspect_script" "$unit" 2>/dev/null)"; then
    :
  else
    state_json='null'
  fi

  printf '{"action":"%s","scope":"%s","unit":"%s","state":%s}\n' \
    "$(json_escape "$action")" \
    "$(json_escape "$scope")" \
    "$(json_escape "$unit")" \
    "$state_json"
}

case "$action" in
  daemon-reload)
    "${cmd[@]}" daemon-reload
    printf '{"action":"daemon-reload","scope":"%s","changed":true}\n' "$(json_escape "$scope")"
    ;;
  start|stop|restart|try-restart|reload|reload-or-restart|enable|disable|reenable|mask|unmask|reset-failed)
    if [[ -z "$unit" ]]; then
      echo "Unit name is required for action: $action" >&2
      exit 64
    fi

    args=("${cmd[@]}")
    if is_true "${SYSTEMD_NO_BLOCK:-false}"; then
      args+=(--no-block)
    fi
    if is_true "${SYSTEMD_FORCE:-false}"; then
      args+=(--force)
    fi

    case "$action" in
      enable|disable|reenable|mask|unmask)
        if is_true "${SYSTEMD_RUNTIME:-false}"; then
          args+=(--runtime)
        fi
        if is_true "${SYSTEMD_NOW:-false}"; then
          args+=(--now)
        fi
        ;;
    esac

    args+=("$action" "$unit")
    "${args[@]}"
    run_and_report
    ;;
  *)
    echo "Unsupported action: $action" >&2
    exit 64
    ;;
esac
