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

scope="${SYSTEMD_SCOPE:-system}"
unit="${SYSTEMD_UNIT:-${1:-}}"
properties="${SYSTEMD_PROPERTIES:-Id,Description,LoadState,ActiveState,SubState,UnitFileState,MainPID,ExecMainCode,ExecMainStatus,FragmentPath}"

if [[ -z "$unit" ]]; then
  echo "Usage: inspect-unit.sh <unit>" >&2
  exit 64
fi

case "$scope" in
  system|user) ;;
  *)
    echo "SYSTEMD_SCOPE must be system or user" >&2
    exit 64
    ;;
esac

cmd=(systemctl --no-pager)
if [[ "$scope" == "user" ]]; then
  cmd+=(--user)
fi
if [[ -n "${SYSTEMD_HOST:-}" ]]; then
  cmd+=(-H "$SYSTEMD_HOST")
fi

IFS=',' read -r -a keys <<< "$properties"
if ! mapfile -t values < <("${cmd[@]}" show "$unit" "--property=$properties" --value); then
  exit $?
fi

enabled_state="$("${cmd[@]}" is-enabled "$unit" 2>/dev/null || true)"
active_state="$("${cmd[@]}" is-active "$unit" 2>/dev/null || true)"
failed=false
if "${cmd[@]}" is-failed --quiet "$unit" 2>/dev/null; then
  failed=true
fi

printf '{'
printf '"unit":"%s","scope":"%s","enabledState":"%s","activeCheck":"%s","failed":%s' \
  "$(json_escape "$unit")" \
  "$(json_escape "$scope")" \
  "$(json_escape "$enabled_state")" \
  "$(json_escape "$active_state")" \
  "$failed"

for i in "${!keys[@]}"; do
  key="${keys[$i]}"
  value="${values[$i]:-}"
  printf ',"%s":' "$(json_escape "$key")"
  if [[ "$key" =~ ^(MainPID|ExecMainCode|ExecMainStatus)$ ]] && [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s' "$value"
  else
    printf '"%s"' "$(json_escape "$value")"
  fi
done

printf '}\n'
