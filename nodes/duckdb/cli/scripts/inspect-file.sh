#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  inspect-file.sh INPUT [options]

Inspect a CSV, Parquet, or JSON file with DuckDB. INPUT may be a local path,
glob, HTTPS URL, or S3-compatible URL if DuckDB credentials are configured.

Options:
  --format FORMAT  auto, csv, parquet, or json. Default: auto.
  --sample N       Number of sample rows. Default: 10.
  --output MODE    table, csv, json, line, or markdown. Default: table.
  --db PATH        Optional DuckDB database file for the inspection session.
  --readonly       Open --db in read-only mode.
  -h, --help       Show this help.

Examples:
  inspect-file.sh data/events.parquet --sample 20
  inspect-file.sh "s3://bucket/path/*.parquet" --format parquet --output json
USAGE
}

need_duckdb() {
  if ! command -v duckdb >/dev/null 2>&1; then
    echo "error: duckdb CLI is not installed or not on PATH" >&2
    echo "install: https://duckdb.org/docs/stable/installation/" >&2
    exit 127
  fi
}

sql_string() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

detect_format() {
  local input_lc
  input_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$input_lc" in
    *.parquet|*.parquet\?*|*.parquet#*) printf 'parquet' ;;
    *.csv|*.csv.gz|*.tsv|*.tsv.gz|*.csv\?*|*.csv#*) printf 'csv' ;;
    *.json|*.jsonl|*.ndjson|*.json.gz|*.jsonl.gz|*.ndjson.gz|*.json\?*|*.json#*) printf 'json' ;;
    *) printf 'unknown' ;;
  esac
}

input=""
format="auto"
sample=10
output="table"
db_path=""
readonly=0

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

input="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -ge 2 ]] || { echo "error: --format requires a value" >&2; exit 2; }
      format="$2"
      shift 2
      ;;
    --sample|--limit)
      [[ $# -ge 2 ]] || { echo "error: --sample requires a number" >&2; exit 2; }
      sample="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "error: --output requires a mode" >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    --db)
      [[ $# -ge 2 ]] || { echo "error: --db requires a path" >&2; exit 2; }
      db_path="$2"
      shift 2
      ;;
    --readonly)
      readonly=1
      shift
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

if ! [[ "$sample" =~ ^[0-9]+$ ]]; then
  echo "error: --sample must be a non-negative integer" >&2
  exit 2
fi

if [[ "$format" == "auto" ]]; then
  format="$(detect_format "$input")"
fi

case "$format" in
  csv) source_expr="read_csv($(sql_string "$input"), union_by_name = true, filename = true)" ;;
  parquet) source_expr="read_parquet($(sql_string "$input"), union_by_name = true, filename = true)" ;;
  json) source_expr="read_json_auto($(sql_string "$input"), filename = true)" ;;
  *)
    echo "error: could not infer format for '$input'; pass --format csv|parquet|json" >&2
    exit 2
    ;;
esac

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

if [[ -n "$db_path" ]]; then
  args+=("$db_path")
fi

tmp_sql="$(mktemp "${TMPDIR:-/tmp}/duckdb-inspect.XXXXXX.sql")"
trap 'rm -f "$tmp_sql"' EXIT

cat > "$tmp_sql" <<SQL
SELECT 'input' AS metric, $(sql_string "$input") AS value
UNION ALL SELECT 'format', '$format'
UNION ALL SELECT 'rows', CAST(count(*) AS VARCHAR) FROM $source_expr;

DESCRIBE SELECT * FROM $source_expr;

SUMMARIZE SELECT * FROM $source_expr;

SELECT * FROM $source_expr LIMIT $sample;
SQL

exec duckdb "${args[@]}" < "$tmp_sql"
