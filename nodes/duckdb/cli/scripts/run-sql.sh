#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run-sql.sh [--db PATH|--memory] (--sql SQL | --file SQL_FILE) [options]

Options:
  --db PATH        DuckDB database file. Defaults to $DUCKDB_DATABASE or memory.
  --memory         Force an in-memory database, ignoring $DUCKDB_DATABASE.
  --sql SQL        SQL statement(s) to execute.
  --file PATH      SQL file to execute.
  --output MODE    table, csv, json, line, or markdown. Default: table.
  --readonly       Open the database in read-only mode.
  --init PATH      DuckDB init file to run before the query.
  -h, --help       Show this help.

Examples:
  run-sql.sh --sql "SELECT count(*) AS rows FROM 'events.parquet'" --output json
  run-sql.sh --db analysis.duckdb --file report.sql --readonly
USAGE
}

need_duckdb() {
  if ! command -v duckdb >/dev/null 2>&1; then
    echo "error: duckdb CLI is not installed or not on PATH" >&2
    echo "install: https://duckdb.org/docs/stable/installation/" >&2
    exit 127
  fi
}

db_path="${DUCKDB_DATABASE:-}"
force_memory=0
sql=""
sql_file=""
output="table"
readonly=0
init_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      [[ $# -ge 2 ]] || { echo "error: --db requires a path" >&2; exit 2; }
      db_path="$2"
      force_memory=0
      shift 2
      ;;
    --memory)
      db_path=""
      force_memory=1
      shift
      ;;
    --sql)
      [[ $# -ge 2 ]] || { echo "error: --sql requires a value" >&2; exit 2; }
      sql="$2"
      shift 2
      ;;
    --file)
      [[ $# -ge 2 ]] || { echo "error: --file requires a path" >&2; exit 2; }
      sql_file="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "error: --output requires a mode" >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    --readonly)
      readonly=1
      shift
      ;;
    --init)
      [[ $# -ge 2 ]] || { echo "error: --init requires a path" >&2; exit 2; }
      init_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$sql" && -n "$sql_file" ]]; then
  echo "error: choose either --sql or --file, not both" >&2
  exit 2
fi

if [[ -z "$sql" && -z "$sql_file" ]]; then
  echo "error: provide --sql or --file" >&2
  usage >&2
  exit 2
fi

if [[ -n "$sql_file" && ! -f "$sql_file" ]]; then
  echo "error: SQL file not found: $sql_file" >&2
  exit 2
fi

if [[ -n "$init_file" && ! -f "$init_file" ]]; then
  echo "error: init file not found: $init_file" >&2
  exit 2
fi

need_duckdb

args=()

case "$output" in
  table) args+=("-table") ;;
  csv) args+=("-csv") ;;
  json) args+=("-json") ;;
  line) args+=("-line") ;;
  markdown) args+=("-markdown") ;;
  *)
    echo "error: unsupported output mode: $output" >&2
    exit 2
    ;;
esac

if [[ "$readonly" -eq 1 ]]; then
  args+=("-readonly")
fi

if [[ -n "$init_file" ]]; then
  args+=("-init" "$init_file")
fi

if [[ -n "$db_path" && "$force_memory" -eq 0 ]]; then
  args+=("$db_path")
fi

if [[ -n "$sql" ]]; then
  exec duckdb "${args[@]}" -c "$sql"
fi

exec duckdb "${args[@]}" < "$sql_file"
