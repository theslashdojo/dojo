#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  analyze-systemd.sh verify <file...>
  analyze-systemd.sh calendar <spec...>
  analyze-systemd.sh timestamp <timestamp...>
  analyze-systemd.sh timespan <span...>
  analyze-systemd.sh security <unit...>
  analyze-systemd.sh unit-paths
  analyze-systemd.sh blame
  analyze-systemd.sh critical-chain [unit...]
  analyze-systemd.sh dump [pattern...]
  analyze-systemd.sh dot [pattern...]
EOF
}

append_multiline_args() {
  local content="$1"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    cmd+=("$line")
  done <<< "$content"
}

is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

scope="${SYSTEMD_SCOPE:-system}"
action="${1:-${SYSTEMD_ANALYZE_ACTION:-}}"

if [[ -z "$action" ]]; then
  usage
  exit 64
fi

shift || true

cmd=(systemd-analyze --no-pager)
case "$scope" in
  system) cmd+=(--system) ;;
  user) cmd+=(--user) ;;
  global) cmd+=(--global) ;;
  *)
    echo "SYSTEMD_SCOPE must be system, user, or global" >&2
    exit 64
    ;;
esac

if [[ -n "${SYSTEMD_ANALYZE_ROOT:-}" ]]; then
  cmd+=("--root=${SYSTEMD_ANALYZE_ROOT}")
fi
if [[ -n "${SYSTEMD_ANALYZE_IMAGE:-}" ]]; then
  cmd+=("--image=${SYSTEMD_ANALYZE_IMAGE}")
fi
if [[ -n "${SYSTEMD_ANALYZE_JSON:-}" ]]; then
  cmd+=("--json=${SYSTEMD_ANALYZE_JSON}")
fi
if [[ -n "${SYSTEMD_ANALYZE_THRESHOLD:-}" ]]; then
  cmd+=("--threshold=${SYSTEMD_ANALYZE_THRESHOLD}")
fi
if is_true "${SYSTEMD_ANALYZE_OFFLINE:-false}"; then
  cmd+=(--offline=true)
fi
if [[ -n "${SYSTEMD_ANALYZE_ITERATIONS:-}" ]]; then
  cmd+=("--iterations=${SYSTEMD_ANALYZE_ITERATIONS}")
fi
if is_true "${SYSTEMD_ANALYZE_ORDER_ONLY:-false}"; then
  cmd+=(--order)
fi
if is_true "${SYSTEMD_ANALYZE_REQUIRE_ONLY:-false}"; then
  cmd+=(--require)
fi
if [[ -n "${SYSTEMD_ANALYZE_FROM_PATTERN:-}" ]]; then
  cmd+=("--from-pattern=${SYSTEMD_ANALYZE_FROM_PATTERN}")
fi
if [[ -n "${SYSTEMD_ANALYZE_TO_PATTERN:-}" ]]; then
  cmd+=("--to-pattern=${SYSTEMD_ANALYZE_TO_PATTERN}")
fi

case "$action" in
  verify)
    cmd+=(verify)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_FILES:-}"
    fi
    ;;
  calendar)
    cmd+=(calendar)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_SPECS:-}"
    fi
    ;;
  timestamp)
    cmd+=(timestamp)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_TIMESTAMPS:-}"
    fi
    ;;
  timespan)
    cmd+=(timespan)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_SPANS:-}"
    fi
    ;;
  security)
    cmd+=(security)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_UNITS:-}"
    fi
    ;;
  unit-paths)
    cmd+=(unit-paths)
    ;;
  blame)
    cmd+=(blame)
    ;;
  critical-chain)
    cmd+=(critical-chain)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_UNITS:-}"
    fi
    ;;
  dump)
    cmd+=(dump)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_PATTERNS:-}"
    fi
    ;;
  dot)
    cmd+=(dot)
    if (($# > 0)); then
      cmd+=("$@")
    else
      append_multiline_args "${SYSTEMD_ANALYZE_PATTERNS:-}"
    fi
    ;;
  *)
    usage
    exit 64
    ;;
esac

if [[ "${#cmd[@]}" -le 2 ]]; then
  echo "No arguments were provided for action: $action" >&2
  exit 64
fi

exec "${cmd[@]}"
