#!/usr/bin/env bash
set -euo pipefail

ACTION=""
PACKAGES=()
EDIT_DIR=""
PATCH_DIR=""
PATCHES_DIR=""
IGNORE_EXISTING=""

usage() {
  cat <<'EOF'
Usage: manage-patch.sh --action <start|commit|remove> [options]

Options:
  --package <spec>            Exact package spec, repeatable for remove
  --edit-dir <dir>            Directory for pnpm patch extraction
  --patch-dir <dir>           Edited patch directory for patch-commit
  --patches-dir <dir>         Target directory for committed patch files
  --ignore-existing           Ignore an existing patch when starting

Examples:
  manage-patch.sh --action start --package esbuild@0.25.1 --edit-dir ./.patches/esbuild
  manage-patch.sh --action commit --patch-dir ./.patches/esbuild
  manage-patch.sh --action remove --package esbuild@0.25.1
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
    --package)
      PACKAGES+=("${2:?missing package value}")
      shift 2
      ;;
    --edit-dir)
      EDIT_DIR="${2:?missing directory value}"
      shift 2
      ;;
    --patch-dir)
      PATCH_DIR="${2:?missing directory value}"
      shift 2
      ;;
    --patches-dir)
      PATCHES_DIR="${2:?missing directory value}"
      shift 2
      ;;
    --ignore-existing)
      IGNORE_EXISTING="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$ACTION" in
  start)
    if [[ ${#PACKAGES[@]} -ne 1 ]]; then
      echo "Error: start requires exactly one --package spec" >&2
      exit 1
    fi
    cmd=(pnpm patch "${PACKAGES[0]}")
    if [[ -n "$EDIT_DIR" ]]; then
      mkdir -p "$EDIT_DIR"
      cmd+=(--edit-dir "$EDIT_DIR")
    fi
    if [[ -n "$IGNORE_EXISTING" ]]; then
      cmd+=(--ignore-existing)
    fi
    ;;
  commit)
    if [[ -z "$PATCH_DIR" ]]; then
      echo "Error: commit requires --patch-dir" >&2
      exit 1
    fi
    cmd=(pnpm patch-commit "$PATCH_DIR")
    if [[ -n "$PATCHES_DIR" ]]; then
      mkdir -p "$PATCHES_DIR"
      cmd+=(--patches-dir "$PATCHES_DIR")
    fi
    ;;
  remove)
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
      echo "Error: remove requires at least one --package spec" >&2
      exit 1
    fi
    cmd=(pnpm patch-remove "${PACKAGES[@]}")
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
