#!/usr/bin/env bash
set -euo pipefail

PROMTOOL_BIN="${PROMTOOL_BIN:-promtool}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

usage() {
  cat <<'EOF'
Usage:
  manage-rules.sh check <rule-file> [more rule files...]
  manage-rules.sh test <test-file> [more test files...]
  manage-rules.sh list
  manage-rules.sh alerts

Environment:
  PROMTOOL_BIN                   promtool binary to use
  PROMETHEUS_URL                 Prometheus base URL
  PROMETHEUS_BEARER_TOKEN        optional bearer token
  PROMETHEUS_BASIC_AUTH_USERNAME optional basic auth username
  PROMETHEUS_BASIC_AUTH_PASSWORD optional basic auth password
  PROMETHEUS_CA_BUNDLE           optional CA bundle for HTTPS
  PROMETHEUS_INSECURE_SKIP_VERIFY set to true to skip TLS verification
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

curl_with_auth() {
  local method="$1"
  local url="$2"
  shift 2

  local args=(-fsS -X "$method")
  if [[ -n "${PROMETHEUS_BEARER_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer ${PROMETHEUS_BEARER_TOKEN}")
  elif [[ -n "${PROMETHEUS_BASIC_AUTH_USERNAME:-}" ]]; then
    args+=(-u "${PROMETHEUS_BASIC_AUTH_USERNAME}:${PROMETHEUS_BASIC_AUTH_PASSWORD:-}")
  fi

  if [[ "${PROMETHEUS_INSECURE_SKIP_VERIFY:-false}" == "true" ]]; then
    args+=(-k)
  fi

  if [[ -n "${PROMETHEUS_CA_BUNDLE:-}" ]]; then
    args+=(--cacert "${PROMETHEUS_CA_BUNDLE}")
  fi

  curl "${args[@]}" "$@" "$url"
}

action="${1:-}"
shift || true

case "$action" in
  check)
    require_cmd "$PROMTOOL_BIN"
    if [[ "$#" -lt 1 ]]; then
      usage
      exit 1
    fi
    "$PROMTOOL_BIN" check rules "$@"
    ;;
  test)
    require_cmd "$PROMTOOL_BIN"
    if [[ "$#" -lt 1 ]]; then
      usage
      exit 1
    fi
    "$PROMTOOL_BIN" test rules "$@"
    ;;
  list)
    curl_with_auth GET "${PROMETHEUS_URL%/}/api/v1/rules"
    printf '\n'
    ;;
  alerts)
    curl_with_auth GET "${PROMETHEUS_URL%/}/api/v1/alerts"
    printf '\n'
    ;;
  *)
    usage
    exit 1
    ;;
esac
