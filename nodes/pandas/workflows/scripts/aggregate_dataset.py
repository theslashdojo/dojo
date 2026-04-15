#!/usr/bin/env python3
"""Group a dataset by one or more columns and aggregate numeric or named columns."""

from __future__ import annotations

import argparse
from pathlib import Path

from pandas_utils import emit_json, flatten_columns, parse_agg, parse_list, read_frame, write_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input dataset path")
    parser.add_argument("output", help="Output dataset path")
    parser.add_argument("--input-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--output-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--by", required=True, help="Comma-separated group key columns")
    parser.add_argument("--agg-json", help="JSON aggregation object, for example '{\"amount\":[\"sum\",\"mean\"]}'")
    parser.add_argument("--agg", action="append", help="Repeatable column:function aggregation, for example --agg amount:sum")
    parser.add_argument("--include-na", action="store_true", help="Keep NA values as explicit group keys")
    parser.add_argument("--sort", action="store_true", help="Sort group keys")
    parser.add_argument("--index", action="store_true", help="Write output index")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    by = parse_list(args.by) or []
    agg = parse_agg(args.agg_json, args.agg)
    if not agg:
        raise ValueError("Provide --agg-json or at least one --agg column:function")

    df = read_frame(args.input, fmt=args.input_format)
    grouped = (
        df.groupby(by, dropna=not args.include_na, sort=args.sort)
        .agg(agg)
        .reset_index()
    )
    grouped = flatten_columns(grouped)
    write_frame(grouped, args.output, fmt=args.output_format, index=args.index)
    emit_json(
        {
            "input": str(Path(args.input)),
            "output": str(Path(args.output)),
            "input_rows": int(len(df)),
            "output_rows": int(len(grouped)),
            "group_keys": by,
            "aggregations": agg,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
