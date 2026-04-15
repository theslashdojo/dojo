#!/usr/bin/env python3
"""
Inspect and operate Alertmanager status, silences, alerts, and route trees.

Examples:
  python manage-alertmanager.py status
  python manage-alertmanager.py list-silences --filter 'alertname="InstanceDown"'
  python manage-alertmanager.py create-silence --matcher 'alertname=InstanceDown' --comment 'maintenance window'
  python manage-alertmanager.py expire-silence 01234567-89ab-cdef-0123-456789abcdef
  python manage-alertmanager.py validate-config alertmanager.yml
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import ssl
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ALERTMANAGER_URL = os.getenv("ALERTMANAGER_URL", "http://localhost:9093").rstrip("/")


def build_ssl_context() -> ssl.SSLContext | None:
    insecure = os.getenv("ALERTMANAGER_INSECURE_SKIP_VERIFY", "false").lower() == "true"
    ca_bundle = os.getenv("ALERTMANAGER_CA_BUNDLE")

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
    bearer = os.getenv("ALERTMANAGER_BEARER_TOKEN")
    username = os.getenv("ALERTMANAGER_BASIC_AUTH_USERNAME")
    password = os.getenv("ALERTMANAGER_BASIC_AUTH_PASSWORD", "")

    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    elif username:
        token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
        headers["Authorization"] = f"Basic {token}"

    return headers


def request_json(
    path: str,
    method: str = "GET",
    params: list[tuple[str, str]] | None = None,
    payload: Any | None = None,
) -> Any:
    url = f"{ALERTMANAGER_URL}{path}"
    if params:
        url = f"{url}?{urlencode(params, doseq=True)}"

    data = None
    headers = make_headers()
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = Request(url, data=data, headers=headers, method=method)

    try:
        with urlopen(request, context=SSL_CONTEXT) as response:
            body = response.read().decode("utf-8")
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        print(
            json.dumps(
                {"status": "error", "code": error.code, "url": url, "detail": detail},
                indent=2,
            ),
            file=sys.stderr,
        )
        raise SystemExit(1) from error
    except URLError as error:
        print(
            json.dumps(
                {"status": "error", "url": url, "detail": str(error.reason)},
                indent=2,
            ),
            file=sys.stderr,
        )
        raise SystemExit(1) from error

    if not body:
        return {}

    return json.loads(body)


def parse_duration(value: str) -> timedelta:
    units = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}
    total_seconds = 0
    position = 0

    for match in re.finditer(r"(\d+)([smhdw])", value):
        if match.start() != position:
            raise ValueError(f"Unsupported duration format: {value}")
        total_seconds += int(match.group(1)) * units[match.group(2)]
        position = match.end()

    if position != len(value) or total_seconds == 0:
        raise ValueError(f"Unsupported duration format: {value}")

    return timedelta(seconds=total_seconds)


def parse_matcher(expression: str) -> dict[str, Any]:
    for operator in ("!~", "=~", "!=", "="):
        if operator in expression:
            name, value = expression.split(operator, 1)
            return {
                "name": name.strip(),
                "value": value.strip(),
                "isRegex": operator in ("=~", "!~"),
                "isEqual": operator in ("=", "=~"),
            }
    raise ValueError(f"Unsupported matcher expression: {expression}")


def parse_key_value(items: list[str] | None) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in items or []:
        if "=" not in item:
            raise ValueError(f"Expected key=value, got: {item}")
        key, value = item.split("=", 1)
        result[key] = value
    return result


def print_json(payload: Any) -> None:
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")


def run_amtool(arguments: list[str]) -> None:
    amtool_bin = os.getenv("AMTOOL_BIN", "amtool")
    try:
        subprocess.run([amtool_bin, *arguments], check=True)
    except FileNotFoundError as error:
        print(f"Error: amtool not found at {amtool_bin}", file=sys.stderr)
        raise SystemExit(1) from error


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage Alertmanager through API v2 and amtool")
    subparsers = parser.add_subparsers(dest="action", required=True)

    subparsers.add_parser("status", help="Fetch Alertmanager status")

    list_silences = subparsers.add_parser("list-silences", help="List silences")
    list_silences.add_argument("--filter", action="append", help='Matcher expression like alertname="InstanceDown"')

    create_silence = subparsers.add_parser("create-silence", help="Create a silence")
    create_silence.add_argument("--matcher", action="append", required=True, help="Matcher like alertname=InstanceDown or instance=~web-.*")
    create_silence.add_argument("--annotation", action="append", help="Silence annotation key=value")
    create_silence.add_argument("--start", help="RFC3339 start time, default now")
    create_silence.add_argument("--end", help="RFC3339 end time")
    create_silence.add_argument("--duration", default="2h", help="Duration if --end is omitted, default 2h")
    create_silence.add_argument("--created-by", default=os.getenv("USER", "dojo-agent"), help="Silence author")
    create_silence.add_argument("--comment", required=True, help="Reason for the silence")

    expire_silence = subparsers.add_parser("expire-silence", help="Expire a silence by ID")
    expire_silence.add_argument("silence_id", help="Silence UUID")

    alerts = subparsers.add_parser("alerts", help="List alerts")
    alerts.add_argument("--filter", action="append", help='Matcher expression like alertname="InstanceDown"')
    alerts.add_argument("--receiver", help="Receiver regex")

    groups = subparsers.add_parser("groups", help="List grouped alerts")
    groups.add_argument("--filter", action="append", help='Matcher expression like severity="critical"')
    groups.add_argument("--receiver", help="Receiver regex")

    validate_config = subparsers.add_parser("validate-config", help="Validate an Alertmanager config file with amtool")
    validate_config.add_argument("config_file", help="Path to alertmanager.yml")

    routes = subparsers.add_parser("routes", help="Render the route tree with amtool")
    routes.add_argument("--config-file", help="Render routes from a local config file instead of the remote server")

    return parser


def main() -> None:
    args = build_parser().parse_args()

    if args.action == "status":
        print_json(request_json("/api/v2/status"))
        return

    if args.action == "list-silences":
        params = [("filter", item) for item in args.filter or []]
        print_json(request_json("/api/v2/silences", params=params))
        return

    if args.action == "create-silence":
        starts_at = args.start or datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        if args.end:
            ends_at = args.end
        else:
            ends_at = (
                datetime.fromisoformat(starts_at.replace("Z", "+00:00")) + parse_duration(args.duration)
            ).isoformat().replace("+00:00", "Z")

        payload = {
            "matchers": [parse_matcher(item) for item in args.matcher],
            "startsAt": starts_at,
            "endsAt": ends_at,
            "createdBy": args.created_by,
            "comment": args.comment,
            "annotations": parse_key_value(args.annotation),
        }
        print_json(request_json("/api/v2/silences", method="POST", payload=payload))
        return

    if args.action == "expire-silence":
        request_json(f"/api/v2/silence/{args.silence_id}", method="DELETE")
        print_json({"expired": args.silence_id})
        return

    if args.action == "alerts":
        params = [("filter", item) for item in args.filter or []]
        if args.receiver:
            params.append(("receiver", args.receiver))
        print_json(request_json("/api/v2/alerts", params=params))
        return

    if args.action == "groups":
        params = [("filter", item) for item in args.filter or []]
        if args.receiver:
            params.append(("receiver", args.receiver))
        print_json(request_json("/api/v2/alerts/groups", params=params))
        return

    if args.action == "validate-config":
        run_amtool(["check-config", args.config_file])
        return

    if args.action == "routes":
        if args.config_file:
            run_amtool(["config", "routes", f"--config.file={args.config_file}"])
        else:
            run_amtool(["config", "routes", f"--alertmanager.url={ALERTMANAGER_URL}"])
        return

    raise SystemExit(f"Unsupported action: {args.action}")


if __name__ == "__main__":
    main()
