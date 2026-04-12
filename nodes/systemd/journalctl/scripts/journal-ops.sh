#!/usr/bin/env bash
set -euo pipefail

is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<'EOF' >&2
Usage:
  journal-ops.sh query [FIELD=VALUE ...]
  journal-ops.sh disk-usage
  journal-ops.sh verify
  journal-ops.sh list-boots
  journal-ops.sh rotate
  journal-ops.sh flush
  journal-ops.sh sync
  journal-ops.sh vacuum-time <span>
  journal-ops.sh vacuum-size <bytes>
  journal-ops.sh vacuum-files <count>
  journal-ops.sh fields
  journal-ops.sh field-values <FIELD>
EOF
}

scope="${SYSTEMD_JOURNAL_SCOPE:-all}"
action="${1:-${SYSTEMD_JOURNAL_ACTION:-query}}"

build_query_cmd() {
  cmd=(journalctl --no-pager)

  case "$scope" in
    system) cmd+=(--system) ;;
    user) cmd+=(--user) ;;
    all|"") ;;
    *)
      echo "SYSTEMD_JOURNAL_SCOPE must be all, system, or user" >&2
      exit 64
      ;;
  esac

  if [[ -n "${SYSTEMD_JOURNAL_MACHINE:-}" ]]; then
    cmd+=("--machine=${SYSTEMD_JOURNAL_MACHINE}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_DIRECTORY:-}" ]]; then
    cmd+=("--directory=${SYSTEMD_JOURNAL_DIRECTORY}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_FILE:-}" ]]; then
    cmd+=("--file=${SYSTEMD_JOURNAL_FILE}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_ROOT:-}" ]]; then
    cmd+=("--root=${SYSTEMD_JOURNAL_ROOT}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_NAMESPACE:-}" ]]; then
    cmd+=("--namespace=${SYSTEMD_JOURNAL_NAMESPACE}")
  fi

  if [[ -n "${SYSTEMD_JOURNAL_UNIT:-}" ]]; then
    cmd+=("--unit=${SYSTEMD_JOURNAL_UNIT}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_USER_UNIT:-}" ]]; then
    cmd+=("--user-unit=${SYSTEMD_JOURNAL_USER_UNIT}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_BOOT:-}" ]]; then
    cmd+=("--boot=${SYSTEMD_JOURNAL_BOOT}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_SINCE:-}" ]]; then
    cmd+=("--since=${SYSTEMD_JOURNAL_SINCE}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_UNTIL:-}" ]]; then
    cmd+=("--until=${SYSTEMD_JOURNAL_UNTIL}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_PRIORITY:-}" ]]; then
    cmd+=("--priority=${SYSTEMD_JOURNAL_PRIORITY}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_IDENTIFIER:-}" ]]; then
    cmd+=("--identifier=${SYSTEMD_JOURNAL_IDENTIFIER}")
  fi
  if [[ -n "${SYSTEMD_JOURNAL_GREP:-}" ]]; then
    cmd+=("--grep=${SYSTEMD_JOURNAL_GREP}")
  fi

  output_mode="${SYSTEMD_JOURNAL_OUTPUT:-short-iso}"
  cmd+=("--output=${output_mode}")

  if [[ -n "${SYSTEMD_JOURNAL_LINES:-}" ]]; then
    cmd+=("--lines=${SYSTEMD_JOURNAL_LINES}")
  fi
  if is_true "${SYSTEMD_JOURNAL_REVERSE:-false}"; then
    cmd+=(--reverse)
  fi
  if is_true "${SYSTEMD_JOURNAL_UTC:-false}"; then
    cmd+=(--utc)
  fi
  if is_true "${SYSTEMD_JOURNAL_SHOW_CURSOR:-false}"; then
    cmd+=(--show-cursor)
  fi
  if is_true "${SYSTEMD_JOURNAL_ALL_FIELDS:-false}"; then
    cmd+=(--all)
  fi
  if is_true "${SYSTEMD_JOURNAL_QUIET:-false}"; then
    cmd+=(--quiet)
  fi
  if is_true "${SYSTEMD_JOURNAL_FOLLOW:-false}"; then
    cmd+=(--follow)
  fi

  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    cmd+=("$match")
  done <<< "${SYSTEMD_JOURNAL_MATCHES:-}"
}

case "$action" in
  query)
    shift || true
    build_query_cmd
    if (($# > 0)); then
      cmd+=("$@")
    fi
    exec "${cmd[@]}"
    ;;
  disk-usage)
    exec journalctl --disk-usage
    ;;
  verify)
    exec journalctl --verify
    ;;
  list-boots)
    exec journalctl --list-boots
    ;;
  rotate)
    exec journalctl --rotate
    ;;
  flush)
    exec journalctl --flush
    ;;
  sync)
    exec journalctl --sync
    ;;
  vacuum-time)
    value="${2:-${SYSTEMD_JOURNAL_VACUUM_TIME:-}}"
    [[ -n "$value" ]] || { echo "vacuum-time requires a time span" >&2; exit 64; }
    exec journalctl "--vacuum-time=${value}"
    ;;
  vacuum-size)
    value="${2:-${SYSTEMD_JOURNAL_VACUUM_SIZE:-}}"
    [[ -n "$value" ]] || { echo "vacuum-size requires a size" >&2; exit 64; }
    exec journalctl "--vacuum-size=${value}"
    ;;
  vacuum-files)
    value="${2:-${SYSTEMD_JOURNAL_VACUUM_FILES:-}}"
    [[ -n "$value" ]] || { echo "vacuum-files requires a count" >&2; exit 64; }
    exec journalctl "--vacuum-files=${value}"
    ;;
  fields)
    exec journalctl --fields
    ;;
  field-values)
    field="${2:-${SYSTEMD_JOURNAL_FIELD:-}}"
    [[ -n "$field" ]] || { echo "field-values requires a field name" >&2; exit 64; }
    exec journalctl "--field=${field}"
    ;;
  *)
    usage
    exit 64
    ;;
esac
