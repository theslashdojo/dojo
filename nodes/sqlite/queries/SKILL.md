---
name: sqlite-queries
description: Execute SQLite queries — SELECT, INSERT, UPDATE, DELETE, CTEs, UPSERT, RETURNING, JSON, window functions. Use when reading or writing data in a SQLite database.
---

# SQLite Queries

Execute SQL queries against SQLite databases: reads, writes, upserts, CTEs, JSON operations, and window functions.

## When to Use

- Reading data from a SQLite database (SELECT, JOIN, aggregate)
- Writing data (INSERT, UPDATE, DELETE)
- Atomic insert-or-update (UPSERT with ON CONFLICT)
- Complex queries with CTEs, window functions, or JSON operators
- Building reports or analytics from SQLite data
- Migrating or transforming data between tables

## Workflow

1. **Open the database** with appropriate PRAGMAs (WAL, foreign_keys, busy_timeout)
2. **Write the query** using parameterized placeholders (? or $name) — never interpolate user input
3. **Execute** using the sqlite3 CLI, Python sqlite3, or better-sqlite3 (Node.js)
4. **Check results** — use RETURNING for write operations, EXPLAIN QUERY PLAN for optimization

## Quick Reference

### SELECT Patterns

```sql
-- Filter and sort
SELECT id, name FROM users WHERE active = 1 ORDER BY name LIMIT 20;

-- Aggregate
SELECT department, COUNT(*), AVG(salary) FROM employees GROUP BY department HAVING COUNT(*) > 5;

-- JOIN
SELECT u.name, o.total FROM users u INNER JOIN orders o ON o.user_id = u.id;

-- LEFT JOIN with COALESCE
SELECT u.name, COALESCE(SUM(o.total), 0) as total FROM users u LEFT JOIN orders o ON o.user_id = u.id GROUP BY u.id;
```

### Write Patterns

```sql
-- Insert with RETURNING
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com') RETURNING id;

-- Upsert
INSERT INTO settings (key, value) VALUES ('theme', 'dark')
ON CONFLICT(key) DO UPDATE SET value = excluded.value;

-- Update with subquery
UPDATE orders SET status = 'cancelled' WHERE user_id IN (SELECT id FROM users WHERE banned = 1);

-- Delete expired
DELETE FROM sessions WHERE expires_at < datetime('now') RETURNING id;
```

### CTE Patterns

```sql
-- Non-recursive: simplify complex queries
WITH active AS (SELECT * FROM users WHERE active = 1)
SELECT a.name, COUNT(o.id) FROM active a LEFT JOIN orders o ON o.user_id = a.id GROUP BY a.id;

-- Recursive: tree traversal
WITH RECURSIVE tree AS (
  SELECT id, name, parent_id, 0 as depth FROM categories WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.name, c.parent_id, t.depth + 1 FROM categories c JOIN tree t ON c.parent_id = t.id
)
SELECT * FROM tree;
```

### JSON Patterns

```sql
-- Extract
SELECT data->>'$.name', data->>'$.email' FROM profiles;

-- Filter by JSON field
SELECT * FROM events WHERE data->>'$.type' = 'click';

-- Iterate JSON array
SELECT p.id, t.value as tag FROM posts p, json_each(p.tags) t;

-- Modify
UPDATE profiles SET data = json_set(data, '$.verified', json('true')) WHERE id = 42;
```

## Script Usage

```bash
# Run the query operations script
SQLITE_DB=myapp.db ./scripts/query-ops.sh
```

## Edge Cases

- **NULL handling**: Use `COALESCE(col, default)` or `IFNULL(col, default)` for null safety
- **Type coercion**: SQLite is loosely typed — `'5' = 5` is true. Use `typeof()` to check
- **Case sensitivity**: LIKE is case-insensitive for ASCII by default. Use `GLOB` for case-sensitive
- **Empty results**: SELECT returns empty result set (not NULL/error) when no rows match
- **Integer overflow**: SQLite integers are 64-bit signed (-9223372036854775808 to 9223372036854775807)
- **String concatenation**: Use `||` operator, not `+` (which is numeric addition)
- **Boolean**: No BOOLEAN type — use `INTEGER` with 0/1, check with `= 1` not `IS TRUE`

## Common Mistakes

1. **Not using parameterized queries** — SQL injection is the #1 security vulnerability
2. **Forgetting BEGIN/COMMIT for bulk inserts** — 50 rows/sec vs 100,000+ rows/sec
3. **Not enabling WAL mode** — readers block writers in default journal mode
4. **Using AUTOINCREMENT unnecessarily** — INTEGER PRIMARY KEY already auto-increments
5. **LIKE '%pattern%'** — cannot use indexes. Use FTS5 for full-text search
