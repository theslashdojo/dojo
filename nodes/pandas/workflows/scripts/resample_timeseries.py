#!/usr/bin/env python3
"""Resample timestamped rows with pandas date parsing and time-based grouping."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from pandas_utils import emit_json, flatten_columns, parse_agg, parse_list, read_frame, write_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input dataset path")
    parser.add_argument("output", help="Output dataset path")
    parser.add_argument("--input-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--output-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--date-column", required=True, help="Column containing timestamps")
    parser.add_argument("--freq", required=True, help="Pandas offset alias such as D, W, ME, QE, h, 15min")
    parser.add_argument("--group-by", help="Optional comma-separated entity columns to group before resampling")
    parser.add_argument("--agg-json", help="JSON aggregation object, for example '{\"amount\":\"sum\"}'")
    parser.add_argument("--agg", action="append", help="Repeatable column:function aggregation")
    parser.add_argument("--utc", action="store_true", help="Parse timestamps as UTC")
    parser.add_argument("--index", action="store_true", help="Write output index")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    df = read_frame(args.input, fmt=args.input_format)
    df[args.date_column] = pd.to_datetime(df[args.date_column], errors="coerce", utc=args.utc)
    invalid_dates = int(df[args.date_column].isna().sum())
    df = df.dropna(subset=[args.date_column]).set_index(args.date_column).sort_index()

    agg = parse_agg(args.agg_json, args.agg)
    if not agg:
        numeric_columns = df.select_dtypes(include="number").columns.tolist()
        if not numeric_columns:
            raise ValueError("No numeric columns found. Provide --agg for explicit aggregations.")
        agg = {column: "sum" for column in numeric_columns}

    group_by = parse_list(args.group_by)
    if group_by:
        result = df.groupby(group_by).resample(args.freq).agg(agg).reset_index()
    else:
        result = df.resample(args.freq).agg(agg).reset_index()
    result = flatten_columns(result)
    write_frame(result, args.output, fmt=args.output_format, index=args.index)
    emit_json(
        {
            "input": str(Path(args.input)),
            "output": str(Path(args.output)),
            "input_rows": int(len(df) + invalid_dates),
            "invalid_dates": invalid_dates,
            "output_rows": int(len(result)),
            "date_column": args.date_column,
            "frequency": args.freq,
            "group_by": group_by or [],
            "aggregations": agg,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
