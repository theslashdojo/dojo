#!/usr/bin/env bash
set -euo pipefail

APT_REPO_ACTION="${APT_REPO_ACTION:?APT_REPO_ACTION is required (add-deb822|add-line|remove|list)}"
APT_REPO_NAME="${APT_REPO_NAME:-}"
APT_REPO_URI="${APT_REPO_URI:-}"
APT_REPO_SUITES="${APT_REPO_SUITES:-}"
APT_REPO_COMPONENTS="${APT_REPO_COMPONENTS:-main}"
APT_REPO_ARCH="${APT_REPO_ARCH:-}"
APT_REPO_KEY_URL="${APT_REPO_KEY_URL:-}"
APT_REPO_SIGNED_BY="${APT_REPO_SIGNED_BY:-}"
APT_ENABLE_SOURCE="${APT_ENABLE_SOURCE:-false}"
APT_NO_UPDATE="${APT_NO_UPDATE:-false}"
APT_REMOVE_KEY="${APT_REMOVE_KEY:-false}"
APT_REMOVE_PIN="${APT_REMOVE_PIN:-false}"

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
  "${SUDO[@]}" apt-get "$@"
}

require_repo_args() {
  if [[ -z "$APT_REPO_NAME" || -z "$APT_REPO_URI" || -z "$APT_REPO_SUITES" ]]; then
    echo "ERROR: APT_REPO_NAME, APT_REPO_URI, and APT_REPO_SUITES are required" >&2
    exit 1
  fi
}

repo_dir="/etc/apt/sources.list.d"
key_dir="/etc/apt/keyrings"
pref_dir="/etc/apt/preferences.d"

signed_by="$APT_REPO_SIGNED_BY"
if [[ -z "$signed_by" && -n "$APT_REPO_KEY_URL" && -n "$APT_REPO_NAME" ]]; then
  ext="asc"
  if [[ "$APT_REPO_KEY_URL" == *.gpg ]]; then
    ext="gpg"
  fi
  signed_by="$key_dir/${APT_REPO_NAME}-archive-keyring.$ext"
fi

fetch_key_if_needed() {
  if [[ -z "$APT_REPO_KEY_URL" ]]; then
    return 0
  fi
  if [[ -z "$signed_by" ]]; then
    echo "ERROR: could not determine Signed-By path for key download" >&2
    exit 1
  fi
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' RETURN
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$APT_REPO_KEY_URL" -o "$tmp_file"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_file" "$APT_REPO_KEY_URL"
  else
    echo "ERROR: curl or wget is required to download repository keys" >&2
    exit 1
  fi
  "${SUDO[@]}" install -d -m 0755 "$key_dir"
  "${SUDO[@]}" install -m 0644 "$tmp_file" "$signed_by"
  rm -f "$tmp_file"
  trap - RETURN
}

write_source_file() {
  local target_file="$1"
  local content="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' RETURN
  printf '%s
' "$content" >"$tmp_file"
  "${SUDO[@]}" install -D -m 0644 "$tmp_file" "$target_file"
  rm -f "$tmp_file"
  trap - RETURN
}

refresh_if_needed() {
  if [[ "$APT_NO_UPDATE" != "true" ]]; then
    run_apt update
  fi
}

case "$APT_REPO_ACTION" in
  list)
    shopt -s nullglob
    files=(/etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list)
    if [[ "${#files[@]}" -eq 0 ]]; then
      echo "No repository files found under /etc/apt/sources.list.d"
      exit 0
    fi
    for file in "${files[@]}"; do
      echo "=== $file ==="
      cat "$file"
      echo
    done
    ;;
  add-deb822)
    require_repo_args
    fetch_key_if_needed
    types="deb"
    if [[ "$APT_ENABLE_SOURCE" == "true" ]]; then
      types="deb deb-src"
    fi
    body="Types: $types
URIs: $APT_REPO_URI
Suites: $APT_REPO_SUITES
Components: $APT_REPO_COMPONENTS"
    if [[ -n "$APT_REPO_ARCH" ]]; then
      body+="
Architectures: $APT_REPO_ARCH"
    fi
    if [[ -n "$signed_by" ]]; then
      body+="
Signed-By: $signed_by"
    else
      echo "WARNING: no Signed-By path configured; explicit keyrings are recommended" >&2
    fi
    write_source_file "$repo_dir/$APT_REPO_NAME.sources" "$body"
    refresh_if_needed
    ;;
  add-line)
    require_repo_args
    fetch_key_if_needed
    opts=()
    if [[ -n "$APT_REPO_ARCH" ]]; then
      opts+=("arch=$APT_REPO_ARCH")
    fi
    if [[ -n "$signed_by" ]]; then
      opts+=("signed-by=$signed_by")
    else
      echo "WARNING: no Signed-By path configured; explicit keyrings are recommended" >&2
    fi
    opt_text=""
    if [[ "${#opts[@]}" -gt 0 ]]; then
      opt_text=" [$(IFS=,; echo "${opts[*]}")]"
    fi
    line="deb${opt_text} $APT_REPO_URI $APT_REPO_SUITES $APT_REPO_COMPONENTS"
    if [[ "$APT_ENABLE_SOURCE" == "true" ]]; then
      line+="
deb-src${opt_text} $APT_REPO_URI $APT_REPO_SUITES $APT_REPO_COMPONENTS"
    fi
    write_source_file "$repo_dir/$APT_REPO_NAME.list" "$line"
    refresh_if_needed
    ;;
  remove)
    if [[ -z "$APT_REPO_NAME" ]]; then
      echo "ERROR: APT_REPO_NAME is required for remove" >&2
      exit 1
    fi
    "${SUDO[@]}" rm -f "$repo_dir/$APT_REPO_NAME.sources" "$repo_dir/$APT_REPO_NAME.list"
    if [[ "$APT_REMOVE_PIN" == "true" ]]; then
      "${SUDO[@]}" rm -f "$pref_dir/$APT_REPO_NAME" "$pref_dir/$APT_REPO_NAME.pref"
    fi
    if [[ "$APT_REMOVE_KEY" == "true" ]]; then
      if [[ -n "$signed_by" ]]; then
        "${SUDO[@]}" rm -f "$signed_by"
      else
        "${SUDO[@]}" rm -f "$key_dir/${APT_REPO_NAME}-archive-keyring.asc" "$key_dir/${APT_REPO_NAME}-archive-keyring.gpg"
      fi
    fi
    refresh_if_needed
    ;;
  *)
    echo "ERROR: unknown APT_REPO_ACTION '$APT_REPO_ACTION'" >&2
    exit 1
    ;;
esac
