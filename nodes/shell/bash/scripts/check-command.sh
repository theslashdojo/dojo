#!/usr/bin/env bash
set -euo pipefail

# Check if one or more commands are available on the system.
# Usage: ./check-command.sh <command1> [command2] [command3] ...
#
# Outputs JSON with each command's availability, path, and version.

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <command1> [command2] ..." >&2
  exit 1
fi

# Start JSON array
printf '['

first=true
for cmd in "$@"; do
  if [[ "$first" != true ]]; then
    printf ','
  fi
  first=false

  if cmd_path=$(command -v "$cmd" 2>/dev/null); then
    # Try to get version (common patterns)
    version=""
    if ver=$("$cmd" --version 2>/dev/null | head -1); then
      version="$ver"
    elif ver=$("$cmd" -V 2>/dev/null | head -1); then
      version="$ver"
    elif ver=$("$cmd" version 2>/dev/null | head -1); then
      version="$ver"
    fi

    # Determine type
    cmd_type=$(type -t "$cmd" 2>/dev/null || echo "unknown")

    if command -v jq &>/dev/null; then
      jq -n \
        --arg name "$cmd" \
        --arg path "$cmd_path" \
        --arg version "$version" \
        --arg type "$cmd_type" \
        '{name: $name, available: true, path: $path, version: $version, type: $type}'
    else
      printf '{"name":"%s","available":true,"path":"%s","version":"%s","type":"%s"}' \
        "$cmd" "$cmd_path" "$version" "$cmd_type"
    fi
  else
    if command -v jq &>/dev/null; then
      jq -n \
        --arg name "$cmd" \
        '{name: $name, available: false, path: null, version: null, type: null}'
    else
      printf '{"name":"%s","available":false,"path":null,"version":null,"type":null}' "$cmd"
    fi
  fi
done

printf ']\n'
