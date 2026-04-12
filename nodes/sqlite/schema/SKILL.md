---
name: sqlite-schema
description: Design SQLite schemas — CREATE TABLE, types, constraints, indexes, views, triggers, ALTER TABLE. Use when creating or modifying database structure.
---

# SQLite Schema Design

Create and modify SQLite database schemas: tables, columns, constraints, indexes, views, triggers, and migrations.

## When to Use

- Creating a new SQLite database with tables
- Adding tables or columns to an existing database
- Designing indexes for query performance
- Creating views for reusable queries
- Writing triggers for automated actions
- Running schema migrations (ALTER TABLE, recreate pattern)

## Workflow

1. **Design the schema** — identify entities, relationships, and constraints
2. **Choose types** — INTEGER, TEXT, REAL, BLOB (remember SQLite is flexible-typed)
3. **Define constraints** — PRIMARY KEY, NOT NULL, UNIQUE, CHECK, FOREIGN KEY, DEFAULT
4. **Create indexes** — for columns used in WHERE, JOIN, ORDER BY
5. **Add views/triggers** — for computed queries and automation
6. **Enable foreign keys** — `PRAGMA foreign_keys = ON` (off by default!)

## Quick Reference

### Table with All Constraint Types

```sql
CREATE TABLE products (
  id INTEGER PRIMARY KEY,                         -- auto-incrementing rowid alias
  sku TEXT NOT NULL UNIQUE,                        -- natural key
  name TEXT NOT NULL,
  price REAL NOT NULL CHECK(price > 0),            -- validation
  stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
  category_id INTEGER REFERENCES categories(id),   -- foreign key
  active INTEGER DEFAULT 1 CHECK(active IN (0,1)), -- boolean
  metadata TEXT DEFAULT '{}',                       -- JSON column
  created_at TEXT DEFAULT (datetime('now')),        -- auto timestamp
  UNIQUE(category_id, name)                         -- composite unique
);
```

### Index Patterns

```sql
-- Single column (for WHERE filters)
CREATE INDEX idx_products_category ON products(category_id);

-- Composite (equality first, then range/sort)
CREATE INDEX idx_products_cat_price ON products(category_id, price DESC);

-- Partial (only index matching rows)
CREATE INDEX idx_active_products ON products(name) WHERE active = 1;

-- Expression (for computed lookups)
CREATE INDEX idx_products_lower_name ON products(lower(name));

-- Covering (avoids table lookup)
CREATE INDEX idx_products_list ON products(category_id, active, name, price);
```

### Migration Pattern (Recreate Table)

```sql
-- For changes ALTER TABLE can't handle
BEGIN;
CREATE TABLE products_new ( /* new schema */ );
INSERT INTO products_new SELECT /* mapped columns */ FROM products;
DROP TABLE products;
ALTER TABLE products_new RENAME TO products;
-- Recreate indexes and triggers
COMMIT;
```

## Script Usage

```bash
# Run schema operations
SQLITE_DB=myapp.db ./scripts/schema-ops.sh setup
SQLITE_DB=myapp.db ./scripts/schema-ops.sh inspect
SQLITE_DB=myapp.db ./scripts/schema-ops.sh migrate
```

## Edge Cases

- **Type affinity**: Any column can hold any type unless `STRICT` mode is used
- **Foreign keys OFF by default**: Must run `PRAGMA foreign_keys=ON` on every connection
- **AUTOINCREMENT vs INTEGER PRIMARY KEY**: AUTOINCREMENT prevents rowid reuse but adds overhead — usually unnecessary
- **ALTER TABLE limitations**: Cannot modify column types, drop constraints, or reorder columns (use recreate pattern)
- **DROP COLUMN**: Only available in SQLite 3.35.0+ — check version first
- **RENAME COLUMN**: Only available in SQLite 3.25.0+ — check version first
- **WITHOUT ROWID**: Good for tables with non-integer PKs, but disables some features (e.g., incremental blob I/O)
- **Schema changes in WAL mode**: DDL operations acquire an exclusive lock briefly — keep them fast

## Best Practices

1. Always use `IF NOT EXISTS` for idempotent schema scripts
2. Always enable `PRAGMA foreign_keys = ON` before any INSERT/UPDATE
3. Prefer INTEGER PRIMARY KEY over AUTOINCREMENT
4. Store dates as TEXT in ISO-8601 format with `DEFAULT (datetime('now'))`
5. Store booleans as INTEGER with CHECK(col IN (0, 1))
6. Use STRICT tables when type safety matters
7. Create indexes based on actual query patterns, not speculation
8. Track migrations in a `migrations` table with name and applied_at
