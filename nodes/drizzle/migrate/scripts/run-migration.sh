#!/usr/bin/env bash
# Drizzle Migration Runner
#
# Runs drizzle-kit migration commands: generate, migrate, push, pull, studio.
#
# Usage:
#   MIGRATION_COMMAND=generate ./run-migration.sh
#   MIGRATION_COMMAND=migrate DATABASE_URL=postgres://... ./run-migration.sh
#   MIGRATION_COMMAND=push DATABASE_URL=postgres://... ./run-migration.sh
#   MIGRATION_COMMAND=pull DATABASE_URL=postgres://... ./run-migration.sh
#
# Environment:
#   MIGRATION_COMMAND - Command to run (default: generate)
#     generate  - Create SQL migration files from schema changes
#     migrate   - Apply pending migration files to database
#     push      - Apply schema directly to database (no SQL files)
#     pull      - Introspect database into TypeScript schema
#     studio    - Open visual schema browser
#     check     - Validate migration consistency
#     export    - Output SQL representation to console
#   DATABASE_URL     - Database connection string (required for migrate/push/pull/studio)
#   MIGRATION_NAME   - Optional name for the migration (generate only)
#   DRIZZLE_CONFIG   - Path to drizzle config file (default: drizzle.config.ts)
#   STRICT_MODE      - Set to "true" to require confirmation for destructive changes

set -euo pipefail

COMMAND="${MIGRATION_COMMAND:-generate}"
CONFIG="${DRIZZLE_CONFIG:-drizzle.config.ts}"

# Verify drizzle-kit is installed
if ! npx drizzle-kit --version &>/dev/null; then
  echo "Error: drizzle-kit is not installed."
  echo "Install with: npm install -D drizzle-kit"
  exit 1
fi

# Verify config exists
if [[ ! -f "$CONFIG" ]]; then
  echo "Error: Config file not found: $CONFIG"
  echo "Create drizzle.config.ts or set DRIZZLE_CONFIG env var."
  exit 1
fi

# Build command arguments
ARGS=("--config=$CONFIG")

case "$COMMAND" in
  generate)
    if [[ -n "${MIGRATION_NAME:-}" ]]; then
      ARGS+=("--name=$MIGRATION_NAME")
    fi
    echo "Generating migration from schema changes..."
    npx drizzle-kit generate "${ARGS[@]}"
    echo "Migration generated. Review the SQL in your output directory before applying."
    ;;

  migrate)
    if [[ -z "${DATABASE_URL:-}" ]]; then
      echo "Error: DATABASE_URL is required for 'migrate' command."
      exit 1
    fi
    echo "Applying pending migrations..."
    npx drizzle-kit migrate "${ARGS[@]}"
    echo "Migrations applied successfully."
    ;;

  push)
    if [[ -z "${DATABASE_URL:-}" ]]; then
      echo "Error: DATABASE_URL is required for 'push' command."
      exit 1
    fi
    if [[ "${STRICT_MODE:-}" == "true" ]]; then
      ARGS+=("--strict")
    fi
    echo "Pushing schema changes directly to database..."
    npx drizzle-kit push "${ARGS[@]}"
    echo "Schema pushed successfully."
    ;;

  pull)
    if [[ -z "${DATABASE_URL:-}" ]]; then
      echo "Error: DATABASE_URL is required for 'pull' command."
      exit 1
    fi
    echo "Introspecting database schema..."
    npx drizzle-kit pull "${ARGS[@]}"
    echo "Schema pulled. Check generated TypeScript files."
    ;;

  studio)
    if [[ -z "${DATABASE_URL:-}" ]]; then
      echo "Error: DATABASE_URL is required for 'studio' command."
      exit 1
    fi
    echo "Starting Drizzle Studio..."
    npx drizzle-kit studio "${ARGS[@]}"
    ;;

  check)
    echo "Checking migration consistency..."
    npx drizzle-kit check "${ARGS[@]}"
    echo "Migration check complete."
    ;;

  export)
    echo "Exporting SQL representation..."
    npx drizzle-kit export "${ARGS[@]}"
    ;;

  *)
    echo "Error: Unknown command '$COMMAND'."
    echo "Valid commands: generate, migrate, push, pull, studio, check, export"
    exit 1
    ;;
esac
