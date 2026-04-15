# Pandas Recipes

## Install Extras

```bash
python -m pip install "pandas[performance,excel,parquet]"
```

Useful optional dependencies:

| Need | Package family |
|---|---|
| Parquet and Arrow-backed dtypes | `pyarrow` |
| Excel read/write | `openpyxl`, `xlsxwriter` |
| Faster expressions | `numexpr` |
| Compression formats | Python stdlib plus optional codecs |
| Plotting via `DataFrame.plot` | `matplotlib` |

## Dtype Choices

| Data | Preferred dtype | Notes |
|---|---|---|
| Identifiers | `string` | Avoid numeric coercion of leading zeros. |
| Low-cardinality text | `category` | Saves memory for repeated values. |
| Integers with missing values | `Int64` or Arrow integer | Plain `int64` cannot represent missing values. |
| Booleans with missing values | `boolean` | Nullable BooleanDtype, not Python `bool`. |
| Timestamps | `datetime64[ns]` or timezone-aware datetime | Parse with `utc=True` for external data. |
| Money | integer cents or Decimal object | Float can create rounding artifacts. |

## Cleaning Template

```python
import pandas as pd

raw = pd.read_csv("input.csv", dtype_backend="numpy_nullable")
clean = (
    raw
    .rename(columns=lambda c: c.strip().lower().replace(" ", "_"))
    .assign(
        created_at=lambda d: pd.to_datetime(d["created_at"], errors="coerce", utc=True),
        amount=lambda d: pd.to_numeric(d["amount"], errors="coerce"),
        status=lambda d: d["status"].astype("string").str.strip().str.lower(),
    )
    .dropna(subset=["created_at", "amount"])
    .drop_duplicates()
)
clean.to_parquet("clean.parquet", index=False)
```

## Join Audit

```python
joined = left.merge(
    right,
    on="account_id",
    how="left",
    validate="many_to_one",
    indicator=True,
)
unmatched = joined.loc[joined["_merge"].eq("left_only")]
```

## Groupby Summary

```python
summary = (
    orders
    .groupby(["region", "status"], dropna=False)
    .agg(
        orders=("order_id", "nunique"),
        revenue=("amount", "sum"),
        average_order=("amount", "mean"),
    )
    .reset_index()
    .sort_values(["region", "revenue"], ascending=[True, False])
)
```

## Time-Series Summary

```python
events["ts"] = pd.to_datetime(events["ts"], errors="coerce", utc=True)
daily = (
    events
    .dropna(subset=["ts"])
    .set_index("ts")
    .sort_index()
    .resample("D")
    .agg(events=("event_id", "count"), users=("user_id", "nunique"))
    .reset_index()
)
```

## Memory Checklist

1. Read only needed columns with `usecols=` or Parquet `columns=`.
2. Sample first with `nrows=` for CSV or row-group-aware tools for Parquet.
3. Convert repeated strings to `category`.
4. Use nullable or Arrow-backed dtypes for missing-heavy columns.
5. Write intermediate results to Parquet, not CSV.
6. Use `chunksize=` for CSV streaming reductions.
7. Move large joins or scans to [[duckdb]] when data is larger than memory.
