#!/usr/bin/env bash
# SQLite Schema Operations — create, inspect, and migrate database schemas
# Usage: SQLITE_DB=myapp.db ./schema-ops.sh [operation]
# Operations: setup, inspect, indexes, migrate, fts5, strict, cleanup
set -euo pipefail

DB="${SQLITE_DB:-app.db}"
OP="${1:-setup}"

# Apply connection PRAGMAs
pragmas() {
  sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=5000;
SQL
}

case "$OP" in
  setup)
    echo "=== Creating schema in: $DB ==="
    pragmas
    sqlite3 "$DB" <<'SQL'
-- Migrations tracking table
CREATE TABLE IF NOT EXISTS migrations (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  applied_at TEXT DEFAULT (datetime('now'))
);

-- Users table with all constraint types
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('admin', 'user', 'viewer')),
  active INTEGER DEFAULT 1 CHECK(active IN (0, 1)),
  profile TEXT DEFAULT '{}',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Posts with foreign key
CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  published INTEGER DEFAULT 0 CHECK(published IN (0, 1)),
  tags TEXT DEFAULT '[]',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Many-to-many join table (composite PK)
CREATE TABLE IF NOT EXISTS post_categories (
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL,
  PRIMARY KEY (post_id, category_id)
);

-- Key-value settings (WITHOUT ROWID)
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT (datetime('now'))
) WITHOUT ROWID;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(lower(email));
CREATE INDEX IF NOT EXISTS idx_users_active ON users(role) WHERE active = 1;

-- Auto-update trigger for updated_at
CREATE TRIGGER IF NOT EXISTS users_auto_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
  UPDATE users SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS posts_auto_update
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
  UPDATE posts SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Record migration
INSERT OR IGNORE INTO migrations (name) VALUES ('001_initial_schema');

SELECT 'Schema created successfully. Tables: users, posts, post_categories, settings, migrations';
SQL
    ;;

  inspect)
    echo "=== Schema Inspection: $DB ==="

    echo "--- Tables ---"
    sqlite3 -header -column "$DB" \
      "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') ORDER BY type, name;"

    echo ""
    echo "--- Indexes ---"
    sqlite3 -header -column "$DB" \
      "SELECT name, tbl_name as 'table' FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, name;"

    echo ""
    echo "--- Triggers ---"
    sqlite3 -header -column "$DB" \
      "SELECT name, tbl_name as 'table' FROM sqlite_master WHERE type='trigger' ORDER BY tbl_name, name;"

    echo ""
    echo "--- Users table columns ---"
    sqlite3 -header -column "$DB" "PRAGMA table_info('users');"

    echo ""
    echo "--- Foreign keys on posts ---"
    sqlite3 -header -column "$DB" "PRAGMA foreign_key_list('posts');"

    echo ""
    echo "--- Applied migrations ---"
    sqlite3 -header -column "$DB" "SELECT * FROM migrations ORDER BY id;" 2>/dev/null || echo "(no migrations table)"

    echo ""
    echo "--- Full CREATE statements ---"
    sqlite3 "$DB" "SELECT sql || ';' FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type DESC, name;"
    ;;

  indexes)
    echo "=== Index Details: $DB ==="

    # List all indexes with their columns
    sqlite3 "$DB" <<'SQL'
SELECT m.name as index_name, m.tbl_name as table_name, ii.name as column_name, ii.seqno as position
FROM sqlite_master m
JOIN pragma_index_info(m.name) ii
WHERE m.type = 'index' AND m.name NOT LIKE 'sqlite_%'
ORDER BY m.tbl_name, m.name, ii.seqno;
SQL
    ;;

  migrate)
    echo "=== Running Migration: $DB ==="
    pragmas

    # Check if migration already applied
    APPLIED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM migrations WHERE name='002_add_tags_view';" 2>/dev/null || echo "0")
    if [ "$APPLIED" -gt 0 ]; then
      echo "Migration 002_add_tags_view already applied. Skipping."
      exit 0
    fi

    sqlite3 "$DB" <<'SQL'
BEGIN;

-- Add a column to users (safe ALTER TABLE)
ALTER TABLE users ADD COLUMN last_login TEXT;

