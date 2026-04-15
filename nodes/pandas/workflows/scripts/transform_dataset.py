#!/usr/bin/env python3
"""Apply common safe pandas transformations to a dataset and write the result."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from pandas_utils import emit_json, parse_list, read_frame, write_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input dataset path")
    parser.add_argument("output", help="Output dataset path")
    parser.add_argument("--input-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--output-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--select", help="Comma-separated columns to keep")
    parser.add_argument("--drop-columns", help="Comma-separated columns to remove")
    parser.add_argument("--rename-json", help="JSON object mapping old column names to new names")
    parser.add_argument("--query", help="pandas DataFrame.query expression for row filtering")
    parser.add_argument("--drop-duplicates", action="store_true", help="Drop duplicate rows")
    parser.add_argument("--dedupe-subset", help="Comma-separated columns for duplicate detection")
    parser.add_argument("--sort-by", help="Comma-separated columns to sort by")
    parser.add_argument("--descending", action="store_true", help="Sort descending")
    parser.add_argument("--index", action="store_true", help="Write output index")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    df = read_frame(args.input, fmt=args.input_format)
    before_rows = len(df)

    if args.rename_json:
        rename_map = json.loads(args.rename_json)
        if not isinstance(rename_map, dict):
            raise ValueError("--rename-json must be an object mapping old names to new names")
        df = df.rename(columns=rename_map)

    selected = parse_list(args.select)
    if selected:
        df = df.loc[:, selected]

    dropped = parse_list(args.drop_columns)
    if dropped:
        df = df.drop(columns=dropped)

    if args.query:
        df = df.query(args.query)

    if args.drop_duplicates:
        df = df.drop_duplicates(subset=parse_list(args.dedupe_subset))

    sort_by = parse_list(args.sort_by)
    if sort_by:
        df = df.sort_values(sort_by, ascending=not args.descending)

    write_frame(df, args.output, fmt=args.output_format, index=args.index)
    emit_json(
        {
            "input": str(Path(args.input)),
            "output": str(Path(args.output)),
            "input_rows": int(before_rows),
            "output_rows": int(len(df)),
            "output_columns": int(len(df.columns)),
            "column_names": [str(column) for column in df.columns],
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
