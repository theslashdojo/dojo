#!/usr/bin/env bash
set -euo pipefail

# Run an arbitrary bash command and return structured output.
# Usage: ./run-command.sh <command> [working_directory] [timeout_seconds]
#
# Outputs JSON with stdout, stderr, and exit_code fields.

COMMAND="${1:?Usage: $0 <command> [working_directory] [timeout_seconds]}"
WORKDIR="${2:-.}"
TIMEOUT="${3:-120}"

# Validate working directory
if [[ ! -d "$WORKDIR" ]]; then
  echo "{\"stdout\":\"\",\"stderr\":\"Working directory does not exist: $WORKDIR\",\"exit_code\":1}"
  exit 1
fi

# Create temp files for capturing output
stdout_file=$(mktemp)
stderr_file=$(mktemp)
trap 'rm -f "$stdout_file" "$stderr_file"' EXIT

# Execute command with timeout
set +e
cd "$WORKDIR"
timeout "$TIMEOUT" bash -c "$COMMAND" >"$stdout_file" 2>"$stderr_file"
exit_code=$?
set -e

# Handle timeout (exit code 124)
if [[ $exit_code -eq 124 ]]; then
  echo "Command timed out after ${TIMEOUT}s" >> "$stderr_file"
fi

# Read outputs, escaping for JSON
stdout_content=$(<"$stdout_file")
stderr_content=$(<"$stderr_file")

# Output JSON (using jq if available, otherwise manual escaping)
if command -v jq &>/dev/null; then
  jq -n \
    --arg stdout "$stdout_content" \
    --arg stderr "$stderr_content" \
    --argjson exit_code "$exit_code" \
    '{stdout: $stdout, stderr: $stderr, exit_code: $exit_code}'
else
  # Manual JSON escaping for environments without jq
  escape_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
  }
  printf '{"stdout":"%s","stderr":"%s","exit_code":%d}\n' \
    "$(escape_json "$stdout_content")" \
    "$(escape_json "$stderr_content")" \
    "$exit_code"
fi
