#!/usr/bin/env bash
set -euo pipefail

# Run Vitest tests with automatic local detection and flexible flags.
#
# Usage:
#   ./run-tests.sh [test_pattern] [flags...]
#
# Arguments:
#   test_pattern   Optional file path or name pattern to filter tests
#
# Flags (passed through directly):
#   --coverage     Enable code coverage reporting
#   --watch        Enable watch mode (re-run on file changes)
#   --ui           Open browser-based UI dashboard
#   --run          Run once and exit (default in CI)
#   --update       Update snapshots
#   --reporter=X   Set output reporter (default, verbose, json, junit)
#   --project=X    Run a specific workspace project
#   --bail=N       Stop after N failures
#   --changed      Run only tests affected by changed files
#
# Environment variables:
#   TEST_PATTERN       Test file or name pattern (alternative to positional arg)
#   VITEST_COVERAGE    Set to 'true' to enable coverage
#   VITEST_WATCH       Set to 'true' to enable watch mode
#   VITEST_UI          Set to 'true' to enable browser UI
#   VITEST_RUN         Set to 'true' to force single-pass run mode
#   CI                 Auto-detected; forces run mode when set
#
# Examples:
#   ./run-tests.sh                              # run all tests (run mode in CI, watch in dev)
#   ./run-tests.sh src/utils                    # filter by path
#   ./run-tests.sh --coverage                   # with coverage
#   ./run-tests.sh src/api --coverage --run     # specific tests, coverage, single pass
#   VITEST_COVERAGE=true ./run-tests.sh         # coverage via env var
#   ./run-tests.sh --watch                      # explicit watch mode
#   ./run-tests.sh --ui                         # open UI dashboard

# --- Detect vitest installation ---

VITEST_BIN=""

# 1. Check local node_modules (npx-style)
if [ -x "./node_modules/.bin/vitest" ]; then
  VITEST_BIN="./node_modules/.bin/vitest"
# 2. Check if vitest is available via PATH (global install or pnpm/yarn pnp)
elif command -v vitest &>/dev/null; then
  VITEST_BIN="vitest"
# 3. Try npx as a fallback (downloads if needed)
elif command -v npx &>/dev/null; then
  VITEST_BIN="npx vitest"
else
  echo "Error: vitest is not installed." >&2
  echo "Install it with: npm install -D vitest" >&2
  exit 1
fi

# --- Build argument list ---

ARGS=()
PATTERN=""
HAS_RUN_FLAG=false
HAS_WATCH_FLAG=false
HAS_UI_FLAG=false
HAS_COVERAGE_FLAG=false

# Parse positional args and flags
for arg in "$@"; do
  case "$arg" in
    --run)
      HAS_RUN_FLAG=true
      ARGS+=("$arg")
      ;;
    --watch)
      HAS_WATCH_FLAG=true
      ARGS+=("$arg")
      ;;
    --ui)
      HAS_UI_FLAG=true
      ARGS+=("$arg")
      ;;
    --coverage)
      HAS_COVERAGE_FLAG=true
      ARGS+=("$arg")
      ;;
    --*)
      ARGS+=("$arg")
      ;;
    *)
      # First non-flag argument is the test pattern
      if [ -z "$PATTERN" ]; then
        PATTERN="$arg"
      else
        ARGS+=("$arg")
      fi
      ;;
  esac
done

# Apply environment variable overrides (only if flag not already set)
if [ "${VITEST_COVERAGE:-}" = "true" ] && [ "$HAS_COVERAGE_FLAG" = false ]; then
  ARGS+=("--coverage")
  HAS_COVERAGE_FLAG=true
fi

if [ "${VITEST_UI:-}" = "true" ] && [ "$HAS_UI_FLAG" = false ]; then
  ARGS+=("--ui")
  HAS_UI_FLAG=true
fi

if [ "${VITEST_WATCH:-}" = "true" ] && [ "$HAS_WATCH_FLAG" = false ]; then
  ARGS+=("--watch")
  HAS_WATCH_FLAG=true
fi

if [ "${VITEST_RUN:-}" = "true" ] && [ "$HAS_RUN_FLAG" = false ]; then
  ARGS+=("--run")
  HAS_RUN_FLAG=true
fi

# Use TEST_PATTERN env var if no positional pattern was provided
if [ -z "$PATTERN" ] && [ -n "${TEST_PATTERN:-}" ]; then
  PATTERN="$TEST_PATTERN"
fi

# --- Determine run mode ---

# In CI or when no explicit mode is set, default to run mode (no watch)
# UI and watch mode take precedence if explicitly requested
if [ "$HAS_UI_FLAG" = false ] && [ "$HAS_WATCH_FLAG" = false ] && [ "$HAS_RUN_FLAG" = false ]; then
  if [ -n "${CI:-}" ]; then
    # CI environment detected: always run once
    ARGS+=("run")
  else
    # Interactive dev: default to run mode for scripts (watch is better from terminal directly)
    ARGS+=("run")
  fi
fi

# --- Assemble final command ---

FINAL_ARGS=()

# Add the pattern first if present (vitest expects it before flags)
if [ -n "$PATTERN" ]; then
  FINAL_ARGS+=("$PATTERN")
fi

# Append all other flags
FINAL_ARGS+=("${ARGS[@]}")

# --- Execute ---

echo "Running: $VITEST_BIN ${FINAL_ARGS[*]}"
exec $VITEST_BIN "${FINAL_ARGS[@]}"
