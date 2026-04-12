#!/usr/bin/env bash
set -euo pipefail

# Safely delete files with optional backup and dry-run mode.
# Usage: ./safe-delete.sh [options] <path1> [path2] ...
#
# Options:
#   -b <dir>    Backup directory (files are copied here before deletion)
#   -n          Dry run (list what would be deleted without deleting)
#   -f          Force (skip confirmation prompt)
#   -r          Recursive (for directories)

backup_dir=""
dry_run=false
force=false
recursive=false

while getopts ':b:nfr' opt; do
  case "$opt" in
    b) backup_dir="$OPTARG" ;;
    n) dry_run=true ;;
    f) force=true ;;
    r) recursive=true ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
    ?) echo "Unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [options] <path1> [path2] ..." >&2
  echo "  -b <dir>  Backup directory" >&2
  echo "  -n        Dry run" >&2
  echo "  -f        Force (no prompt)" >&2
  echo "  -r        Recursive" >&2
  exit 1
fi

# Create backup directory if specified
if [[ -n "$backup_dir" ]]; then
  mkdir -p "$backup_dir"
fi

deleted=0
skipped=0
backed_up=0

for path in "$@"; do
  # Check if path exists
  if [[ ! -e "$path" ]]; then
    echo "SKIP: $path (does not exist)" >&2
    (( skipped++ )) || true
    continue
  fi

  # Safety: refuse to delete critical paths
  real_path=$(realpath "$path" 2>/dev/null || echo "$path")
  case "$real_path" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/sbin|/srv|/sys|/usr|/var)
      echo "REFUSE: $path (critical system path)" >&2
      (( skipped++ )) || true
      continue
      ;;
  esac

  # Check if directory without -r flag
  if [[ -d "$path" && "$recursive" != true ]]; then
    echo "SKIP: $path (directory, use -r for recursive)" >&2
    (( skipped++ )) || true
    continue
  fi

  # Dry run
  if [[ "$dry_run" == true ]]; then
    if [[ -d "$path" ]]; then
      echo "WOULD DELETE: $path/ (directory)"
    else
      size=$(stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null || echo "?")
      echo "WOULD DELETE: $path ($size bytes)"
    fi
    continue
  fi

  # Backup
  if [[ -n "$backup_dir" ]]; then
    backup_path="$backup_dir/$(basename "$path").$(date +%Y%m%d-%H%M%S)"
    if cp -a "$path" "$backup_path" 2>/dev/null; then
      echo "BACKUP: $path -> $backup_path" >&2
      (( backed_up++ )) || true
    else
      echo "WARN: Could not backup $path" >&2
    fi
  fi

  # Delete
  if [[ -d "$path" ]]; then
    rm -rf "$path"
  else
    rm -f "$path"
  fi
  echo "DELETED: $path"
  (( deleted++ )) || true
done

echo "---" >&2
echo "Deleted: $deleted, Skipped: $skipped, Backed up: $backed_up" >&2
