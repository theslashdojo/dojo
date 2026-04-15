#!/usr/bin/env bash
set -euo pipefail

if ! command -v mongosh >/dev/null 2>&1; then
  echo "mongosh is required but was not found in PATH" >&2
  exit 127
fi

mode_count=0
[[ -n "${MONGOSH_EVAL:-}" ]] && mode_count=$((mode_count + 1))
[[ -n "${MONGOSH_FILE:-}" ]] && mode_count=$((mode_count + 1))
if [[ "$mode_count" -ne 1 ]]; then
  echo "Set exactly one of MONGOSH_EVAL or MONGOSH_FILE" >&2
  exit 2
fi

cmd=(mongosh)
if [[ "${MONGOSH_NODB:-0}" == "1" ]]; then
  cmd+=(--nodb)
else
  : "${MONGODB_URI:?Set MONGODB_URI or use MONGOSH_NODB=1}"
  cmd+=("$MONGODB_URI")
fi

if [[ "${MONGOSH_QUIET:-1}" != "0" ]]; then
  cmd+=(--quiet)
fi

if [[ -n "${MONGOSH_JSON:-}" ]]; then
  cmd+=("--json=${MONGOSH_JSON}")
fi

if [[ -n "${MONGOSH_API_VERSION:-}" ]]; then
  cmd+=(--apiVersion "${MONGOSH_API_VERSION}")
fi

if [[ -n "${MONGOSH_FILE:-}" ]]; then
  if [[ ! -f "${MONGOSH_FILE}" ]]; then
    echo "Script file not found: ${MONGOSH_FILE}" >&2
    exit 2
  fi
  cmd+=(--file "${MONGOSH_FILE}")
else
  cmd+=(--eval "${MONGOSH_EVAL}")
fi

exec "${cmd[@]}"
