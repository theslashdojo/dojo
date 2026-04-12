#!/usr/bin/env bash
set -euo pipefail

# Run Prisma Migration
# Requires: DATABASE_URL (env), MIGRATION_NAME (env)
# Packages: prisma

if [ -z "${MIGRATION_NAME:-}" ]; then
  echo "Error: MIGRATION_NAME environment variable is required"
  echo "Usage: MIGRATION_NAME=add-user-table ./run-migration.sh"
  exit 1
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "Error: DATABASE_URL environment variable is required"
  exit 1
fi

# Validate schema before migrating
echo "Validating schema..."
npx prisma validate

# Check current migration status
echo ""
echo "Current migration status:"
npx prisma migrate status 2>/dev/null || true

# Run the migration
echo ""
echo "Creating and applying migration: ${MIGRATION_NAME}"
npx prisma migrate dev --name "$MIGRATION_NAME"

echo ""
echo "Migration '${MIGRATION_NAME}' applied successfully."
echo ""
echo "Migration status after applying:"
npx prisma migrate status
