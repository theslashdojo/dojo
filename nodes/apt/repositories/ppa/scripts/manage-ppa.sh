#!/usr/bin/env bash
set -euo pipefail

APT_PPA_ACTION="${APT_PPA_ACTION:?APT_PPA_ACTION is required (add|remove|list)}"
APT_PPA="${APT_PPA:-}"
APT_ASSUME_YES="${APT_ASSUME_YES:-true}"
APT_NO_UPDATE="${APT_NO_UPDATE:-false}"

if ! command -v add-apt-repository >/dev/null 2>&1; then
  echo "ERROR: add-apt-repository is not installed. Install software-properties-common first." >&2
  exit 1
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

normalize_ppa() {
  if [[ -z "$APT_PPA" ]]; then
    echo "ERROR: APT_PPA is required for add and remove" >&2
    exit 1
  fi
  if [[ "$APT_PPA" == ppa:* ]]; then
    printf '%s
' "$APT_PPA"
  else
    printf 'ppa:%s
' "$APT_PPA"
  fi
}

COMMON_FLAGS=()
if [[ "$APT_ASSUME_YES" == "true" ]]; then
  COMMON_FLAGS+=(-y)
fi
if [[ "$APT_NO_UPDATE" == "true" ]]; then
  COMMON_FLAGS+=(-n)
fi

case "$APT_PPA_ACTION" in
  add)
    ref="$(normalize_ppa)"
    "${SUDO[@]}" add-apt-repository "${COMMON_FLAGS[@]}" "$ref"
    ;;
  remove)
    ref="$(normalize_ppa)"
    "${SUDO[@]}" add-apt-repository -r "${COMMON_FLAGS[@]}" "$ref"
    ;;
  list)
    "${SUDO[@]}" add-apt-repository -L
    ;;
  *)
    echo "ERROR: unknown APT_PPA_ACTION '$APT_PPA_ACTION'" >&2
    exit 1
    ;;
esac
