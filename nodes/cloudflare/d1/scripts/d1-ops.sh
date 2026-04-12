#!/usr/bin/env bash
set -euo pipefail

# Cloudflare D1 operations via Wrangler CLI
# Required env: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
# Usage:
#   ./d1-ops.sh create <database-name>
#   ./d1-ops.sh execute <database-name> <sql> [--local|--remote]
#   ./d1-ops.sh execute-file <database-name> <sql-file> [--local|--remote]
#   ./d1-ops.sh migrate-create <database-name> <migration-name>
#   ./d1-ops.sh migrate-apply <database-name> [--local|--remote]
#   ./d1-ops.sh migrate-list <database-name> [--local|--remote]
#   ./d1-ops.sh list

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

ACTION="${1:-help}"
TARGET="${3:---remote}"

case "$ACTION" in
  create)
    DB_NAME="${2:?Usage: d1-ops.sh create <database-name>}"
    wrangler d1 create "$DB_NAME"
    ;;
  execute)
    DB_NAME="${2:?Usage: d1-ops.sh execute <database-name> <sql>}"
    SQL="${3:?Missing SQL command}"
    TARGET="${4:---remote}"
    wrangler d1 execute "$DB_NAME" --command "$SQL" "$TARGET"
    ;;
  execute-file)
    DB_NAME="${2:?Usage: d1-ops.sh execute-file <database-name> <sql-file>}"
    SQL_FILE="${3:?Missing SQL file path}"
    TARGET="${4:---remote}"
    if [ ! -f "$SQL_FILE" ]; then
      echo "Error: SQL file not found: $SQL_FILE" >&2
      exit 1
    fi
    wrangler d1 execute "$DB_NAME" --file "$SQL_FILE" "$TARGET"
    ;;
  migrate-create)
    DB_NAME="${2:?Usage: d1-ops.sh migrate-create <database-name> <migration-name>}"
    MIGRATION_NAME="${3:?Missing migration name}"
    wrangler d1 migrations create "$DB_NAME" "$MIGRATION_NAME"
    ;;
  migrate-apply)
    DB_NAME="${2:?Usage: d1-ops.sh migrate-apply <database-name> [--local|--remote]}"
    TARGET="${3:---remote}"
    wrangler d1 migrations apply "$DB_NAME" "$TARGET"
    ;;
  migrate-list)
    DB_NAME="${2:?Usage: d1-ops.sh migrate-list <database-name> [--local|--remote]}"
    TARGET="${3:---remote}"
    wrangler d1 migrations list "$DB_NAME" "$TARGET"
    ;;
  list)
    wrangler d1 list
    ;;
  *)
    echo "Usage: d1-ops.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  create <name>                          Create a D1 database"
    echo "  execute <name> <sql> [--local|--remote] Execute SQL query"
    echo "  execute-file <name> <file> [--local|--remote] Execute SQL from file"
    echo "  migrate-create <name> <migration>      Create a migration file"
    echo "  migrate-apply <name> [--local|--remote] Apply pending migrations"
    echo "  migrate-list <name> [--local|--remote]  List migration status"
    echo "  list                                   List all databases"
    exit 1
    ;;
esac
