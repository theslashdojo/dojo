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

normalize_unit_name() {
  local value="$1"
  if [[ "$value" != *.service ]]; then
    value="${value}.service"
  fi
  printf '%s' "$value"
}

normalize_space_list() {
  printf '%s' "$1" | tr ',' ' ' | xargs
}

append_multiline_directives() {
  local file_path="$1"
  local directive="$2"
  local content="$3"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf '%s=%s\n' "$directive" "$line" >> "$file_path"
  done <<< "$content"
}

run_with_optional_sudo() {
  local cmd=("$@")
  if is_true "${SYSTEMD_USE_SUDO:-false}" && [[ "${SYSTEMD_SCOPE:-system}" == "system" ]]; then
    cmd=(sudo "${cmd[@]}")
  fi
  "${cmd[@]}"
}

run_systemctl() {
  local cmd=(systemctl --no-pager)
  if [[ "${SYSTEMD_SCOPE:-system}" == "user" ]]; then
    cmd+=(--user)
  fi
  if [[ -n "${SYSTEMD_HOST:-}" ]]; then
    cmd+=(-H "$SYSTEMD_HOST")
  fi
  run_with_optional_sudo "${cmd[@]}" "$@"
}

run_analyze() {
  local cmd=(systemd-analyze --no-pager)
  if [[ "${SYSTEMD_SCOPE:-system}" == "user" ]]; then
    cmd+=(--user)
  fi
  run_with_optional_sudo "${cmd[@]}" "$@"
}

scope="${SYSTEMD_SCOPE:-system}"
service_name="${SYSTEMD_SERVICE_NAME:-${1:-}}"
exec_start="${SYSTEMD_SERVICE_EXEC_START:-}"
service_type="${SYSTEMD_SERVICE_TYPE:-exec}"

if [[ -z "$service_name" || -z "$exec_start" ]]; then
  echo "SYSTEMD_SERVICE_NAME and SYSTEMD_SERVICE_EXEC_START are required" >&2
  exit 64
fi

case "$scope" in
  system|user) ;;
  *)
    echo "SYSTEMD_SCOPE must be system or user" >&2
    exit 64
    ;;
esac

service_name="$(normalize_unit_name "$service_name")"
base_name="${service_name%.service}"
description="${SYSTEMD_SERVICE_DESCRIPTION:-$base_name}"
after_units="$(normalize_space_list "${SYSTEMD_SERVICE_AFTER:-}")"
wants_units="$(normalize_space_list "${SYSTEMD_SERVICE_WANTS:-}")"
requires_units="$(normalize_space_list "${SYSTEMD_SERVICE_REQUIRES:-}")"
service_user="${SYSTEMD_SERVICE_USER:-}"
service_group="${SYSTEMD_SERVICE_GROUP:-}"
working_directory="${SYSTEMD_SERVICE_WORKING_DIRECTORY:-}"
environment_file="${SYSTEMD_SERVICE_ENV_FILE:-}"
environment_lines="${SYSTEMD_SERVICE_ENV:-}"
exec_start_pre="${SYSTEMD_SERVICE_EXEC_START_PRE:-}"
exec_start_post="${SYSTEMD_SERVICE_EXEC_START_POST:-}"
exec_reload="${SYSTEMD_SERVICE_EXEC_RELOAD:-}"
exec_stop="${SYSTEMD_SERVICE_EXEC_STOP:-}"
restart_policy="${SYSTEMD_SERVICE_RESTART:-on-failure}"
restart_sec="${SYSTEMD_SERVICE_RESTART_SEC:-}"
timeout_start_sec="${SYSTEMD_SERVICE_TIMEOUT_START_SEC:-}"
timeout_stop_sec="${SYSTEMD_SERVICE_TIMEOUT_STOP_SEC:-}"
remain_after_exit="${SYSTEMD_SERVICE_REMAIN_AFTER_EXIT:-}"

