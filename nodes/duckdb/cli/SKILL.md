---
name: cli
description: Operate DuckDB from the command line for local SQL analytics; use when an agent needs to query CSV, Parquet, JSON, DataFrames, or DuckDB files without a database server.
---

# DuckDB CLI

Use this skill when a task needs local analytical SQL, file inspection, format conversion, or repeatable research scripts. DuckDB is embedded: no server, no daemon, and usually no connection string. The CLI can query files directly or open a persistent `.duckdb` database.

## When to Use

- Query CSV, Parquet, JSON, or partitioned file trees with SQL.
- Produce machine-readable JSON or CSV output from a shell command.
- Create or inspect a portable `.duckdb` analytics database.
- Validate dataset shape in CI before a pipeline runs.
- Convert data between CSV, Parquet, and tables.
- Run one-off research analysis without provisioning PostgreSQL.

## Fast Path

```bash
# Count rows in a file
duckdb -json -c "SELECT count(*) AS rows FROM 'events.parquet';"

# Inspect schema, stats, and sample rows
nodes/duckdb/cli/scripts/inspect-file.sh events.parquet --sample 20 --output table

# Run committed SQL against a persistent database
nodes/duckdb/cli/scripts/run-sql.sh --db analysis.duckdb --file report.sql --output json
```

## Workflow

1. Identify the data surface: local file, glob, remote URL, S3 path, DataFrame, or `.duckdb` file.
2. Inspect before transforming: run `inspect-file.sh` or `DESCRIBE SELECT * FROM ...`.
3. Write SQL with explicit `ORDER BY` for reports and `LIMIT` for exploratory samples.
4. Choose output: table for humans, JSON for agents, CSV/Parquet via `COPY` for files.
5. Persist only when useful: create a `.duckdb` file for reusable tables, views, macros, or checkpoints.
6. Tune only after measuring: start with `EXPLAIN`, `EXPLAIN ANALYZE`, and `SUMMARIZE`.

## CLI Commands

```bash
# In-memory SQL
duckdb -c "SELECT 42 AS answer;"

# Persistent database
duckdb analysis.duckdb -c "CREATE TABLE events AS SELECT * FROM 'events.parquet';"

# Read-only inspection
duckdb -readonly analysis.duckdb -c "SELECT count() FROM events;"

# Output modes
duckdb -json -c "SELECT * FROM 'events.csv' LIMIT 5;"
duckdb -csv -c "SELECT * FROM 'events.parquet' LIMIT 5;"
duckdb -markdown -c "SELECT status, count() FROM 'events.parquet' GROUP BY ALL;"

# Interactive help
duckdb
.help
.tables
.schema
.timer on
```

## Scripts

`scripts/run-sql.sh` executes direct SQL or a SQL file.

```bash
nodes/duckdb/cli/scripts/run-sql.sh \
  --db analysis.duckdb \
  --sql "SELECT date_trunc('day', ts) AS day, count() FROM events GROUP BY ALL ORDER BY ALL" \
  --output json
```

`scripts/inspect-file.sh` reports input, inferred format, row count, schema, summary statistics, and sample rows.

```bash
nodes/duckdb/cli/scripts/inspect-file.sh "data/events/**/*.parquet" \
  --format parquet \
  --sample 10 \
  --output table
```

## SQL Patterns

```sql
-- Query a file directly
SELECT status, count() AS n
FROM read_parquet('events/*.parquet')
GROUP BY ALL
ORDER BY ALL;

-- Friendly SQL
SELECT * EXCLUDE (raw_payload)
FROM events
WHERE status = 'paid'
ORDER BY ALL;

-- Top-N per group
SELECT region, max_by(customer_id, revenue, 5) AS top_customers
FROM sales
GROUP BY region;

-- Reusable view over partitioned files
CREATE OR REPLACE VIEW events AS
SELECT *
FROM read_parquet('warehouse/events/**/*.parquet', hive_partitioning = true);
```

## Files

```sql
-- CSV with inferred schema
SELECT * FROM read_csv('input.csv', union_by_name = true);

-- JSON and JSON Lines
SELECT * FROM read_json_auto('records.ndjson');

-- Parquet globs
SELECT * FROM read_parquet(['a/*.parquet', 'b/*.parquet'], union_by_name = true);

-- Convert CSV to Parquet
COPY (
  SELECT * FROM read_csv('input.csv', union_by_name = true)
) TO 'output.parquet' (FORMAT parquet);

-- Export report as CSV
COPY (
  SELECT status, count() AS n FROM events GROUP BY status ORDER BY status
) TO 'status_counts.csv' (HEADER, DELIMITER ',');
```

## Python

Use Python when the workflow needs parameters, DataFrames, Arrow objects, or notebook ergonomics.

```python
import duckdb

con = duckdb.connect("analysis.duckdb")
con.execute("SET threads = 4")
rows = con.execute(
    "SELECT * FROM events WHERE status = ? LIMIT ?",
    ["paid", 100],
).fetchall()

df = con.sql("""
    SELECT date_trunc('day', ts) AS day, count()
    FROM read_parquet('events/*.parquet')
    GROUP BY ALL
    ORDER BY ALL
""").df()
```

DuckDB Python can also query visible Pandas, Polars, NumPy, Arrow, and relation objects by variable name. Register objects explicitly when variable lookup is ambiguous.

## Extensions

```sql
INSTALL httpfs;
LOAD httpfs;

INSTALL spatial;
LOAD spatial;

SELECT extension_name, loaded, installed
FROM duckdb_extensions()
ORDER BY extension_name;
```

Many core extensions autoload when a query needs them, for example reading an HTTPS file with `httpfs`. Explicit `INSTALL` and `LOAD` is clearer for reproducible scripts.

## Secrets and Remote Files

Prefer `CREATE SECRET` over hard-coded credentials. Example for S3-compatible storage:

```sql
CREATE OR REPLACE SECRET s3_data (
  TYPE s3,
  KEY_ID '...',
  SECRET '...',
  REGION 'us-east-1'
);

SELECT count()
FROM read_parquet('s3://bucket/path/*.parquet');
```

For CI, inject credentials through environment variables or a secret manager and generate the secret at runtime.

## Performance

Start with measurement:

```sql
EXPLAIN SELECT * FROM events WHERE status = 'paid';
EXPLAIN ANALYZE SELECT status, count() FROM events GROUP BY status;
SUMMARIZE SELECT * FROM events;
```

Common tuning:

```sql
SET threads = 4;
SET memory_limit = '8GB';
SET temp_directory = '/tmp/duckdb-spill';
SET preserve_insertion_order = false;
```

Use Parquet for repeated analytics, select only needed columns, filter early, and write partitioned outputs when downstream tools need partition pruning.

## Troubleshooting

- Parser error: check quotes, semicolons, and shell escaping.
- Binder error: a column/table name is wrong or ambiguous; run `DESCRIBE SELECT * FROM ...`.
- CSV type error: increase sample size or pass explicit types to `read_csv`.
- Out of memory: set `memory_limit`, `temp_directory`, or `preserve_insertion_order = false`.
- Extension install failure: check network access and whether the extension repository is allowed.
- S3 access denied: verify `CREATE SECRET` scope, region, endpoint, and session token.

## References

Bulky official-doc links and notes live in `references/duckdb-official-docs.md`.
