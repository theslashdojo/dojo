#!/usr/bin/env python3
"""Shared helpers for pandas workflow scripts."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pandas as pd


def infer_format(path: str, requested: str = "auto") -> str:
    if requested != "auto":
        return requested

    suffixes = "".join(Path(path).suffixes).lower()
    if suffixes.endswith(".csv") or suffixes.endswith(".csv.gz"):
        return "csv"
    if suffixes.endswith(".tsv") or suffixes.endswith(".tsv.gz"):
        return "tsv"
    if suffixes.endswith(".jsonl") or suffixes.endswith(".ndjson"):
        return "jsonl"
    if suffixes.endswith(".json") or suffixes.endswith(".json.gz"):
        return "json"
    if suffixes.endswith(".parquet") or suffixes.endswith(".pq"):
        return "parquet"
    if suffixes.endswith(".xlsx") or suffixes.endswith(".xls"):
        return "excel"
    raise ValueError(f"Cannot infer file format from extension: {path}")


def parse_list(value: str | None) -> list[str] | None:
    if not value:
        return None
    return [part.strip() for part in value.split(",") if part.strip()]


def _with_optional_dtype_backend(func, kwargs: dict[str, Any], dtype_backend: str | None):
    if not dtype_backend:
        return func(**kwargs)
    try:
        return func(**{**kwargs, "dtype_backend": dtype_backend})
    except TypeError:
        return func(**kwargs)


def read_frame(
    path: str,
    *,
    fmt: str = "auto",
    sheet: str | int | None = None,
    nrows: int | None = None,
    columns: list[str] | None = None,
    parse_dates: list[str] | None = None,
    dtype_backend: str | None = None,
) -> pd.DataFrame:
    fmt = infer_format(path, fmt)
    common: dict[str, Any] = {}
    if parse_dates and fmt in {"csv", "tsv"}:
        common["parse_dates"] = parse_dates

    if fmt == "csv":
        kwargs = {"filepath_or_buffer": path, **common}
        if nrows:
            kwargs["nrows"] = nrows
        if columns:
            kwargs["usecols"] = columns
        return _with_optional_dtype_backend(pd.read_csv, kwargs, dtype_backend)

    if fmt == "tsv":
        kwargs = {"filepath_or_buffer": path, "sep": "\t", **common}
        if nrows:
            kwargs["nrows"] = nrows
        if columns:
            kwargs["usecols"] = columns
        return _with_optional_dtype_backend(pd.read_csv, kwargs, dtype_backend)

    if fmt == "json":
        kwargs = {"path_or_buf": path}
        df = _with_optional_dtype_backend(pd.read_json, kwargs, dtype_backend)
    elif fmt == "jsonl":
        kwargs = {"path_or_buf": path, "lines": True}
        df = _with_optional_dtype_backend(pd.read_json, kwargs, dtype_backend)
    elif fmt == "parquet":
        kwargs = {"path": path}
        if columns:
            kwargs["columns"] = columns
        return _with_optional_dtype_backend(pd.read_parquet, kwargs, dtype_backend)
    elif fmt == "excel":
        kwargs = {"io": path}
        if sheet is not None:
            kwargs["sheet_name"] = sheet
        if nrows:
            kwargs["nrows"] = nrows
        if columns:
            kwargs["usecols"] = columns
        df = _with_optional_dtype_backend(pd.read_excel, kwargs, dtype_backend)
    else:
        raise ValueError(f"Unsupported input format: {fmt}")

    if columns:
        df = df.loc[:, columns]
    if parse_dates:
        for column in parse_dates:
            df[column] = pd.to_datetime(df[column], errors="coerce")
    if nrows:
        df = df.head(nrows)
    return df


def write_frame(
    df: pd.DataFrame,
    path: str,
    *,
    fmt: str = "auto",
    index: bool = False,
    json_lines: bool = False,
    compression: str | None = None,
) -> None:
    fmt = infer_format(path, fmt)
    kwargs: dict[str, Any] = {"index": index}
    if compression:
        kwargs["compression"] = compression

    if fmt == "csv":
        df.to_csv(path, **kwargs)
    elif fmt == "tsv":
        df.to_csv(path, sep="\t", **kwargs)
    elif fmt == "json":
        df.to_json(path, orient="records", lines=json_lines, date_format="iso")
    elif fmt == "jsonl":
        df.to_json(path, orient="records", lines=True, date_format="iso")
    elif fmt == "parquet":
        df.to_parquet(path, index=index)
    elif fmt == "excel":
        df.to_excel(path, index=index)
    else:
        raise ValueError(f"Unsupported output format: {fmt}")


def parse_agg(value: str | None, repeated: list[str] | None = None) -> dict[str, Any]:
    if value:
        data = json.loads(value)
        if not isinstance(data, dict):
            raise ValueError("--agg JSON must be an object like {\"amount\":\"sum\"}")
        return data

    result: dict[str, Any] = {}
    for item in repeated or []:
        if ":" not in item:
            raise ValueError(f"Aggregation must use column:function syntax: {item}")
        column, func = item.split(":", 1)
        column = column.strip()
        func = func.strip()
        if not column or not func:
            raise ValueError(f"Invalid aggregation spec: {item}")
        if column in result:
            existing = result[column]
            if isinstance(existing, list):
                existing.append(func)
            else:
                result[column] = [existing, func]
        else:
            result[column] = func
    return result


def flatten_columns(df: pd.DataFrame) -> pd.DataFrame:
    if not isinstance(df.columns, pd.MultiIndex):
        return df
    df = df.copy()
    df.columns = [
        "_".join(str(part) for part in column if str(part) not in {"", "None"})
        for column in df.columns.to_flat_index()
    ]
    return df


def json_default(value: Any):
    if hasattr(value, "item"):
        return value.item()
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def emit_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True, default=json_default))
