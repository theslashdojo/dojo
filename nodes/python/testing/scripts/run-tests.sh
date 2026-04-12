#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${1:-tests}"
MARKERS="${2:-}"
VERBOSE="${3:-true}"

ARGS=("$TEST_PATH")

if [ "$VERBOSE" = "true" ]; then
  ARGS+=("-v" "--tb=short")
fi

if [ -n "$MARKERS" ]; then
  ARGS+=("-m" "$MARKERS")
fi

if python -c "import pytest_cov" 2>/dev/null; then
  ARGS+=("--cov=src" "--cov-report=term-missing")
fi

echo "Running: pytest ${ARGS[*]}"
pytest "${ARGS[@]}"
