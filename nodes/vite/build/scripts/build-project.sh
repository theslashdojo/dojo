#!/usr/bin/env bash
set -euo pipefail

# Build a Vite project for production with configurable options.
# Usage: ./build-project.sh
#
# Environment variables:
#   PROJECT_DIR  (required) — Path to the Vite project root
#   MODE         (optional) — Build mode, default: production
#   SOURCEMAP    (optional) — Source maps: true, false, inline, hidden. Default: false
#   OUT_DIR      (optional) — Output directory, default: dist
#
# Outputs a summary of generated files and total size.

PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR is required — set it to the Vite project root}"
MODE="${MODE:-production}"
SOURCEMAP="${SOURCEMAP:-false}"
OUT_DIR="${OUT_DIR:-dist}"

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Check for a Vite installation
VITE_BIN=""
if [[ -x "node_modules/.bin/vite" ]]; then
  VITE_BIN="node_modules/.bin/vite"
elif command -v vite &>/dev/null; then
  VITE_BIN="vite"
elif command -v npx &>/dev/null; then
  VITE_BIN="npx vite"
else
  echo "Error: vite is not installed in this project and npx is not available." >&2
  echo "Run 'npm install' first, or install vite globally." >&2
  exit 1
fi

# Check for a vite config file
CONFIG_FOUND=false
for f in vite.config.ts vite.config.js vite.config.mts vite.config.mjs; do
  if [[ -f "$f" ]]; then
    CONFIG_FOUND=true
    break
  fi
done

if [[ "$CONFIG_FOUND" == "false" ]]; then
  echo "Warning: No vite.config.{ts,js,mts,mjs} found in $PROJECT_DIR" >&2
  echo "Vite will use default configuration." >&2
fi

# Build the arguments array
BUILD_ARGS=("build" "--mode" "$MODE" "--outDir" "$OUT_DIR")

if [[ "$SOURCEMAP" != "false" ]]; then
  BUILD_ARGS+=("--sourcemap")
fi

echo "=== Vite Build ==="
echo "Project:    $PROJECT_DIR"
echo "Mode:       $MODE"
echo "Output:     $OUT_DIR"
echo "Sourcemap:  $SOURCEMAP"
echo "Command:    $VITE_BIN ${BUILD_ARGS[*]}"
echo ""

# Run the build
$VITE_BIN "${BUILD_ARGS[@]}"
BUILD_EXIT=$?

if [[ $BUILD_EXIT -ne 0 ]]; then
  echo "" >&2
  echo "Error: vite build failed with exit code $BUILD_EXIT" >&2
  exit $BUILD_EXIT
fi

# Report output
ABSOLUTE_OUT_DIR="$(cd "$OUT_DIR" 2>/dev/null && pwd)"
echo ""
echo "=== Build Output ==="
echo "Directory: $ABSOLUTE_OUT_DIR"
echo ""

# List files and sizes
if command -v find &>/dev/null && command -v sort &>/dev/null; then
  echo "Files:"
  find "$OUT_DIR" -type f -printf '  %s\t%p\n' | sort -rn | while IFS=$'\t' read -r size path; do
    if [[ $size -ge 1048576 ]]; then
      human=$(awk "BEGIN { printf \"%.2f MB\", $size / 1048576 }")
    elif [[ $size -ge 1024 ]]; then
      human=$(awk "BEGIN { printf \"%.2f kB\", $size / 1024 }")
    else
      human="${size} B"
    fi
    printf "  %-12s %s\n" "$human" "$path"
  done
  echo ""
fi

# Total size
if command -v du &>/dev/null; then
  TOTAL_SIZE=$(du -sh "$OUT_DIR" 2>/dev/null | cut -f1)
  echo "Total size: $TOTAL_SIZE"
fi

FILE_COUNT=$(find "$OUT_DIR" -type f | wc -l)
echo "File count: $FILE_COUNT"
echo ""
echo "Build complete. Preview with: npx vite preview --outDir $OUT_DIR"
