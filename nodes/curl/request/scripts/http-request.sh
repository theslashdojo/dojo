#!/usr/bin/env bash
# curl HTTP Request Script
# Executes an HTTP request using environment-variable-driven configuration.
#
# Required:
#   CURL_URL          - Target URL
#
# Optional:
#   CURL_METHOD       - HTTP method (default: GET)
#   CURL_HEADERS      - Newline-separated headers
#   CURL_DATA         - Request body (string, @filename, or @- for stdin)
#   CURL_OUTPUT       - Output mode: body, headers, status, full, or -w format string (default: body)
#   CURL_FOLLOW_REDIRECTS - Follow redirects: true/false (default: true)
#   CURL_TIMEOUT      - Max total time in seconds (default: 30)
#   CURL_RETRIES      - Number of retries (default: 0)
#   CURL_INSECURE     - Skip SSL verification: true/false (default: false)

set -euo pipefail

# --- Validate required params ---
if [[ -z "${CURL_URL:-}" ]]; then
  echo "Error: CURL_URL is required" >&2
  exit 1
fi

# --- Defaults ---
METHOD="${CURL_METHOD:-GET}"
OUTPUT="${CURL_OUTPUT:-body}"
FOLLOW="${CURL_FOLLOW_REDIRECTS:-true}"
TIMEOUT="${CURL_TIMEOUT:-30}"
RETRIES="${CURL_RETRIES:-0}"
INSECURE="${CURL_INSECURE:-false}"

# --- Build curl arguments ---
CURL_ARGS=(-s -S)

# Method
CURL_ARGS+=(-X "$METHOD")

# Headers
if [[ -n "${CURL_HEADERS:-}" ]]; then
  while IFS= read -r header; do
    header=$(echo "$header" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$header" ]]; then
      CURL_ARGS+=(-H "$header")
    fi
  done <<< "$CURL_HEADERS"
fi

# Data/body
if [[ -n "${CURL_DATA:-}" ]]; then
  CURL_ARGS+=(--data-raw "$CURL_DATA")
fi

# Follow redirects
if [[ "$FOLLOW" == "true" ]]; then
  CURL_ARGS+=(-L --max-redirs 10)
fi

# Timeout
CURL_ARGS+=(-m "$TIMEOUT")

# Retries
if [[ "$RETRIES" -gt 0 ]]; then
  CURL_ARGS+=(--retry "$RETRIES" --retry-delay 2)
fi

# Insecure
if [[ "$INSECURE" == "true" ]]; then
  CURL_ARGS+=(-k)
fi

# --- Output mode ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

case "$OUTPUT" in
  body)
    curl "${CURL_ARGS[@]}" "$CURL_URL"
    ;;
  headers)
    curl "${CURL_ARGS[@]}" -D - -o /dev/null "$CURL_URL"
    ;;
  status)
    curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}\n' "$CURL_URL"
    ;;
  full)
    # Output headers + body + timing
    HEADER_FILE=$(mktemp)
    trap 'rm -f "$TMPFILE" "$HEADER_FILE"' EXIT

    BODY=$(curl "${CURL_ARGS[@]}" \
      -D "$HEADER_FILE" \
      -w '\n---\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\nTTFB: %{time_starttransfer}s\nDNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTLS: %{time_appconnect}s\nSize: %{size_download} bytes\nRemote IP: %{remote_ip}:%{remote_port}\n' \
      "$CURL_URL")

    echo "=== Response Headers ==="
    cat "$HEADER_FILE"
    echo ""
    echo "=== Response Body ==="
    echo "$BODY"
    ;;
  *)
    # Treat as a custom -w format string
    curl "${CURL_ARGS[@]}" -o /dev/null -w "$OUTPUT" "$CURL_URL"
    ;;
esac

EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "curl exited with code $EXIT_CODE" >&2
  case $EXIT_CODE in
    6)  echo "Could not resolve host" >&2 ;;
    7)  echo "Failed to connect" >&2 ;;
    22) echo "HTTP error (server returned >= 400)" >&2 ;;
    28) echo "Operation timed out" >&2 ;;
    35) echo "SSL connect error" >&2 ;;
    51) echo "SSL peer certificate problem" >&2 ;;
    52) echo "Empty reply from server" >&2 ;;
    56) echo "Failure receiving data" >&2 ;;
  esac
  exit $EXIT_CODE
fi
