#!/usr/bin/env python3
"""Join two tabular datasets with pandas.merge and write the result."""

from __future__ import annotations

import argparse
from pathlib import Path

from pandas_utils import emit_json, parse_list, read_frame, write_frame


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left", help="Left dataset path")
    parser.add_argument("right", help="Right dataset path")
    parser.add_argument("output", help="Output dataset path")
    parser.add_argument("--left-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--right-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--output-format", default="auto", choices=["auto", "csv", "tsv", "json", "jsonl", "excel", "parquet"])
    parser.add_argument("--on", help="Comma-separated join keys shared by both frames")
    parser.add_argument("--left-on", help="Comma-separated left join keys")
    parser.add_argument("--right-on", help="Comma-separated right join keys")
    parser.add_argument("--how", default="inner", choices=["inner", "left", "right", "outer", "cross"])
    parser.add_argument("--validate", choices=["one_to_one", "one_to_many", "many_to_one", "many_to_many"])
    parser.add_argument("--indicator", action="store_true", help="Add _merge column showing source side")
    parser.add_argument("--suffixes", default="_left,_right", help="Comma-separated suffixes for overlapping columns")
    parser.add_argument("--index", action="store_true", help="Write output index")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    left = read_frame(args.left, fmt=args.left_format)
    right = read_frame(args.right, fmt=args.right_format)
    suffixes = tuple(parse_list(args.suffixes) or ["_left", "_right"])
    if len(suffixes) != 2:
        raise ValueError("--suffixes must contain exactly two comma-separated values")

    merged = left.merge(
        right,
        how=args.how,
        on=parse_list(args.on),
        left_on=parse_list(args.left_on),
        right_on=parse_list(args.right_on),
        validate=args.validate,
        indicator=args.indicator,
        suffixes=suffixes,
    )
    write_frame(merged, args.output, fmt=args.output_format, index=args.index)
    emit_json(
        {
            "left": str(Path(args.left)),
            "right": str(Path(args.right)),
            "output": str(Path(args.output)),
            "left_rows": int(len(left)),
            "right_rows": int(len(right)),
            "output_rows": int(len(merged)),
            "output_columns": int(len(merged.columns)),
            "how": args.how,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
