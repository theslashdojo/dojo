#!/usr/bin/env python3
"""Convert tabular datasets between CSV, TSV, JSON, JSONL, Excel, and Parquet."""

from __future__ import annotations

import argparse
from pathlib import Path

from pandas_utils import emit_json, parse_list, read_frame, write_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input dataset path")
    parser.add_argument("output", help="Output dataset path")
    parser.add_argument("--input-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--output-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--sheet", help="Excel sheet name or index")
    parser.add_argument("--columns", help="Comma-separated columns to keep")
    parser.add_argument("--parse-dates", help="Comma-separated columns to parse as datetimes")
    parser.add_argument("--dtype-backend", choices=["numpy_nullable", "pyarrow"], help="Optional pandas nullable dtype backend")
    parser.add_argument("--index", action="store_true", help="Write the pandas index")
    parser.add_argument("--json-lines", action="store_true", help="Write newline-delimited JSON when output is JSON")
    parser.add_argument("--compression", help="Compression name for CSV/TSV outputs, such as gzip")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    sheet = int(args.sheet) if args.sheet and args.sheet.isdigit() else args.sheet
    df = read_frame(
        args.input,
        fmt=args.input_format,
        sheet=sheet,
        columns=parse_list(args.columns),
        parse_dates=parse_list(args.parse_dates),
        dtype_backend=args.dtype_backend,
    )
    write_frame(
        df,
        args.output,
        fmt=args.output_format,
        index=args.index,
        json_lines=args.json_lines,
        compression=args.compression,
    )
    emit_json(
        {
            "input": str(Path(args.input)),
            "output": str(Path(args.output)),
            "rows": int(len(df)),
            "columns": int(len(df.columns)),
            "column_names": [str(column) for column in df.columns],
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
