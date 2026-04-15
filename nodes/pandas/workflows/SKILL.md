---
name: workflows
description: Execute pandas-based data analysis workflows for CSV, Excel, JSON, Parquet, SQL-like joins, cleaning, transformations, groupby summaries, time-series resampling, and memory-aware profiling. Use when an agent needs reproducible local tabular data work in Python.
---

# Pandas Workflows

Use this skill when the task is tabular data work in a local workspace: inspect files, clean records, convert formats, join datasets, summarize groups, resample timestamps, or prepare data for reports and tests.

## Workflow

1. Inspect shape, dtypes, missingness, duplicates, and sample rows before changing data.
2. Preserve raw inputs; write cleaned or derived files to a new path.
3. Prefer vectorized pandas operations over row loops and `DataFrame.apply`.
4. Parse dates, IDs, money, booleans, and categories explicitly when inference is risky.
5. Validate joins with `validate=` and, when debugging, `indicator=True`.
6. Store repeatable analytical outputs as Parquet when downstream tools support it.
7. Switch to [[duckdb]] or chunking when data does not fit comfortably in memory.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install "pandas[performance,excel,parquet]"
python - <<'PY'
import pandas as pd
print(pd.__version__)
PY
```

For `uv` projects:

```bash
uv add "pandas[performance,excel,parquet]"
uv run python -c "import pandas as pd; print(pd.__version__)"
```

## Scripts

Run scripts from `nodes/pandas/workflows/scripts/` or by absolute path.

### Profile a dataset

```bash
python nodes/pandas/workflows/scripts/profile_dataset.py data/orders.csv --parse-dates created_at
python nodes/pandas/workflows/scripts/profile_dataset.py data/events.parquet --columns user_id,event,ts
```

Outputs JSON with rows profiled, dtypes, missing percentages, duplicate count, memory usage, numeric summary, samples, and top values.

### Convert formats

```bash
python nodes/pandas/workflows/scripts/convert_dataset.py data/orders.csv data/orders.parquet --parse-dates created_at
python nodes/pandas/workflows/scripts/convert_dataset.py data/input.xlsx data/output.jsonl --sheet 0 --json-lines
```

Use Parquet for typed intermediate artifacts. Use CSV only when a human or legacy system requires it.

### Join tables

```bash
python nodes/pandas/workflows/scripts/join_datasets.py users.csv orders.csv joined.parquet \
  --on user_id --how left --validate one_to_many --indicator
```

Use `--validate one_to_one`, `one_to_many`, `many_to_one`, or `many_to_many` to catch accidental row multiplication.

### Aggregate groups

```bash
python nodes/pandas/workflows/scripts/aggregate_dataset.py orders.csv revenue_by_status.csv \
  --by status --agg amount:sum --agg order_id:nunique

python nodes/pandas/workflows/scripts/aggregate_dataset.py orders.parquet by_region.parquet \
  --by region,status --agg-json '{"amount":["sum","mean"],"order_id":"count"}'
```

### Transform rows and columns

```bash
python nodes/pandas/workflows/scripts/transform_dataset.py raw.csv clean.parquet \
  --rename-json '{"Order ID":"order_id","Amount":"amount"}' \
  --query 'amount > 0' --drop-duplicates --sort-by order_id
```

### Resample time series

```bash
python nodes/pandas/workflows/scripts/resample_timeseries.py events.csv daily.csv \
  --date-column created_at --freq D --agg event_id:count

python nodes/pandas/workflows/scripts/resample_timeseries.py orders.csv monthly.parquet \
  --date-column paid_at --freq ME --group-by region --agg amount:sum --utc
```

## Node Sections

- `pandas/workflows/io`: read and write CSV, TSV, JSON, JSONL, Excel, Parquet, and SQL result sets.
- `pandas/workflows/clean`: handle missing values, duplicates, dtypes, strings, categories, and invalid records.
- `pandas/workflows/transform`: filter, assign, map, reshape, explode, pivot, and build method chains.
- `pandas/workflows/join`: merge, join, concat, validate cardinality, and debug unmatched rows.
- `pandas/workflows/groupby`: split-apply-combine, named aggregations, transform, rolling, and pivot tables.
- `pandas/workflows/time-series`: parse timestamps, localize time zones, resample, shift, rolling windows, and offsets.
- `pandas/workflows/performance`: memory profiling, efficient dtypes, chunking, Parquet, Arrow-backed dtypes, and alternatives.

## Pandas Patterns

Use method chains for reproducible transformations:

```python
clean = (
    raw
    .rename(columns=str.lower)
    .assign(
        created_at=lambda d: pd.to_datetime(d["created_at"], errors="coerce", utc=True),
        amount=lambda d: pd.to_numeric(d["amount"], errors="coerce"),
    )
    .dropna(subset=["created_at", "amount"])
    .drop_duplicates(subset=["order_id"])
)
```

Use semantic column selection:

```python
numeric = df.select_dtypes(include="number")
dates = df.select_dtypes(include="datetime")
subset = df.loc[df["status"].eq("paid"), ["order_id", "amount", "created_at"]]
```

Use vectorized operations:

```python
df["net"] = df["gross"] - df["discount"].fillna(0)
df["email_domain"] = df["email"].str.split("@").str[-1].str.lower()
df["month"] = df["created_at"].dt.to_period("M").dt.to_timestamp()
```

## Edge Cases

- CSV inference can corrupt IDs with leading zeros. Pass `dtype={"zip": "string"}` in custom code.
- Excel files require optional engines such as `openpyxl`; install the `excel` extra.
- Parquet requires `pyarrow` or `fastparquet`; prefer `pyarrow`.
- Missing values use `pd.NA`, `NaN`, and `NaT` depending on dtype. Use nullable dtypes when possible.
- Chained assignment can silently fail. Use `.loc[row_mask, column] = value`.
- Joins can multiply rows. Always check key uniqueness and use `validate=`.
- Time zones matter. Parse external timestamps with `utc=True`, then convert for presentation.

See `references/recipes.md` for compact recipes and dtype guidance.
