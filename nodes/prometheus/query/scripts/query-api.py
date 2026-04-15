#!/usr/bin/env python3
"""
Query the Prometheus HTTP API for metric data, rule health, and server state.

Examples:
  python query-api.py instant --query 'up{job="node"}'
  python query-api.py range --query 'rate(http_requests_total[5m])' --start 2026-04-12T00:00:00Z --end 2026-04-12T01:00:00Z --step 30s
  python query-api.py series --match 'up' --match 'process_start_time_seconds'
  python query-api.py targets
  python query-api.py status-tsdb
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import ssl
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://localhost:9090").rstrip("/")


def build_ssl_context() -> ssl.SSLContext | None:
    insecure = os.getenv("PROMETHEUS_INSECURE_SKIP_VERIFY", "false").lower() == "true"
    ca_bundle = os.getenv("PROMETHEUS_CA_BUNDLE")

    if not insecure and not ca_bundle:
        return None

    context = ssl.create_default_context(cafile=ca_bundle)
    if insecure:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    return context


SSL_CONTEXT = build_ssl_context()


def make_headers() -> dict[str, str]:
    headers = {"Accept": "application/json"}
    bearer = os.getenv("PROMETHEUS_BEARER_TOKEN")
    username = os.getenv("PROMETHEUS_BASIC_AUTH_USERNAME")
    password = os.getenv("PROMETHEUS_BASIC_AUTH_PASSWORD", "")

    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    elif username:
        token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
        headers["Authorization"] = f"Basic {token}"

    return headers


def request_json(path: str, params: list[tuple[str, str]] | None = None) -> Any:
    url = f"{PROMETHEUS_URL}{path}"
    if params:
        url = f"{url}?{urlencode(params, doseq=True)}"

    request = Request(url, headers=make_headers(), method="GET")

    try:
        with urlopen(request, context=SSL_CONTEXT) as response:
            payload = response.read().decode("utf-8")
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        print(
            json.dumps(
                {
                    "status": "error",
                    "code": error.code,
                    "url": url,
                    "detail": detail,
                },
                indent=2,
            ),
            file=sys.stderr,
        )
        raise SystemExit(1) from error
    except URLError as error:
        print(
            json.dumps(
                {
                    "status": "error",
                    "url": url,
                    "detail": str(error.reason),
                },
                indent=2,
            ),
            file=sys.stderr,
        )
        raise SystemExit(1) from error

    return json.loads(payload)


def add_common_query_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--query", required=True, help="PromQL expression")
    parser.add_argument("--timeout", help="Per-request evaluation timeout, for example 30s")
    parser.add_argument("--limit", type=int, help="Limit returned series count")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Query Prometheus HTTP API endpoints")
    subparsers = parser.add_subparsers(dest="action", required=True)

    instant = subparsers.add_parser("instant", help="Run an instant query")
    add_common_query_flags(instant)
    instant.add_argument("--time", help="Evaluation time as RFC3339 or Unix timestamp")
    instant.add_argument("--lookback-delta", help="Override the server lookback delta")

    range_query = subparsers.add_parser("range", help="Run a range query")
    add_common_query_flags(range_query)
    range_query.add_argument("--start", required=True, help="Start time")
    range_query.add_argument("--end", required=True, help="End time")
    range_query.add_argument("--step", required=True, help="Query resolution step, for example 30s")

    series = subparsers.add_parser("series", help="List series matching one or more selectors")
    series.add_argument(
        "--match",
        dest="matchers",
        action="append",
        required=True,
        help="Series selector like up or http_requests_total{job='api'}",
    )
    series.add_argument("--start", help="Optional start time")
    series.add_argument("--end", help="Optional end time")

    subparsers.add_parser("targets", help="List active and dropped scrape targets")
    subparsers.add_parser("rules", help="List loaded rule groups")
    subparsers.add_parser("alerts", help="List active alerts")
    subparsers.add_parser("status-config", help="Fetch the loaded server configuration")
    subparsers.add_parser("status-tsdb", help="Fetch TSDB cardinality and head stats")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.action == "instant":
        params: list[tuple[str, str]] = [("query", args.query)]
        if args.time:
            params.append(("time", args.time))
        if args.timeout:
            params.append(("timeout", args.timeout))
        if args.limit is not None:
            params.append(("limit", str(args.limit)))
        if args.lookback_delta:
            params.append(("lookback_delta", args.lookback_delta))
        payload = request_json("/api/v1/query", params)
    elif args.action == "range":
        params = [
            ("query", args.query),
            ("start", args.start),
            ("end", args.end),
            ("step", args.step),
        ]
        if args.timeout:
            params.append(("timeout", args.timeout))
        if args.limit is not None:
            params.append(("limit", str(args.limit)))
        payload = request_json("/api/v1/query_range", params)
    elif args.action == "series":
        params = [("match[]", matcher) for matcher in args.matchers]
        if args.start:
            params.append(("start", args.start))
        if args.end:
            params.append(("end", args.end))
        payload = request_json("/api/v1/series", params)
    elif args.action == "targets":
        payload = request_json("/api/v1/targets")
    elif args.action == "rules":
        payload = request_json("/api/v1/rules")
    elif args.action == "alerts":
        payload = request_json("/api/v1/alerts")
    elif args.action == "status-config":
        payload = request_json("/api/v1/status/config")
    elif args.action == "status-tsdb":
        payload = request_json("/api/v1/status/tsdb")
    else:
        parser.error(f"Unsupported action: {args.action}")
        return

    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
