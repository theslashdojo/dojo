#!/usr/bin/env bash
# SQLite Query Operations — demonstrates common query patterns
# Usage: SQLITE_DB=myapp.db ./query-ops.sh [operation]
# Operations: setup, insert, select, upsert, cte, json, window, bulk, cleanup
set -euo pipefail

DB="${SQLITE_DB:-app.db}"
OP="${1:-setup}"

# Apply performance PRAGMAs
pragmas() {
  sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=5000;
PRAGMA cache_size=-64000;
PRAGMA temp_store=MEMORY;
SQL
}

case "$OP" in
  setup)
    echo "=== Setting up demo database: $DB ==="
    pragmas
    sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  department TEXT DEFAULT 'engineering',
  salary REAL DEFAULT 0,
  active INTEGER DEFAULT 1 CHECK(active IN (0, 1)),
  metadata TEXT DEFAULT '{}',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total REAL NOT NULL CHECK(total >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'completed', 'cancelled')),
  items TEXT DEFAULT '[]',
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_dept ON users(department) WHERE active = 1;

-- Insert sample data
INSERT OR IGNORE INTO users (name, email, department, salary, metadata) VALUES
  ('Alice', 'alice@example.com', 'engineering', 120000, '{"role":"senior","skills":["python","sql","rust"]}'),
  ('Bob', 'bob@example.com', 'engineering', 95000, '{"role":"mid","skills":["javascript","sql"]}'),
  ('Carol', 'carol@example.com', 'sales', 85000, '{"role":"lead","skills":["negotiation","crm"]}'),
  ('Dave', 'dave@example.com', 'sales', 75000, '{"role":"junior","skills":["crm"]}'),
  ('Eve', 'eve@example.com', 'engineering', 140000, '{"role":"principal","skills":["python","rust","c"]}');

INSERT OR IGNORE INTO orders (user_id, total, status, items) VALUES
  (1, 99.99, 'completed', '["widget-a","widget-b"]'),
  (1, 249.50, 'pending', '["gadget-x"]'),
  (2, 15.00, 'completed', '["widget-a"]'),
  (3, 500.00, 'completed', '["enterprise-plan"]'),
  (3, 500.00, 'pending', '["enterprise-plan"]');
SQL
    echo "Done. Tables: users, orders, settings"
    ;;

  select)
    echo "=== SELECT Examples ==="

    echo "--- All active users ---"
    sqlite3 -header -column "$DB" \
      "SELECT id, name, email, department FROM users WHERE active = 1 ORDER BY name;"

    echo ""
    echo "--- Users with order totals (LEFT JOIN) ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT u.name, u.department,
       COUNT(o.id) as order_count,
       COALESCE(SUM(o.total), 0) as lifetime_value
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id
ORDER BY lifetime_value DESC;
SQL

    echo ""
    echo "--- Department summary ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT department,
       COUNT(*) as headcount,
       ROUND(AVG(salary), 0) as avg_salary,
       MIN(salary) as min_salary,
       MAX(salary) as max_salary
FROM users
WHERE active = 1
GROUP BY department;
SQL
    ;;

  insert)
    echo "=== INSERT with RETURNING ==="
    sqlite3 -header -column "$DB" <<'SQL'
INSERT INTO users (name, email, department, salary)
VALUES ('Frank', 'frank@example.com', 'engineering', 105000)
RETURNING id, name, email, created_at;
SQL
    ;;

  upsert)
    echo "=== UPSERT Examples ==="

    echo "--- Insert or update settings ---"
    sqlite3 -header -column "$DB" <<'SQL'
INSERT INTO settings (key, value) VALUES ('theme', 'dark')
ON CONFLICT(key) DO UPDATE SET value = excluded.value
RETURNING key, value;
SQL

    echo ""
    echo "--- Insert or ignore (skip duplicates) ---"
    sqlite3 "$DB" <<'SQL'
INSERT OR IGNORE INTO users (name, email) VALUES ('Alice', 'alice@example.com');
SELECT 'Insert or ignore: no error on duplicate';
SQL
    ;;

  cte)
    echo "=== CTE Examples ==="

    echo "--- Non-recursive: active users with recent orders ---"
    sqlite3 -header -column "$DB" <<'SQL'
WITH active_users AS (
  SELECT * FROM users WHERE active = 1
),
recent_orders AS (
  SELECT * FROM orders WHERE created_at > datetime('now', '-30 days')
)
SELECT au.name, COUNT(ro.id) as recent_orders, COALESCE(SUM(ro.total), 0) as recent_total
FROM active_users au
LEFT JOIN recent_orders ro ON ro.user_id = au.id
GROUP BY au.id
ORDER BY recent_total DESC;
SQL

    echo ""
    echo "--- Generate date series (recursive CTE) ---"
    sqlite3 -header -column "$DB" <<'SQL'
