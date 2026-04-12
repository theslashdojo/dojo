#!/usr/bin/env bash
# Type-check a TypeScript project without emitting output.
# Usage: ./typecheck.sh [path/to/tsconfig.json]
# Exit code: 0 = no type errors, non-zero = type errors found

set -euo pipefail

TSCONFIG="${1:-tsconfig.json}"

if [ ! -f "$TSCONFIG" ]; then
  echo "Error: $TSCONFIG not found" >&2
  exit 1
fi

if ! command -v npx &>/dev/null; then
  echo "Error: npx not found. Install Node.js 18+ first." >&2
  exit 1
fi

echo "Type-checking with $TSCONFIG..."
npx tsc --noEmit --project "$TSCONFIG" --pretty
echo "No type errors found."