if [[ "$scope" == "system" ]]; then
  unit_path="/etc/systemd/system/${service_name}"
  wanted_by="${SYSTEMD_SERVICE_WANTED_BY:-multi-user.target}"
else
  unit_path="${HOME}/.config/systemd/user/${service_name}"
  wanted_by="${SYSTEMD_SERVICE_WANTED_BY:-default.target}"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
tmp_file="${tmp_dir}/${service_name}"

{
  echo "[Unit]"
  printf 'Description=%s\n' "$description"
  [[ -n "$after_units" ]] && printf 'After=%s\n' "$after_units"
  [[ -n "$wants_units" ]] && printf 'Wants=%s\n' "$wants_units"
  [[ -n "$requires_units" ]] && printf 'Requires=%s\n' "$requires_units"
  echo
  echo "[Service]"
  printf 'Type=%s\n' "$service_type"
  [[ -n "$service_user" ]] && printf 'User=%s\n' "$service_user"
  [[ -n "$service_group" ]] && printf 'Group=%s\n' "$service_group"
  [[ -n "$working_directory" ]] && printf 'WorkingDirectory=%s\n' "$working_directory"
  [[ -n "$environment_file" ]] && printf 'EnvironmentFile=%s\n' "$environment_file"
} > "$tmp_file"

append_multiline_directives "$tmp_file" "Environment" "$environment_lines"
append_multiline_directives "$tmp_file" "ExecStartPre" "$exec_start_pre"
printf 'ExecStart=%s\n' "$exec_start" >> "$tmp_file"
append_multiline_directives "$tmp_file" "ExecStartPost" "$exec_start_post"
[[ -n "$exec_reload" ]] && printf 'ExecReload=%s\n' "$exec_reload" >> "$tmp_file"
[[ -n "$exec_stop" ]] && printf 'ExecStop=%s\n' "$exec_stop" >> "$tmp_file"
printf 'Restart=%s\n' "$restart_policy" >> "$tmp_file"
[[ -n "$restart_sec" ]] && printf 'RestartSec=%s\n' "$restart_sec" >> "$tmp_file"
[[ -n "$timeout_start_sec" ]] && printf 'TimeoutStartSec=%s\n' "$timeout_start_sec" >> "$tmp_file"
[[ -n "$timeout_stop_sec" ]] && printf 'TimeoutStopSec=%s\n' "$timeout_stop_sec" >> "$tmp_file"
[[ -n "$remain_after_exit" ]] && printf 'RemainAfterExit=%s\n' "$remain_after_exit" >> "$tmp_file"

{
  echo
  echo "[Install]"
  printf 'WantedBy=%s\n' "$wanted_by"
} >> "$tmp_file"

if ! is_true "${SYSTEMD_SKIP_VERIFY:-false}"; then
  run_analyze verify "$tmp_file"
fi

run_with_optional_sudo install -D -m 0644 "$tmp_file" "$unit_path"
run_systemctl daemon-reload

enable_service=false
start_service=false
if is_true "${SYSTEMD_SERVICE_ENABLE:-false}"; then
  enable_service=true
fi
if is_true "${SYSTEMD_SERVICE_START:-false}"; then
  start_service=true
fi

if [[ "$enable_service" == true && "$start_service" == true ]]; then
  run_systemctl enable --now "$service_name"
elif [[ "$enable_service" == true ]]; then
  run_systemctl enable "$service_name"
elif [[ "$start_service" == true ]]; then
  run_systemctl start "$service_name"
fi

enabled_state="$(run_systemctl is-enabled "$service_name" 2>/dev/null || true)"
active_state="$(run_systemctl is-active "$service_name" 2>/dev/null || true)"

printf '{"unit":"%s","scope":"%s","path":"%s","enabledState":"%s","activeState":"%s"}\n' \
  "$(json_escape "$service_name")" \
  "$(json_escape "$scope")" \
  "$(json_escape "$unit_path")" \
  "$(json_escape "$enabled_state")" \
  "$(json_escape "$active_state")"
