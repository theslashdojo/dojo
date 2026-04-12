#!/usr/bin/env bash
set -euo pipefail

# Run Jest tests with automatic detection of installation method and CI environment.
#
# Usage:
#   ./run-tests.sh [test_pattern] [flags...]
#
# Arguments:
#   test_pattern    Optional file path or name pattern to match tests (e.g. "user-service", "src/utils")
#
# Flags (can be combined in any order):
#   --coverage      Enable code coverage reporting
#   --watch         Enable interactive watch mode (disabled in CI)
#   --verbose       Show individual test results
#   --bail          Stop after first test suite failure
#   --update        Update outdated snapshots (-u)
#   --ci            Force CI mode (no watch, fail on new snapshots)
#   --config PATH   Path to jest config file
#
# Environment:
#   CI=true         Automatically detected; disables watch mode, enables CI behavior
#   NODE_ENV        Set to "test" if not already set
#
# Examples:
#   ./run-tests.sh                          # run all tests
#   ./run-tests.sh user-service             # run tests matching "user-service"
#   ./run-tests.sh --coverage --verbose     # all tests with coverage and verbose output
#   ./run-tests.sh src/api --watch          # watch tests in src/api
#   ./run-tests.sh --bail --ci              # CI mode, stop on first failure

# --- Detect Jest binary ---

JEST_BIN=""

# Check for local installation (npx-style)
if [[ -x "node_modules/.bin/jest" ]]; then
  JEST_BIN="node_modules/.bin/jest"
# Check for yarn PnP
elif [[ -f ".pnp.cjs" ]] && command -v yarn &>/dev/null; then
  JEST_BIN="yarn jest"
# Check for pnpm
elif [[ -d "node_modules/.pnpm" ]] && command -v pnpx &>/dev/null; then
  JEST_BIN="pnpx jest"
# Check npx availability (will use local or download)
elif command -v npx &>/dev/null; then
  JEST_BIN="npx jest"
# Check global installation
elif command -v jest &>/dev/null; then
  JEST_BIN="jest"
else
  echo "Error: Jest is not installed." >&2
  echo "Install it with: npm install --save-dev jest" >&2
  echo "For TypeScript: npm install --save-dev jest @types/jest ts-jest" >&2
  exit 1
fi

# --- Set NODE_ENV ---

export NODE_ENV="${NODE_ENV:-test}"

# --- Detect CI environment ---

IS_CI="false"
if [[ "${CI:-}" == "true" ]] || [[ "${CI:-}" == "1" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${JENKINS_URL:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] || [[ -n "${CIRCLECI:-}" ]] || [[ -n "${BUILDKITE:-}" ]] || [[ -n "${TRAVIS:-}" ]] || [[ -n "${TF_BUILD:-}" ]]; then
  IS_CI="true"
  export CI="true"
fi

# --- Parse arguments ---

TEST_PATTERN=""
JEST_ARGS=()
WATCH_MODE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --coverage)
      JEST_ARGS+=("--coverage")
      shift
      ;;
    --watch)
      WATCH_MODE="true"
      shift
      ;;
    --verbose)
      JEST_ARGS+=("--verbose")
      shift
      ;;
    --bail)
      JEST_ARGS+=("--bail")
      shift
      ;;
    --update|-u)
      JEST_ARGS+=("--updateSnapshot")
      shift
      ;;
    --ci)
      IS_CI="true"
      export CI="true"
      JEST_ARGS+=("--ci")
      shift
      ;;
    --config)
      if [[ -n "${2:-}" ]]; then
        JEST_ARGS+=("--config" "$2")
        shift 2
      else
        echo "Error: --config requires a path argument" >&2
        exit 1
      fi
      ;;
    --config=*)
      JEST_ARGS+=("--config" "${1#--config=}")
      shift
      ;;
    -*)
      # Pass through any other flags directly to Jest
      JEST_ARGS+=("$1")
      shift
      ;;
    *)
      # First positional argument is the test pattern
      if [[ -z "$TEST_PATTERN" ]]; then
        TEST_PATTERN="$1"
      else
        # Additional positional args passed through
        JEST_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

# --- Apply watch mode ---

if [[ "$WATCH_MODE" == "true" ]]; then
  if [[ "$IS_CI" == "true" ]]; then
    echo "Note: Watch mode disabled in CI environment." >&2
  else
    JEST_ARGS+=("--watch")
  fi
fi

# --- Apply CI-specific defaults ---

if [[ "$IS_CI" == "true" ]]; then
  # Ensure --ci is set (fail on new snapshots, no interactivity)
  if [[ ! " ${JEST_ARGS[*]:-} " =~ " --ci " ]]; then
    JEST_ARGS+=("--ci")
  fi
  # Use --forceExit in CI to prevent hanging on open handles
  if [[ ! " ${JEST_ARGS[*]:-} " =~ " --forceExit " ]]; then
    JEST_ARGS+=("--forceExit")
  fi
fi

# --- Build final command ---

FINAL_ARGS=()

if [[ -n "$TEST_PATTERN" ]]; then
  FINAL_ARGS+=("$TEST_PATTERN")
fi

FINAL_ARGS+=("${JEST_ARGS[@]}")

# --- Print what we're running ---

echo "Jest: ${JEST_BIN}"
if [[ "$IS_CI" == "true" ]]; then
  echo "Mode: CI"
else
  echo "Mode: local"
fi
echo "Command: ${JEST_BIN} ${FINAL_ARGS[*]:-}"
echo "---"

# --- Execute ---

# shellcheck disable=SC2086
exec ${JEST_BIN} "${FINAL_ARGS[@]}"
