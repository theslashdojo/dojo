#!/usr/bin/env bash
set -euo pipefail

args=()

[[ -n "${PLAYWRIGHT_PROJECT:-}" ]] && args+=(--project "${PLAYWRIGHT_PROJECT}")
[[ -n "${PLAYWRIGHT_GREP:-}" ]] && args+=(--grep "${PLAYWRIGHT_GREP}")
[[ -n "${PLAYWRIGHT_WORKERS:-}" ]] && args+=(--workers "${PLAYWRIGHT_WORKERS}")
[[ -n "${PLAYWRIGHT_RETRIES:-}" ]] && args+=(--retries "${PLAYWRIGHT_RETRIES}")
[[ "${PLAYWRIGHT_HEADED:-0}" == "1" ]] && args+=(--headed)
[[ "${PLAYWRIGHT_UI:-0}" == "1" ]] && args+=(--ui)
[[ "${PLAYWRIGHT_DEBUG:-0}" == "1" ]] && args+=(--debug)
[[ "${PLAYWRIGHT_UPDATE_SNAPSHOTS:-0}" == "1" ]] && args+=(--update-snapshots)

exec npx playwright test "${args[@]}" "$@"
