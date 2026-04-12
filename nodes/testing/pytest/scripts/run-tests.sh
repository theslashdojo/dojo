#!/usr/bin/env bash
# Run pytest with common options, virtualenv activation, and CI support.
#
# Usage:
#   bash run-tests.sh [test_path] [extra_args...]
#   bash run-tests.sh tests/test_api.py -v -x
#   bash run-tests.sh tests/ --cov=src
#
# Environment variables:
#   TEST_PATH     — path to tests (default: "tests" or first positional arg)
#   VERBOSE       — "true" for -v --tb=short (default: "true")
#   STOP_FIRST    — "true" for -x (default: "false")
#   COVER         — "true" for --cov (default: "false")
#   COV_SOURCE    — coverage source directory (default: "src")
#   COV_THRESHOLD — minimum coverage percentage (default: "")
#   PARALLEL      — "true" for -n auto (default: "false")
#   MARKERS       — marker expression, e.g. "not slow" (default: "")
#   PATTERN       — name pattern filter -k (default: "")
#   CI            — set to any value to enable CI mode
#   PYTEST_EXTRA  — extra arguments passed directly to pytest
#
# Exits with pytest's exit code.

set -euo pipefail

# ---------------------------------------------------------------------------
# Virtualenv activation
# ---------------------------------------------------------------------------
activate_venv() {
    local venv_dirs=(".venv" "venv" ".env")
    for dir in "${venv_dirs[@]}"; do
        if [ -f "$dir/bin/activate" ]; then
            echo "[run-tests] Activating virtualenv: $dir"
            # shellcheck disable=SC1091
            source "$dir/bin/activate"
            return 0
        fi
    done
    # Check if we're already inside a virtualenv
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        echo "[run-tests] Using active virtualenv: $VIRTUAL_ENV"
        return 0
    fi
    echo "[run-tests] No virtualenv found; using system Python"
    return 0
}

# ---------------------------------------------------------------------------
# Verify pytest is available
# ---------------------------------------------------------------------------
check_pytest() {
    if ! command -v pytest &>/dev/null; then
        if python -m pytest --version &>/dev/null 2>&1; then
            # pytest is importable but not on PATH — use module invocation
            PYTEST_CMD="python -m pytest"
            return 0
        fi
        echo "[run-tests] ERROR: pytest is not installed."
        echo "[run-tests] Install with: pip install pytest"
        exit 1
    fi
    PYTEST_CMD="pytest"
    return 0
}

# ---------------------------------------------------------------------------
# Parse positional args: first arg may be the test path
# ---------------------------------------------------------------------------
EXTRA_POSITIONAL=()
if [ $# -gt 0 ]; then
    # If the first argument looks like a path (file/dir, no leading dash), use it as test path
    if [[ "$1" != -* ]]; then
        TEST_PATH="${TEST_PATH:-$1}"
        shift
    fi
    # Remaining positional args are passed through
    EXTRA_POSITIONAL=("$@")
fi

# ---------------------------------------------------------------------------
# Configuration with defaults
# ---------------------------------------------------------------------------
TEST_PATH="${TEST_PATH:-tests}"
VERBOSE="${VERBOSE:-true}"
STOP_FIRST="${STOP_FIRST:-false}"
COVER="${COVER:-false}"
COV_SOURCE="${COV_SOURCE:-src}"
COV_THRESHOLD="${COV_THRESHOLD:-}"
PARALLEL="${PARALLEL:-false}"
MARKERS="${MARKERS:-}"
PATTERN="${PATTERN:-}"
PYTEST_EXTRA="${PYTEST_EXTRA:-}"

# ---------------------------------------------------------------------------
# Activate virtualenv and verify pytest
# ---------------------------------------------------------------------------
activate_venv
check_pytest

# ---------------------------------------------------------------------------
# Build argument list
# ---------------------------------------------------------------------------
ARGS=()

# Test path
if [ -n "$TEST_PATH" ]; then
    ARGS+=("$TEST_PATH")
fi

# Verbose mode
if [ "$VERBOSE" = "true" ]; then
    ARGS+=("-v" "--tb=short")
fi

# Stop on first failure
if [ "$STOP_FIRST" = "true" ]; then
    ARGS+=("-x")
fi

# Coverage
if [ "$COVER" = "true" ]; then
    if python -c "import pytest_cov" 2>/dev/null; then
        ARGS+=("--cov=$COV_SOURCE" "--cov-report=term-missing")
        if [ -n "$COV_THRESHOLD" ]; then
            ARGS+=("--cov-fail-under=$COV_THRESHOLD")
        fi
    else
        echo "[run-tests] WARNING: pytest-cov not installed, skipping coverage"
        echo "[run-tests] Install with: pip install pytest-cov"
    fi
fi

# Parallel execution
if [ "$PARALLEL" = "true" ]; then
    if python -c "import xdist" 2>/dev/null; then
        ARGS+=("-n" "auto")
    else
        echo "[run-tests] WARNING: pytest-xdist not installed, skipping parallel execution"
        echo "[run-tests] Install with: pip install pytest-xdist"
    fi
fi

# Marker filter
if [ -n "$MARKERS" ]; then
    ARGS+=("-m" "$MARKERS")
fi

# Name pattern filter
if [ -n "$PATTERN" ]; then
    ARGS+=("-k" "$PATTERN")
fi

# CI mode adjustments
if [ -n "${CI:-}" ]; then
    echo "[run-tests] CI mode detected"
    # Ensure color output in CI (many CI systems support ANSI)
    ARGS+=("--color=yes")
    # Add JUnit XML for CI reporting if not already specified
    if [[ ! " ${EXTRA_POSITIONAL[*]:-} ${PYTEST_EXTRA:-} " =~ --junitxml ]]; then
        ARGS+=("--junitxml=test-results.xml")
    fi
    # Add coverage XML for CI tools (Codecov, Coveralls)
    if [ "$COVER" = "true" ] && python -c "import pytest_cov" 2>/dev/null; then
        ARGS+=("--cov-report=xml")
    fi
fi

# Extra args from environment variable (space-separated)
if [ -n "$PYTEST_EXTRA" ]; then
    # shellcheck disable=SC2206
    ARGS+=($PYTEST_EXTRA)
fi

# Extra positional args from command line
if [ ${#EXTRA_POSITIONAL[@]} -gt 0 ]; then
    ARGS+=("${EXTRA_POSITIONAL[@]}")
fi

# ---------------------------------------------------------------------------
# Run pytest
# ---------------------------------------------------------------------------
echo "[run-tests] Running: $PYTEST_CMD ${ARGS[*]}"
echo "---"

# Execute and capture exit code
set +e
$PYTEST_CMD "${ARGS[@]}"
EXIT_CODE=$?
set -e

# ---------------------------------------------------------------------------
# Report exit code meaning
# ---------------------------------------------------------------------------
echo "---"
case $EXIT_CODE in
    0) echo "[run-tests] All tests passed." ;;
    1) echo "[run-tests] Some tests failed." ;;
    2) echo "[run-tests] Test execution was interrupted." ;;
    3) echo "[run-tests] Internal error during test collection." ;;
    4) echo "[run-tests] pytest command line usage error." ;;
    5) echo "[run-tests] No tests were collected." ;;
    *) echo "[run-tests] pytest exited with code $EXIT_CODE." ;;
esac

exit $EXIT_CODE
