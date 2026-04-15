#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: open-trace.sh <trace.zip|trace-url>" >&2
  exit 2
fi

exec npx playwright show-trace "$1"
