#!/usr/bin/env bash
set -euo pipefail

# Find files by name pattern, type, size, or modification time.
# Usage: ./find-files.sh <directory> [options]
#
# Options:
#   -n <pattern>    Name glob pattern (e.g., '*.py')
#   -t <type>       Type: f=file, d=directory, l=symlink
#   -s <size>       Size filter (e.g., '+10M', '-1k')
#   -m <days>       Modified within N days
#   -e <dirs>       Exclude directories (comma-separated)
#   -d <depth>      Max depth
#   -0              Null-separated output (for xargs -0)

SEARCH_DIR="${1:-.}"
shift || true

# Defaults
name_pattern=""
file_type=""
size_filter=""
mtime_days=""
exclude_dirs=""
max_depth=""
null_sep=false

while getopts ':n:t:s:m:e:d:0' opt; do
  case "$opt" in
    n) name_pattern="$OPTARG" ;;
    t) file_type="$OPTARG" ;;
    s) size_filter="$OPTARG" ;;
    m) mtime_days="$OPTARG" ;;
    e) exclude_dirs="$OPTARG" ;;
    d) max_depth="$OPTARG" ;;
    0) null_sep=true ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
    ?) echo "Unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Validate search directory
if [[ ! -d "$SEARCH_DIR" ]]; then
  echo "Directory not found: $SEARCH_DIR" >&2
  exit 1
fi

# Build find command
find_args=("$SEARCH_DIR")

# Max depth
if [[ -n "$max_depth" ]]; then
  find_args+=(-maxdepth "$max_depth")
fi

# Exclusions (add before other predicates)
if [[ -n "$exclude_dirs" ]]; then
  IFS=',' read -ra dirs <<< "$exclude_dirs"
  for dir in "${dirs[@]}"; do
    find_args+=(-path "*/$dir" -prune -o)
  done
fi

# Type filter
if [[ -n "$file_type" ]]; then
  find_args+=(-type "$file_type")
fi

# Name pattern
if [[ -n "$name_pattern" ]]; then
  find_args+=(-name "$name_pattern")
fi

# Size filter
if [[ -n "$size_filter" ]]; then
  find_args+=(-size "$size_filter")
fi

# Modification time
if [[ -n "$mtime_days" ]]; then
  find_args+=(-mtime "-$mtime_days")
fi

# Output format
if [[ "$null_sep" == true ]]; then
  find_args+=(-print0)
else
  find_args+=(-print)
fi

# Execute
find "${find_args[@]}" 2>/dev/null | sort
