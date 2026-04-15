#!/usr/bin/env bash
set -euo pipefail

PROMTOOL_BIN="${PROMTOOL_BIN:-promtool}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

usage() {
  cat <<'EOF'
Usage:
  manage-config.sh validate <prometheus.yml>
  manage-config.sh check-sd <prometheus.yml> <job-name>
  manage-config.sh reload
  manage-config.sh show-loaded

Environment:
  PROMTOOL_BIN                   promtool binary to use
  PROMETHEUS_URL                 base URL for reload and config inspection
  PROMETHEUS_BEARER_TOKEN        optional bearer token
  PROMETHEUS_BASIC_AUTH_USERNAME optional basic auth username
  PROMETHEUS_BASIC_AUTH_PASSWORD optional basic auth password
  PROMETHEUS_CA_BUNDLE           optional CA bundle for HTTPS
  PROMETHEUS_INSECURE_SKIP_VERIFY set to true to skip TLS verification
  PROM_CONFIG_SYNTAX_ONLY        set to true for promtool check config --syntax-only
  PROM_CONFIG_LINT               promtool lint mode, for example all or none
  PROM_CONFIG_LINT_FATAL         set to true to fail on lint warnings
  PROM_CONFIG_AGENT_MODE         set to true to validate agent-mode config
  PROM_SD_TIMEOUT                service discovery timeout, default 30s
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

case "$action" in
  validate)
    require_cmd "$PROMTOOL_BIN"
    config_file="${2:-}"
    if [[ -z "$config_file" ]]; then
      usage
      exit 1
    fi

    cmd=("$PROMTOOL_BIN" check config)
    if [[ "${PROM_CONFIG_SYNTAX_ONLY:-false}" == "true" ]]; then
      cmd+=(--syntax-only)
    fi
    if [[ -n "${PROM_CONFIG_LINT:-}" ]]; then
      cmd+=("--lint=${PROM_CONFIG_LINT}")
    fi
    if [[ "${PROM_CONFIG_LINT_FATAL:-false}" == "true" ]]; then
      cmd+=(--lint-fatal)
    fi
    if [[ "${PROM_CONFIG_AGENT_MODE:-false}" == "true" ]]; then
      cmd+=(--agent)
    fi
    cmd+=("$config_file")

    "${cmd[@]}"
    ;;
  check-sd)
    require_cmd "$PROMTOOL_BIN"
    config_file="${2:-}"
    job_name="${3:-}"
    if [[ -z "$config_file" || -z "$job_name" ]]; then
      usage
      exit 1
    fi

    "$PROMTOOL_BIN" check service-discovery --timeout "${PROM_SD_TIMEOUT:-30s}" "$config_file" "$job_name"
    ;;
  reload)
    curl_with_auth POST "${PROMETHEUS_URL%/}/-/reload"
    printf '\n'
    ;;
  show-loaded)
    curl_with_auth GET "${PROMETHEUS_URL%/}/api/v1/status/config"
    printf '\n'
    ;;
  *)
    usage
    exit 1
    ;;
esac
