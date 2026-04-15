#!/usr/bin/env bash
set -euo pipefail

FILTERS=()
EXTRA_PACKAGES=()
RECURSIVE=""
PARALLEL=""
IF_PRESENT=""
RESUME_FROM=""
REPORT_SUMMARY=""
SHELL_MODE=""
ALLOW_BUILD=""
MODE=""
TARGET=""
ARGS=()

usage() {
  cat <<'EOF'
Usage: run-command.sh [options] <run|exec|dlx> <target> [-- args...]

Options:
  --filter <selector>         Repeatable pnpm filter selector
  --recursive, -r             Run across a workspace
  --parallel                  Ignore topological ordering for recursive execution
  --if-present                Ignore missing scripts for run
  --resume-from <package>     Resume recursive exec from a package
  --report-summary            Emit pnpm summary data when supported
  --shell-mode, -c            Run command inside a shell
  --package <name>            Extra package for dlx
  --allow-build <pkg[,pkg]>   Allow build scripts for dlx installs

Examples:
  run-command.sh run build
  run-command.sh --recursive --filter @acme/* run lint
  run-command.sh exec tsc -- --noEmit
  run-command.sh --shell-mode exec 'echo $PNPM_PACKAGE_NAME'
  run-command.sh dlx create-vue -- my-app
EOF
}

if ! command -v pnpm >/dev/null 2>&1; then
  echo "Error: pnpm is not installed or not on PATH" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTERS+=("${2:?missing filter value}")
      shift 2
      ;;
    --recursive|-r)
      RECURSIVE="true"
      shift
      ;;
    --parallel)
      PARALLEL="true"
      shift
      ;;
    --if-present)
      IF_PRESENT="true"
      shift
      ;;
    --resume-from)
      RESUME_FROM="${2:?missing package value}"
      shift 2
      ;;
    --report-summary)
      REPORT_SUMMARY="true"
      shift
      ;;
    --shell-mode|-c)
      SHELL_MODE="true"
      shift
      ;;
    --package)
      EXTRA_PACKAGES+=("${2:?missing package value}")
      shift 2
      ;;
    --allow-build)
      ALLOW_BUILD="${2:?missing package list}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        ARGS+=("$1")
        shift
      done
      ;;
    run|exec|dlx)
      MODE="$1"
      TARGET="${2:-}"
      if [[ -z "$TARGET" ]]; then
        echo "Error: missing target for $MODE" >&2
        exit 1
      fi
      shift 2
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  usage
  exit 1
fi

cmd=(pnpm)

if [[ "$MODE" != "dlx" && -n "$RECURSIVE" ]]; then
  cmd+=(-r)
fi

for filter in "${FILTERS[@]}"; do
  cmd+=(--filter "$filter")
done

if [[ -n "$PARALLEL" ]]; then
  cmd+=(--parallel)
fi
if [[ -n "$RESUME_FROM" ]]; then
  cmd+=(--resume-from "$RESUME_FROM")
fi
if [[ -n "$REPORT_SUMMARY" ]]; then
  cmd+=(--report-summary)
fi
if [[ -n "$SHELL_MODE" ]]; then
  cmd+=(-c)
fi
for pkg in "${EXTRA_PACKAGES[@]}"; do
  cmd+=(--package "$pkg")
done
if [[ -n "$ALLOW_BUILD" ]]; then
  cmd+=(--allow-build="$ALLOW_BUILD")
fi

case "$MODE" in
  run)
    cmd+=(run)
    if [[ -n "$IF_PRESENT" ]]; then
      cmd+=(--if-present)
    fi
    cmd+=("$TARGET")
    ;;
  exec)
    cmd+=(exec "$TARGET")
    ;;
  dlx)
    cmd+=(dlx "$TARGET")
    ;;
esac

if [[ ${#ARGS[@]} -gt 0 ]]; then
  cmd+=("${ARGS[@]}")
fi

printf 'Running:'
printf ' %q' "${cmd[@]}"
printf '\n'

exec "${cmd[@]}"
