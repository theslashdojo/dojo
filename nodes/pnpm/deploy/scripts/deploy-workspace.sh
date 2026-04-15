#!/usr/bin/env bash
set -euo pipefail

FILTER=""
DEST=""
PROD=""
DEV=""
NO_OPTIONAL=""
LEGACY=""
AUTO_LEGACY="true"

usage() {
  cat <<'EOF'
Usage: deploy-workspace.sh --filter <selector> --dest <dir> [options]

Options:
  --prod, -P                  Exclude devDependencies from deploy output
  --dev, -D                   Include only devDependencies
  --no-optional               Exclude optionalDependencies
  --legacy                    Force the legacy deploy implementation
  --no-auto-legacy            Disable automatic --legacy fallback

Examples:
  deploy-workspace.sh --filter @acme/web --dest ./.deploy/web --prod
  deploy-workspace.sh --filter ./apps/worker --dest /tmp/worker --legacy
EOF
}

if ! command -v pnpm >/dev/null 2>&1; then
  echo "Error: pnpm is not installed or not on PATH" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="${2:?missing filter selector}"
      shift 2
      ;;
    --dest)
      DEST="${2:?missing destination path}"
      shift 2
      ;;
    --prod|-P)
      PROD="true"
      shift
      ;;
    --dev|-D)
      DEV="true"
      shift
      ;;
    --no-optional)
      NO_OPTIONAL="true"
      shift
      ;;
    --legacy)
      LEGACY="true"
      AUTO_LEGACY=""
      shift
      ;;
    --no-auto-legacy)
      AUTO_LEGACY=""
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

if [[ -z "$FILTER" || -z "$DEST" ]]; then
  usage
  exit 1
fi

if [[ -n "$PROD" && -n "$DEV" ]]; then
  echo "Error: choose either --prod or --dev, not both" >&2
  exit 1
fi

if [[ -n "$AUTO_LEGACY" && -f "pnpm-workspace.yaml" ]]; then
  if ! grep -Eq 'inject-workspace-packages:[[:space:]]*true|injectWorkspacePackages:[[:space:]]*true' pnpm-workspace.yaml; then
    LEGACY="true"
  fi
fi

mkdir -p "$DEST"

cmd=(pnpm --filter "$FILTER")
if [[ -n "$DEV" ]]; then
  cmd+=(-D)
fi
if [[ -n "$PROD" ]]; then
  cmd+=(-P)
fi
cmd+=(deploy)
if [[ -n "$LEGACY" ]]; then
  cmd+=(--legacy)
fi
if [[ -n "$NO_OPTIONAL" ]]; then
  cmd+=(--no-optional)
fi
cmd+=("$DEST")

printf 'Running:'
printf ' %q' "${cmd[@]}"
printf '\n'

exec "${cmd[@]}"
