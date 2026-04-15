#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
FILTERS=()
PACKAGES=()
ROOT_FLAG=""
RECURSIVE=""
DEV_FLAG=""
PROD_FLAG=""
OPTIONAL_FLAG=""
EXACT_FLAG=""
OFFLINE=""
FROZEN=""
LOCKFILE_ONLY=""
NO_OPTIONAL=""
ALLOW_BUILD=""

usage() {
  cat <<'EOF'
Usage: manage-deps.sh [options] [package...]

Actions:
  --action <install|add|remove|update|fetch|outdated>

Options:
  --filter <selector>           Repeatable pnpm filter selector
  --workspace-root, -w          Target the workspace root when supported
  --recursive, -r               Run recursively across a workspace
  --dev, -D                     Save to devDependencies
  --prod, -P                    Omit devDependencies / save prod dependency
  --optional, -O                Save to optionalDependencies
  --exact, -E                   Save exact version
  --offline                     Use cached store only
  --frozen-lockfile             Refuse lockfile changes
  --lockfile-only               Update lockfile without touching node_modules
  --no-optional                 Skip optional dependencies
  --allow-build <pkg[,pkg]>     Allow build scripts for matching packages

Examples:
  manage-deps.sh --action install --frozen-lockfile
  manage-deps.sh --action add -D typescript vitest
  manage-deps.sh --action add --filter @acme/web react
  manage-deps.sh --action fetch --prod
  manage-deps.sh --action update -r
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
    --workspace-root|-w)
      ROOT_FLAG="true"
      shift
      ;;
    --recursive|-r)
      RECURSIVE="true"
      shift
      ;;
    --dev|-D)
      DEV_FLAG="true"
      shift
      ;;
    --prod|-P)
      PROD_FLAG="true"
      shift
      ;;
    --optional|-O)
      OPTIONAL_FLAG="true"
      shift
      ;;
    --exact|-E)
      EXACT_FLAG="true"
      shift
      ;;
    --offline)
      OFFLINE="true"
      shift
      ;;
    --frozen-lockfile)
      FROZEN="true"
      shift
      ;;
    --lockfile-only)
      LOCKFILE_ONLY="true"
      shift
      ;;
    --no-optional)
      NO_OPTIONAL="true"
      shift
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
        PACKAGES+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage
      exit 1
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

cmd=(pnpm)

if [[ -n "$RECURSIVE" ]]; then
  cmd+=(-r)
fi

for filter in "${FILTERS[@]}"; do
  cmd+=(--filter "$filter")
done

case "$ACTION" in
  install)
    cmd+=(install)
    ;;
  add)
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
      echo "Error: add requires at least one package" >&2
      exit 1
    fi
    if [[ -n "$ROOT_FLAG" ]]; then
      cmd+=(-w)
    fi
    cmd+=(add)
    ;;
  remove)
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
      echo "Error: remove requires at least one package" >&2
      exit 1
    fi
    if [[ -n "$ROOT_FLAG" ]]; then
      cmd+=(-w)
    fi
    cmd+=(remove)
    ;;
  update)
    if [[ -n "$ROOT_FLAG" ]]; then
      cmd+=(-w)
    fi
    cmd+=(update)
    ;;
  fetch)
    if [[ ! -f "pnpm-lock.yaml" ]]; then
      echo "Error: fetch requires pnpm-lock.yaml in the current directory" >&2
      exit 1
    fi
    cmd+=(fetch)
    ;;
  outdated)
    cmd+=(outdated)
    ;;
  *)
    echo "Error: unsupported action '$ACTION'" >&2
    usage
    exit 1
    ;;
esac

if [[ -n "$DEV_FLAG" ]]; then
  cmd+=(-D)
fi
if [[ -n "$PROD_FLAG" ]]; then
  cmd+=(-P)
fi
if [[ -n "$OPTIONAL_FLAG" ]]; then
  cmd+=(-O)
fi
if [[ -n "$EXACT_FLAG" ]]; then
  cmd+=(-E)
fi
if [[ -n "$OFFLINE" ]]; then
  cmd+=(--offline)
fi
if [[ -n "$FROZEN" ]]; then
  cmd+=(--frozen-lockfile)
fi
if [[ -n "$LOCKFILE_ONLY" ]]; then
  cmd+=(--lockfile-only)
fi
if [[ -n "$NO_OPTIONAL" ]]; then
  cmd+=(--no-optional)
fi
if [[ -n "$ALLOW_BUILD" ]]; then
  cmd+=(--allow-build="$ALLOW_BUILD")
fi
if [[ ${#PACKAGES[@]} -gt 0 ]]; then
  cmd+=("${PACKAGES[@]}")
fi

printf 'Running:'
printf ' %q' "${cmd[@]}"
printf '\n'

exec "${cmd[@]}"
