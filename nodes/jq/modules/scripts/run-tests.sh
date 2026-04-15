#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required but was not found on PATH" >&2
  exit 127
}

if [[ -z "${JQ_TEST_FILE:-}" ]]; then
  echo "Error: JQ_TEST_FILE is required" >&2
  exit 1
fi

test_dir=$(cd "$(dirname "$JQ_TEST_FILE")" && pwd)
test_file=$(basename "$JQ_TEST_FILE")

JQ_ARGS=()
if [[ -n "${JQ_LIBRARY_PATH:-}" ]]; then
  old_ifs="$IFS"
  IFS=":"
  read -r -a path_items <<< "${JQ_LIBRARY_PATH}"
  IFS="$old_ifs"
  for item in "${path_items[@]}"; do
    [[ -n "$item" ]] || continue
    JQ_ARGS+=(-L "$item")
  done
fi

cd "$test_dir"
exec jq "${JQ_ARGS[@]}" --run-tests "$test_file"
