#!/usr/bin/env bash
set -euo pipefail

ACTION=""
FILTERS=()
TARGET_PACKAGE=""
DEPENDENCY=""
SCRIPT_NAME=""
SCRIPT_ARGS=()
PARALLEL=""
IF_PRESENT=""

usage() {
  cat <<'EOF'
Usage: manage-workspace.sh --action <list|run|add-workspace-dep|why|validate> [options] [-- args...]

Options:
  --filter <selector>         Repeatable pnpm filter selector
  --package <name>            Target package for add-workspace-dep
  --dependency <name>         Dependency for add-workspace-dep or why
  --script <name>             Script name for run
  --parallel                  Run recursive tasks in parallel
  --if-present                Ignore packages that do not define the script

Examples:
  manage-workspace.sh --action list
  manage-workspace.sh --action run --script build --filter @acme/web...
  manage-workspace.sh --action add-workspace-dep --package @acme/web --dependency @acme/ui
  manage-workspace.sh --action why --dependency react
  manage-workspace.sh --action validate
EOF
}

if ! command -v pnpm >/dev/null 2>&1; then
  echo "Error: pnpm is not installed or not on PATH" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:?missing action value}"
      shift 2
      ;;
    --filter)
      FILTERS+=("${2:?missing filter value}")
      shift 2
      ;;
    --package)
      TARGET_PACKAGE="${2:?missing package value}"
      shift 2
      ;;
    --dependency)
      DEPENDENCY="${2:?missing dependency value}"
      shift 2
      ;;
    --script)
      SCRIPT_NAME="${2:?missing script value}"
      shift 2
      ;;
    --parallel)
      PARALLEL="true"
      shift
      ;;
    --if-present)
      IF_PRESENT="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        SCRIPT_ARGS+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage
      exit 1
      ;;
    *)
      SCRIPT_ARGS+=("$1")
      shift
      ;;
  esac
done

case "$ACTION" in
  list)
    cmd=(pnpm -r list --depth -1)
    ;;
  run)
    if [[ -z "$SCRIPT_NAME" ]]; then
      echo "Error: --script is required for run" >&2
      exit 1
    fi
    cmd=(pnpm -r)
    for filter in "${FILTERS[@]}"; do
      cmd+=(--filter "$filter")
    done
    if [[ -n "$PARALLEL" ]]; then
      cmd+=(--parallel)
    fi
    cmd+=(run)
    if [[ -n "$IF_PRESENT" ]]; then
      cmd+=(--if-present)
    fi
    cmd+=("$SCRIPT_NAME")
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      cmd+=(-- "${SCRIPT_ARGS[@]}")
    fi
    ;;
  add-workspace-dep)
    if [[ -z "$TARGET_PACKAGE" || -z "$DEPENDENCY" ]]; then
      echo "Error: --package and --dependency are required for add-workspace-dep" >&2
      exit 1
    fi
    spec="$DEPENDENCY"
    if [[ "$DEPENDENCY" != *"workspace:"* ]]; then
      spec="${DEPENDENCY}@workspace:*"
    fi
    cmd=(pnpm --filter "$TARGET_PACKAGE" add "$spec")
    ;;
  why)
    if [[ -z "$DEPENDENCY" ]]; then
      echo "Error: --dependency is required for why" >&2
      exit 1
    fi
    cmd=(pnpm)
    for filter in "${FILTERS[@]}"; do
      cmd+=(--filter "$filter")
    done
    cmd+=(why "$DEPENDENCY")
    ;;
  validate)
    if [[ ! -f "pnpm-workspace.yaml" ]]; then
      echo "Error: pnpm-workspace.yaml not found in $(pwd)" >&2
      exit 1
    fi
    echo "Workspace file: $(pwd)/pnpm-workspace.yaml"
    if command -v rg >/dev/null 2>&1; then
      echo ""
      echo "Workspace package globs:"
      rg -n '^[[:space:]]*-[[:space:]]' pnpm-workspace.yaml || true
    fi
    if [[ -f "package.json" ]]; then
      echo ""
      echo "Root package manager field:"
      node -e "const p=require('./package.json'); console.log(p.packageManager || '(missing)')"
    fi
    exit 0
    ;;
  *)
    echo "Error: unsupported or missing action" >&2
    usage
    exit 1
    ;;
esac

printf 'Running:'
printf ' %q' "${cmd[@]}"
printf '\n'

exec "${cmd[@]}"
