#!/usr/bin/env bash
set -euo pipefail

is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required but was not found on PATH" >&2
    exit 127
  }
}

add_named_json_vars() {
  local vars_json="$1"
  [[ -n "$vars_json" ]] || return 0

  if ! printf "%s" "$vars_json" | jq -e 'type == "object"' >/dev/null; then
    echo "Error: JQ_VARS_JSON must be a JSON object" >&2
    exit 1
  fi

  while IFS= read -r encoded; do
    [[ -n "$encoded" ]] || continue
    local decoded
    local key
    local value
    decoded=$(printf "%s" "$encoded" | base64 -d)
    key=$(printf "%s" "$decoded" | jq -r ".key")
    value=$(printf "%s" "$decoded" | jq -c ".value")
    JQ_ARGS+=(--argjson "$key" "$value")
  done < <(printf "%s" "$vars_json" | jq -rc 'to_entries[] | @base64')
}

require_jq

if [[ -z "${JQ_FILTER:-}" ]]; then
  echo "Error: JQ_FILTER is required" >&2
  exit 1
fi

if [[ -n "${JQ_FILE:-}" && -n "${JQ_INPUT:-}" ]]; then
  echo "Error: set only one of JQ_FILE or JQ_INPUT" >&2
  exit 1
fi

if is_true "${JQ_NULL_INPUT:-false}" && [[ -n "${JQ_FILE:-}" || -n "${JQ_INPUT:-}" ]]; then
  echo "Error: JQ_NULL_INPUT cannot be combined with JQ_FILE or JQ_INPUT" >&2
  exit 1
fi

JQ_ARGS=()

is_true "${JQ_NULL_INPUT:-false}" && JQ_ARGS+=(-n)
is_true "${JQ_RAW_INPUT:-false}" && JQ_ARGS+=(-R)
is_true "${JQ_SLURP:-false}" && JQ_ARGS+=(-s)
is_true "${JQ_RAW_OUTPUT:-false}" && JQ_ARGS+=(-r)
is_true "${JQ_COMPACT_OUTPUT:-false}" && JQ_ARGS+=(-c)
is_true "${JQ_SORT_KEYS:-false}" && JQ_ARGS+=(-S)
is_true "${JQ_EXIT_STATUS:-false}" && JQ_ARGS+=(-e)

add_named_json_vars "${JQ_VARS_JSON:-}"

if is_true "${JQ_NULL_INPUT:-false}"; then
  jq "${JQ_ARGS[@]}" "${JQ_FILTER}"
elif [[ -n "${JQ_FILE:-}" ]]; then
  jq "${JQ_ARGS[@]}" "${JQ_FILTER}" "${JQ_FILE}"
elif [[ -n "${JQ_INPUT:-}" ]]; then
  printf "%s" "${JQ_INPUT}" | jq "${JQ_ARGS[@]}" "${JQ_FILTER}"
else
  jq "${JQ_ARGS[@]}" "${JQ_FILTER}"
fi
