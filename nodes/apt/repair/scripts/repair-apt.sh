#!/usr/bin/env bash
set -euo pipefail

APT_REPAIR_ACTION="${APT_REPAIR_ACTION:?APT_REPAIR_ACTION is required (check|configure-pending|fix-broken|fix-missing|locks)}"
APT_PACKAGES="${APT_PACKAGES:-}"
APT_ASSUME_YES="${APT_ASSUME_YES:-true}"
APT_SIMULATE="${APT_SIMULATE:-false}"
DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

PACKAGE_ARGS=()
if [[ -n "$APT_PACKAGES" ]]; then
  read -r -a PACKAGE_ARGS <<<"$APT_PACKAGES"
fi

SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
  else
    echo "ERROR: root privileges are required; install sudo or run as root" >&2
    exit 1
  fi
fi

run_apt() {
  env DEBIAN_FRONTEND="$DEBIAN_FRONTEND" "${SUDO[@]}" apt-get "$@"
}

COMMON_FLAGS=()
if [[ "$APT_ASSUME_YES" == "true" ]]; then
  COMMON_FLAGS+=(-y)
fi
if [[ "$APT_SIMULATE" == "true" ]]; then
  COMMON_FLAGS+=(-s)
fi

case "$APT_REPAIR_ACTION" in
  check)
    run_apt check
    ;;
  configure-pending)
    "${SUDO[@]}" dpkg --configure -a
    ;;
  fix-broken)
    run_apt "${COMMON_FLAGS[@]}" install -f
    ;;
  fix-missing)
    if [[ "${#PACKAGE_ARGS[@]}" -eq 0 ]]; then
      echo "ERROR: set APT_PACKAGES for fix-missing" >&2
      exit 1
    fi
    run_apt "${COMMON_FLAGS[@]}" --fix-missing install "${PACKAGE_ARGS[@]}"
    ;;
  locks)
    lock_files=(
      /var/lib/dpkg/lock-frontend
      /var/lib/dpkg/lock
      /var/lib/apt/lists/lock
      /var/cache/apt/archives/lock
    )
    found=false
    for lock_file in "${lock_files[@]}"; do
      if [[ -e "$lock_file" ]]; then
        found=true
        echo "=== $lock_file ==="
        if command -v lsof >/dev/null 2>&1; then
          "${SUDO[@]}" lsof "$lock_file" || true
        elif command -v fuser >/dev/null 2>&1; then
          "${SUDO[@]}" fuser -v "$lock_file" || true
        else
          echo "Install lsof or psmisc to inspect the owning process."
        fi
        echo
      fi
    done
    if [[ "$found" != "true" ]]; then
      echo "No standard APT lock files found."
    fi
    ;;
  *)
    echo "ERROR: unknown APT_REPAIR_ACTION '$APT_REPAIR_ACTION'" >&2
    exit 1
    ;;
esac
