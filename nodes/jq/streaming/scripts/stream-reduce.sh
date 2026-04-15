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

if [[ -z "${JQ_FILTER:-}" && -z "${JQ_FILTER_FILE:-}" ]]; then
  echo "Error: set JQ_FILTER or JQ_FILTER_FILE" >&2
  exit 1
fi

if [[ -n "${JQ_FILTER:-}" && -n "${JQ_FILTER_FILE:-}" ]]; then
  echo "Error: set only one of JQ_FILTER or JQ_FILTER_FILE" >&2
  exit 1
fi

if [[ -n "${JQ_FILE:-}" && -n "${JQ_INPUT:-}" ]]; then
  echo "Error: set only one of JQ_FILE or JQ_INPUT" >&2
  exit 1
fi

JQ_ARGS=(--stream)
is_true "${JQ_STREAM_ERRORS:-false}" && JQ_ARGS+=(--stream-errors)
is_true "${JQ_SEQ:-false}" && JQ_ARGS+=(--seq)
is_true "${JQ_UNBUFFERED:-false}" && JQ_ARGS+=(--unbuffered)
is_true "${JQ_RAW_OUTPUT:-false}" && JQ_ARGS+=(-r)
is_true "${JQ_COMPACT_OUTPUT:-false}" && JQ_ARGS+=(-c)
is_true "${JQ_SORT_KEYS:-false}" && JQ_ARGS+=(-S)
add_named_json_vars "${JQ_VARS_JSON:-}"

if [[ -n "${JQ_FILTER_FILE:-}" ]]; then
  JQ_ARGS+=(-f "${JQ_FILTER_FILE}")
  filter_mode=file
else
  filter_mode=inline
fi

run_jq() {
  if [[ "$filter_mode" == "file" ]]; then
    if [[ -n "${JQ_FILE:-}" ]]; then
      jq "${JQ_ARGS[@]}" "${JQ_FILE}"
    elif [[ -n "${JQ_INPUT:-}" ]]; then
      printf "%s" "${JQ_INPUT}" | jq "${JQ_ARGS[@]}"
    else
      jq "${JQ_ARGS[@]}"
    fi
  else
    if [[ -n "${JQ_FILE:-}" ]]; then
      jq "${JQ_ARGS[@]}" "${JQ_FILTER}" "${JQ_FILE}"
    elif [[ -n "${JQ_INPUT:-}" ]]; then
      printf "%s" "${JQ_INPUT}" | jq "${JQ_ARGS[@]}" "${JQ_FILTER}"
    else
      jq "${JQ_ARGS[@]}" "${JQ_FILTER}"
    fi
  fi
}

run_jq