WITH RECURSIVE dates(d) AS (
  VALUES(date('now', '-6 days'))
  UNION ALL
  SELECT date(d, '+1 day') FROM dates WHERE d < date('now')
)
SELECT d as date,
       COALESCE(cnt, 0) as orders
FROM dates
LEFT JOIN (
  SELECT date(created_at) as d, COUNT(*) as cnt
  FROM orders GROUP BY 1
) o USING(d);
SQL
    ;;

  json)
    echo "=== JSON Query Examples ==="

    echo "--- Extract JSON fields ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT name,
       metadata->>'$.role' as role,
       metadata->>'$.skills' as skills
FROM users;
SQL

    echo ""
    echo "--- Expand JSON arrays into rows ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT u.name, skill.value as skill
FROM users u, json_each(u.metadata, '$.skills') as skill
ORDER BY u.name, skill.value;
SQL

    echo ""
    echo "--- Filter by JSON content ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT name, metadata->>'$.role' as role
FROM users
WHERE EXISTS (
  SELECT 1 FROM json_each(metadata, '$.skills') WHERE value = 'python'
);
SQL

    echo ""
    echo "--- Build JSON response ---"
    sqlite3 "$DB" <<'SQL'
.mode json
SELECT json_object(
  'id', u.id,
  'name', u.name,
  'orders', (
    SELECT json_group_array(json_object('id', o.id, 'total', o.total, 'status', o.status))
    FROM orders o WHERE o.user_id = u.id
  )
) as user_json
FROM users u
WHERE u.name = 'Alice';
SQL
    ;;

  window)
    echo "=== Window Function Examples ==="

    echo "--- Rank by salary within department ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) as dept_rank,
       RANK() OVER (ORDER BY salary DESC) as overall_rank
FROM users
WHERE active = 1;
SQL

    echo ""
    echo "--- Running total of orders ---"
    sqlite3 -header -column "$DB" <<'SQL'
SELECT id, user_id, total,
       SUM(total) OVER (ORDER BY id ROWS UNBOUNDED PRECEDING) as running_total,
       ROW_NUMBER() OVER (ORDER BY id) as row_num
FROM orders;
SQL
    ;;

  bulk)
    echo "=== Bulk Insert Demo ==="
    echo "Inserting 1000 rows in a single transaction..."

    sqlite3 "$DB" <<'SQL'
BEGIN;
CREATE TABLE IF NOT EXISTS bulk_test (id INTEGER PRIMARY KEY, value TEXT, created_at TEXT DEFAULT (datetime('now')));
SQL

    # Generate and insert 1000 rows in one transaction
    {
      for i in $(seq 1 1000); do
        echo "INSERT INTO bulk_test (value) VALUES ('item-$i');"
      done
      echo "COMMIT;"
    } | sqlite3 "$DB"

    COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM bulk_test;")
    echo "Done. Rows in bulk_test: $COUNT"

    # Cleanup
    sqlite3 "$DB" "DROP TABLE IF EXISTS bulk_test;"
    ;;

  explain)
    echo "=== EXPLAIN QUERY PLAN ==="
    sqlite3 -header -column "$DB" <<'SQL'
EXPLAIN QUERY PLAN
SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = 1
GROUP BY u.id
ORDER BY order_count DESC;
SQL
    ;;

  cleanup)
    echo "=== Cleaning up ==="
    rm -f "$DB" "${DB}-wal" "${DB}-shm"
    echo "Removed $DB and associated WAL/SHM files."
    ;;

  *)
    echo "Usage: $0 {setup|select|insert|upsert|cte|json|window|bulk|explain|cleanup}"
    echo ""
    echo "Operations:"
    echo "  setup    Create demo tables and sample data"
    echo "  select   Run SELECT query examples (joins, aggregates)"
    echo "  insert   INSERT with RETURNING clause"
    echo "  upsert   UPSERT with ON CONFLICT examples"
    echo "  cte      Common Table Expression examples"
    echo "  json     JSON query examples (extract, filter, build)"
    echo "  window   Window function examples (rank, running total)"
    echo "  bulk     Bulk insert 1000 rows in a transaction"
    echo "  explain  EXPLAIN QUERY PLAN example"
    echo "  cleanup  Remove the database file"
    exit 1
    ;;
esac
