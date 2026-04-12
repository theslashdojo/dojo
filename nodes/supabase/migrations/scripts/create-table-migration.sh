#!/usr/bin/env bash
set -euo pipefail

# Create a migration file with a table, RLS policies, and indexes
# Usage: ./create-table-migration.sh <table_name> [owner_column]

TABLE="${1:?Usage: create-table-migration.sh <table_name> [owner_column]}"
OWNER_COL="${2:-user_id}"

# Create the migration
MIGRATION_FILE=$(supabase migration new "create_${TABLE}_table" 2>&1 | grep -oP 'supabase/migrations/\S+')

if [ -z "$MIGRATION_FILE" ]; then
  echo "ERROR: Failed to create migration file"
  exit 1
fi

cat > "$MIGRATION_FILE" << EOSQL
CREATE TABLE ${TABLE} (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ${OWNER_COL} uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE ${TABLE} ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "${TABLE}_select_own" ON ${TABLE}
  FOR SELECT USING (auth.uid() = ${OWNER_COL});

CREATE POLICY "${TABLE}_insert_own" ON ${TABLE}
  FOR INSERT WITH CHECK (auth.uid() = ${OWNER_COL});

CREATE POLICY "${TABLE}_update_own" ON ${TABLE}
  FOR UPDATE
  USING (auth.uid() = ${OWNER_COL})
  WITH CHECK (auth.uid() = ${OWNER_COL});

CREATE POLICY "${TABLE}_delete_own" ON ${TABLE}
  FOR DELETE USING (auth.uid() = ${OWNER_COL});

-- Indexes
CREATE INDEX idx_${TABLE}_${OWNER_COL} ON ${TABLE}(${OWNER_COL});
CREATE INDEX idx_${TABLE}_created_at ON ${TABLE}(created_at DESC);
EOSQL

echo "Migration created: $MIGRATION_FILE"
echo "Add your columns after '${OWNER_COL}' then run: supabase db reset"
