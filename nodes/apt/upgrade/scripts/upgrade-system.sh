#!/usr/bin/env bash
set -euo pipefail

APT_UPGRADE_ACTION="${APT_UPGRADE_ACTION:?APT_UPGRADE_ACTION is required (update|preview|upgrade|dist-upgrade|autoremove|autoclean|clean|distclean)}"
APT_ASSUME_YES="${APT_ASSUME_YES:-true}"
APT_SKIP_UPDATE="${APT_SKIP_UPDATE:-false}"
APT_SIMULATE="${APT_SIMULATE:-false}"
APT_QUIET="${APT_QUIET:-false}"
DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

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
if [[ "$APT_QUIET" == "true" ]]; then
  COMMON_FLAGS+=(-q)
fi

refresh_if_needed() {
  if [[ "$APT_SKIP_UPDATE" != "true" ]]; then
    run_apt update
  fi
}

case "$APT_UPGRADE_ACTION" in
  update)
    run_apt update
    ;;
  preview)
    refresh_if_needed
    run_apt -s upgrade
    ;;
  upgrade)
    refresh_if_needed
    run_apt "${COMMON_FLAGS[@]}" upgrade
    ;;
  dist-upgrade)
    refresh_if_needed
    run_apt "${COMMON_FLAGS[@]}" dist-upgrade
    ;;
  autoremove)
    run_apt "${COMMON_FLAGS[@]}" autoremove --purge
    ;;
  autoclean)
    run_apt autoclean
    ;;
  clean)
    run_apt clean
    ;;
  distclean)
    run_apt distclean
    ;;
  *)
    echo "ERROR: unknown APT_UPGRADE_ACTION '$APT_UPGRADE_ACTION'" >&2
    exit 1
    ;;
esac
