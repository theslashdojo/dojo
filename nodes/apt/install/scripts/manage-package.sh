#!/usr/bin/env bash
set -euo pipefail

APT_ACTION="${APT_ACTION:?APT_ACTION is required (install|reinstall|remove|purge)}"
APT_PACKAGES="${APT_PACKAGES:?APT_PACKAGES is required (space-separated package specs)}"
APT_ASSUME_YES="${APT_ASSUME_YES:-true}"
APT_NO_RECOMMENDS="${APT_NO_RECOMMENDS:-false}"
APT_TARGET_RELEASE="${APT_TARGET_RELEASE:-}"
APT_SKIP_UPDATE="${APT_SKIP_UPDATE:-false}"
APT_SIMULATE="${APT_SIMULATE:-false}"
APT_QUIET="${APT_QUIET:-false}"
DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

read -r -a PACKAGE_ARGS <<<"$APT_PACKAGES"

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
if [[ -n "$APT_TARGET_RELEASE" ]]; then
  COMMON_FLAGS+=(-t "$APT_TARGET_RELEASE")
fi
if [[ "$APT_SIMULATE" == "true" ]]; then
  COMMON_FLAGS+=(-s)
fi
if [[ "$APT_QUIET" == "true" ]]; then
  COMMON_FLAGS+=(-q)
fi

INSTALL_FLAGS=("${COMMON_FLAGS[@]}")
if [[ "$APT_NO_RECOMMENDS" == "true" ]]; then
  INSTALL_FLAGS+=(--no-install-recommends)
fi

case "$APT_ACTION" in
  install)
    if [[ "$APT_SKIP_UPDATE" != "true" ]]; then
      run_apt update
    fi
    run_apt "${INSTALL_FLAGS[@]}" install "${PACKAGE_ARGS[@]}"
    ;;
  reinstall)
    if [[ "$APT_SKIP_UPDATE" != "true" ]]; then
      run_apt update
    fi
    run_apt "${INSTALL_FLAGS[@]}" install --reinstall "${PACKAGE_ARGS[@]}"
    ;;
  remove)
    run_apt "${COMMON_FLAGS[@]}" remove "${PACKAGE_ARGS[@]}"
    ;;
  purge)
    run_apt "${COMMON_FLAGS[@]}" purge "${PACKAGE_ARGS[@]}"
    ;;
  *)
    echo "ERROR: unknown APT_ACTION '$APT_ACTION'" >&2
    exit 1
    ;;
esac
