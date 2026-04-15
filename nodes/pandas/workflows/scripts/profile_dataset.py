#!/usr/bin/env python3
"""Profile a CSV, JSON, Excel, or Parquet dataset with pandas."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from pandas_utils import emit_json, parse_list, read_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Dataset path: CSV, TSV, JSON, JSONL, Excel, or Parquet")
    parser.add_argument("--format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--sheet", help="Excel sheet name or index")
    parser.add_argument("--limit", type=int, help="Read at most this many rows for profiling")
    parser.add_argument("--columns", help="Comma-separated columns to load")
    parser.add_argument("--parse-dates", help="Comma-separated columns to parse as datetimes")
    parser.add_argument("--dtype-backend", choices=["numpy_nullable", "pyarrow"], help="Optional pandas nullable dtype backend")
    parser.add_argument("--top-values", type=int, default=5, help="Top value count per column")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    sheet = int(args.sheet) if args.sheet and args.sheet.isdigit() else args.sheet
    df = read_frame(
        args.path,
        fmt=args.format,
        sheet=sheet,
        nrows=args.limit,
        columns=parse_list(args.columns),
        parse_dates=parse_list(args.parse_dates),
        dtype_backend=args.dtype_backend,
    )

    missing = df.isna().sum()
    profile = {
        "path": str(Path(args.path)),
        "sampled": bool(args.limit),
        "rows_profiled": int(len(df)),
        "columns": int(len(df.columns)),
        "column_names": [str(column) for column in df.columns],
        "dtypes": {str(column): str(dtype) for column, dtype in df.dtypes.items()},
        "memory_bytes": int(df.memory_usage(deep=True).sum()),
        "duplicate_rows": int(df.duplicated().sum()),
        "missing": {
            str(column): {
                "count": int(count),
                "percent": float(count / len(df) * 100) if len(df) else 0.0,
            }
            for column, count in missing.items()
        },
        "numeric_summary": df.describe(include="number").to_dict(),
        "sample_rows": df.head(5).where(pd.notna(df), None).to_dict(orient="records"),
        "top_values": {},
    }

    if args.top_values > 0:
        for column in df.columns:
            counts = df[column].value_counts(dropna=False).head(args.top_values)
            profile["top_values"][str(column)] = [
                {"value": None if pd.isna(index) else index, "count": int(count)}
                for index, count in counts.items()
            ]

    emit_json(profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
