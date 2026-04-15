#!/usr/bin/env bash
set -euo pipefail

APT_SEARCH_ACTION="${APT_SEARCH_ACTION:?APT_SEARCH_ACTION is required (search|show|depends|rdepends|policy|madison|unmet|list-installed)}"
APT_QUERY="${APT_QUERY:-}"
APT_PACKAGE="${APT_PACKAGE:-}"
APT_PACKAGES="${APT_PACKAGES:-}"
APT_NAMES_ONLY="${APT_NAMES_ONLY:-true}"
APT_RECURSE="${APT_RECURSE:-false}"
APT_INSTALLED_ONLY="${APT_INSTALLED_ONLY:-false}"

PACKAGE_ARGS=()
if [[ -n "$APT_PACKAGES" ]]; then
  read -r -a PACKAGE_ARGS <<<"$APT_PACKAGES"
elif [[ -n "$APT_PACKAGE" ]]; then
  PACKAGE_ARGS=("$APT_PACKAGE")
fi

require_packages() {
  if [[ "${#PACKAGE_ARGS[@]}" -eq 0 ]]; then
    echo "ERROR: set APT_PACKAGE or APT_PACKAGES for this action" >&2
    exit 1
  fi
}

case "$APT_SEARCH_ACTION" in
  search)
    if [[ -z "$APT_QUERY" ]]; then
      echo "ERROR: APT_QUERY is required for search" >&2
      exit 1
    fi
    CMD=(apt-cache search)
    if [[ "$APT_NAMES_ONLY" == "true" ]]; then
      CMD+=(--names-only)
    fi
    CMD+=("$APT_QUERY")
    "${CMD[@]}"
    ;;
  show)
    require_packages
    apt-cache show "${PACKAGE_ARGS[@]}"
    ;;
  depends)
    require_packages
    CMD=(apt-cache depends)
    if [[ "$APT_RECURSE" == "true" ]]; then
      CMD+=(--recurse)
    fi
    if [[ "$APT_INSTALLED_ONLY" == "true" ]]; then
      CMD+=(--installed)
    fi
    CMD+=("${PACKAGE_ARGS[@]}")
    "${CMD[@]}"
    ;;
  rdepends)
    require_packages
    CMD=(apt-cache rdepends)
    if [[ "$APT_RECURSE" == "true" ]]; then
      CMD+=(--recurse)
    fi
    if [[ "$APT_INSTALLED_ONLY" == "true" ]]; then
      CMD+=(--installed)
    fi
    CMD+=("${PACKAGE_ARGS[@]}")
    "${CMD[@]}"
    ;;
  policy)
    apt-cache policy "${PACKAGE_ARGS[@]}"
    ;;
  madison)
    require_packages
    apt-cache madison "${PACKAGE_ARGS[@]}"
    ;;
  unmet)
    apt-cache unmet
    ;;
  list-installed)
    dpkg-query -W -f='${Package}	${Version}
'
    ;;
  *)
    echo "ERROR: unknown APT_SEARCH_ACTION '$APT_SEARCH_ACTION'" >&2
    exit 1
    ;;
esac