-- Create a view
CREATE VIEW IF NOT EXISTS active_posts AS
SELECT p.id, p.title, u.name as author, p.created_at
FROM posts p
INNER JOIN users u ON u.id = p.author_id
WHERE p.published = 1
ORDER BY p.created_at DESC;

-- Record migration
INSERT INTO migrations (name) VALUES ('002_add_tags_view');

COMMIT;

SELECT 'Migration 002_add_tags_view applied successfully';
SQL
    ;;

  fts5)
    echo "=== FTS5 Virtual Table Setup: $DB ==="
    pragmas
    sqlite3 "$DB" <<'SQL'
-- Create FTS5 index for full-text search on posts
CREATE VIRTUAL TABLE IF NOT EXISTS posts_fts USING fts5(
  title,
  body,
  content='posts',
  content_rowid='id',
  tokenize='porter unicode61'
);

-- Sync triggers
CREATE TRIGGER IF NOT EXISTS posts_fts_insert AFTER INSERT ON posts BEGIN
  INSERT INTO posts_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;

CREATE TRIGGER IF NOT EXISTS posts_fts_delete AFTER DELETE ON posts BEGIN
  INSERT INTO posts_fts(posts_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
END;

CREATE TRIGGER IF NOT EXISTS posts_fts_update AFTER UPDATE ON posts BEGIN
  INSERT INTO posts_fts(posts_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
  INSERT INTO posts_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;

-- Rebuild from existing data
INSERT INTO posts_fts(posts_fts) VALUES('rebuild');

SELECT 'FTS5 index created on posts (title, body)';
SQL
    ;;

  strict)
    echo "=== STRICT Table Example: $DB ==="
    sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS measurements (
  id INTEGER PRIMARY KEY,
  sensor_id INTEGER NOT NULL,
  value REAL NOT NULL,
  unit TEXT NOT NULL,
  recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

-- This would fail in STRICT mode:
-- INSERT INTO measurements (sensor_id, value, unit) VALUES ('not_a_number', 'not_a_float', 42);

-- This works:
INSERT INTO measurements (sensor_id, value, unit) VALUES (1, 23.5, 'celsius');
SELECT 'STRICT table created. Type mismatches will be rejected.';
SQL
    ;;

  check)
    echo "=== Schema Health Check: $DB ==="
    pragmas

    echo "--- Foreign key violations ---"
    VIOLATIONS=$(sqlite3 "$DB" "PRAGMA foreign_key_check;" 2>/dev/null)
    if [ -z "$VIOLATIONS" ]; then
      echo "No foreign key violations found."
    else
      echo "VIOLATIONS FOUND:"
      echo "$VIOLATIONS"
    fi

    echo ""
    echo "--- Integrity check ---"
    sqlite3 "$DB" "PRAGMA integrity_check;"

    echo ""
    echo "--- Database size ---"
    PAGE_COUNT=$(sqlite3 "$DB" "PRAGMA page_count;")
    PAGE_SIZE=$(sqlite3 "$DB" "PRAGMA page_size;")
    SIZE_BYTES=$((PAGE_COUNT * PAGE_SIZE))
    echo "Pages: $PAGE_COUNT x $PAGE_SIZE bytes = $((SIZE_BYTES / 1024)) KB"
    ;;

  cleanup)
    echo "=== Cleaning up ==="
    rm -f "$DB" "${DB}-wal" "${DB}-shm"
    echo "Removed $DB and associated files."
    ;;

  *)
    echo "Usage: $0 {setup|inspect|indexes|migrate|fts5|strict|check|cleanup}"
    echo ""
    echo "Operations:"
    echo "  setup    Create initial schema (users, posts, settings)"
    echo "  inspect  Show all tables, indexes, triggers, columns"
    echo "  indexes  Show index details with column info"
    echo "  migrate  Run a sample migration (add column + view)"
    echo "  fts5     Create FTS5 full-text search index on posts"
    echo "  strict   Create a STRICT mode table example"
    echo "  check    Run integrity and foreign key checks"
    echo "  cleanup  Remove the database file"
    exit 1
    ;;
esac
