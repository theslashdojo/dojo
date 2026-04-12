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

normalize_timer_name() {
  local value="$1"
  if [[ "$value" != *.timer ]]; then
    value="${value}.timer"
  fi
  printf '%s' "$value"
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
timer_name="${SYSTEMD_TIMER_NAME:-${1:-}}"

if [[ -z "$timer_name" ]]; then
  echo "SYSTEMD_TIMER_NAME is required" >&2
  exit 64
fi

case "$scope" in
  system|user) ;;
  *)
    echo "SYSTEMD_SCOPE must be system or user" >&2
    exit 64
    ;;
esac

timer_name="$(normalize_timer_name "$timer_name")"
base_name="${timer_name%.timer}"
timer_description="${SYSTEMD_TIMER_DESCRIPTION:-$base_name timer}"
unit_to_activate="${SYSTEMD_TIMER_UNIT:-${base_name}.service}"
on_calendar="${SYSTEMD_TIMER_ON_CALENDAR:-}"
on_active_sec="${SYSTEMD_TIMER_ON_ACTIVE_SEC:-}"
on_boot_sec="${SYSTEMD_TIMER_ON_BOOT_SEC:-}"
on_startup_sec="${SYSTEMD_TIMER_ON_STARTUP_SEC:-}"
on_unit_active_sec="${SYSTEMD_TIMER_ON_UNIT_ACTIVE_SEC:-}"
on_unit_inactive_sec="${SYSTEMD_TIMER_ON_UNIT_INACTIVE_SEC:-}"
accuracy_sec="${SYSTEMD_TIMER_ACCURACY_SEC:-}"
randomized_delay_sec="${SYSTEMD_TIMER_RANDOMIZED_DELAY_SEC:-}"
fixed_random_delay="${SYSTEMD_TIMER_FIXED_RANDOM_DELAY:-}"
persistent="${SYSTEMD_TIMER_PERSISTENT:-}"
wake_system="${SYSTEMD_TIMER_WAKE_SYSTEM:-}"
remain_after_elapse="${SYSTEMD_TIMER_REMAIN_AFTER_ELAPSE:-}"

if [[ -z "$on_calendar" && -z "$on_active_sec" && -z "$on_boot_sec" && -z "$on_startup_sec" && -z "$on_unit_active_sec" && -z "$on_unit_inactive_sec" ]]; then
  echo "At least one timer trigger must be set" >&2
  exit 64
fi

if [[ "$scope" == "system" ]]; then
  timer_path="/etc/systemd/system/${timer_name}"
else
  timer_path="${HOME}/.config/systemd/user/${timer_name}"
fi
wanted_by="${SYSTEMD_TIMER_WANTED_BY:-timers.target}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
tmp_file="${tmp_dir}/${timer_name}"

{
  echo "[Unit]"
  printf 'Description=%s\n' "$timer_description"
  echo
  echo "[Timer]"
  printf 'Unit=%s\n' "$unit_to_activate"
  [[ -n "$on_calendar" ]] && printf 'OnCalendar=%s\n' "$on_calendar"
  [[ -n "$on_active_sec" ]] && printf 'OnActiveSec=%s\n' "$on_active_sec"
  [[ -n "$on_boot_sec" ]] && printf 'OnBootSec=%s\n' "$on_boot_sec"
  [[ -n "$on_startup_sec" ]] && printf 'OnStartupSec=%s\n' "$on_startup_sec"
  [[ -n "$on_unit_active_sec" ]] && printf 'OnUnitActiveSec=%s\n' "$on_unit_active_sec"
  [[ -n "$on_unit_inactive_sec" ]] && printf 'OnUnitInactiveSec=%s\n' "$on_unit_inactive_sec"
  [[ -n "$accuracy_sec" ]] && printf 'AccuracySec=%s\n' "$accuracy_sec"
  [[ -n "$randomized_delay_sec" ]] && printf 'RandomizedDelaySec=%s\n' "$randomized_delay_sec"
  [[ -n "$fixed_random_delay" ]] && printf 'FixedRandomDelay=%s\n' "$fixed_random_delay"
  [[ -n "$persistent" ]] && printf 'Persistent=%s\n' "$persistent"
  [[ -n "$wake_system" ]] && printf 'WakeSystem=%s\n' "$wake_system"
  [[ -n "$remain_after_elapse" ]] && printf 'RemainAfterElapse=%s\n' "$remain_after_elapse"
  echo
  echo "[Install]"
  printf 'WantedBy=%s\n' "$wanted_by"
} > "$tmp_file"

if ! is_true "${SYSTEMD_SKIP_VERIFY:-false}"; then
  run_analyze verify "$tmp_file"
fi

run_with_optional_sudo install -D -m 0644 "$tmp_file" "$timer_path"
run_systemctl daemon-reload

enable_timer=false
start_timer=false
if is_true "${SYSTEMD_TIMER_ENABLE:-false}"; then
  enable_timer=true
fi
if is_true "${SYSTEMD_TIMER_START:-false}"; then
  start_timer=true
fi

if [[ "$enable_timer" == true && "$start_timer" == true ]]; then
  run_systemctl enable --now "$timer_name"
elif [[ "$enable_timer" == true ]]; then
  run_systemctl enable "$timer_name"
elif [[ "$start_timer" == true ]]; then
  run_systemctl start "$timer_name"
fi

enabled_state="$(run_systemctl is-enabled "$timer_name" 2>/dev/null || true)"
active_state="$(run_systemctl is-active "$timer_name" 2>/dev/null || true)"
next_elapse="$(run_systemctl show "$timer_name" --property=NextElapseUSecRealtime --value 2>/dev/null || true)"

printf '{"unit":"%s","scope":"%s","path":"%s","activates":"%s","enabledState":"%s","activeState":"%s","nextElapse":"%s"}\n' \
  "$(json_escape "$timer_name")" \
  "$(json_escape "$scope")" \
  "$(json_escape "$timer_path")" \
  "$(json_escape "$unit_to_activate")" \
  "$(json_escape "$enabled_state")" \
  "$(json_escape "$active_state")" \
  "$(json_escape "$next_elapse")"
