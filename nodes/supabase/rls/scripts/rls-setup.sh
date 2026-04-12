#!/usr/bin/env bash
set -euo pipefail

# Generate and apply common RLS policies for a table
# Usage: ./rls-setup.sh <table_name> [owner_column] [--public-read]
#
# Requires: SUPABASE_DB_URL or local supabase running

TABLE="${1:?Usage: rls-setup.sh <table_name> [owner_column] [--public-read]}"
OWNER_COL="${2:-user_id}"
PUBLIC_READ=false

for arg in "$@"; do
  if [ "$arg" = "--public-read" ]; then
    PUBLIC_READ=true
  fi
done

DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@localhost:54322/postgres}"

SQL="
-- Enable RLS
ALTER TABLE ${TABLE} ENABLE ROW LEVEL SECURITY;

-- SELECT: users read own data
CREATE POLICY \"${TABLE}_select_own\" ON ${TABLE}
  FOR SELECT
  TO authenticated
  USING (auth.uid() = ${OWNER_COL});

-- INSERT: users insert own data
CREATE POLICY \"${TABLE}_insert_own\" ON ${TABLE}
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = ${OWNER_COL});

-- UPDATE: users update own data
CREATE POLICY \"${TABLE}_update_own\" ON ${TABLE}
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = ${OWNER_COL})
  WITH CHECK (auth.uid() = ${OWNER_COL});

-- DELETE: users delete own data
CREATE POLICY \"${TABLE}_delete_own\" ON ${TABLE}
  FOR DELETE
  TO authenticated
  USING (auth.uid() = ${OWNER_COL});
"

if [ "$PUBLIC_READ" = true ]; then
  SQL="${SQL}
-- Public read access (anon)
CREATE POLICY \"${TABLE}_public_read\" ON ${TABLE}
  FOR SELECT
  TO anon
  USING (true);
"
fi

echo "Applying RLS policies to table '${TABLE}'..."
echo "$SQL" | psql "$DB_URL"
echo "Done. Policies applied to '${TABLE}'."
