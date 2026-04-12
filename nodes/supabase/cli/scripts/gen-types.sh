#!/usr/bin/env bash
set -euo pipefail

# Generate TypeScript types from the local Supabase database schema
# Requires: supabase CLI, local stack running (supabase start)

OUTPUT_FILE="${1:-src/types/supabase.ts}"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

mkdir -p "$OUTPUT_DIR"

echo "Generating TypeScript types from local database..."
supabase gen types typescript --local > "$OUTPUT_FILE"

echo "Types written to $OUTPUT_FILE"
echo "Use: import type { Database } from '${OUTPUT_FILE%.ts}';"
