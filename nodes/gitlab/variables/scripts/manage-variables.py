#!/usr/bin/env python3
"""List, inspect, set, and delete GitLab project-level CI/CD variables."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any
from urllib import error, parse, request


class ApiError(RuntimeError):
    def __init__(self, status: int, reason: str, payload: Any) -> None:
        super().__init__(f"{status} {reason}")
        self.status = status
        self.reason = reason
        self.payload = payload


def parse_bool(value: str | bool) -> bool:
    if isinstance(value, bool):
        return value
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise argparse.ArgumentTypeError(f"invalid boolean value: {value}")


def base_url() -> str:
    host = os.getenv("GITLAB_HOST", "https://gitlab.com").strip().rstrip("/")
    if not host.startswith(("https://", "http://")):
        host = f"https://{host}"
    return f"{host}/api/v4"


def auth_headers() -> dict[str, str]:
    token = os.getenv("GITLAB_TOKEN") or os.getenv("GITLAB_ACCESS_TOKEN")
    if token:
        return {"PRIVATE-TOKEN": token}
    oauth = os.getenv("OAUTH_TOKEN")
    if oauth:
        return {"Authorization": f"Bearer {oauth}"}
    job_token = os.getenv("CI_JOB_TOKEN")
    if job_token:
        return {"JOB-TOKEN": job_token}
    raise SystemExit(
        "Set GITLAB_TOKEN, GITLAB_ACCESS_TOKEN, OAUTH_TOKEN, or CI_JOB_TOKEN before running this script."
    )


def project_ref(value: str) -> str:
    return value if value.isdigit() else parse.quote(value, safe="")


def should_debug() -> bool:
    return os.getenv("GITLAB_HTTP_DEBUG", "0").lower() in {"1", "true", "yes", "on"}


def normalize_params(mapping: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for key, value in mapping.items():
        if value is None:
            continue
        if isinstance(value, bool):
            normalized[key] = str(value).lower()
        else:
            normalized[key] = value
    return normalized


def request_json(
    method: str,
    path: str,
    *,
    query: dict[str, Any] | None = None,
    form: dict[str, Any] | None = None,
) -> Any:
    url = f"{base_url()}{path}"
    if query:
        cleaned_query = normalize_params(query)
        if cleaned_query:
            url = f"{url}?{parse.urlencode(cleaned_query, doseq=True)}"

    headers = {"Accept": "application/json", **auth_headers()}
    data: bytes | None = None
    if form is not None:
        cleaned_form = normalize_params(form)
        data = parse.urlencode(cleaned_form, doseq=True).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    if should_debug():
        print(f"{method} {url}", file=sys.stderr)

    req = request.Request(url, method=method, data=data, headers=headers)
    try:
        with request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        try:
            payload: Any = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            payload = raw
        raise ApiError(exc.code, exc.reason, payload) from exc


def variable_path(project: str, key: str | None = None) -> str:
    base = f"/projects/{project_ref(project)}/variables"
    if key is None:
        return base
    return f"{base}/{parse.quote(key, safe='')}"


def summarize_variable(variable: dict[str, Any]) -> dict[str, Any]:
    return {
        "key": variable.get("key"),
        "environmentScope": variable.get("environment_scope"),
        "variableType": variable.get("variable_type"),
        "protected": variable.get("protected"),
        "masked": variable.get("masked"),
        "hidden": variable.get("hidden"),
        "raw": variable.get("raw"),
        "description": variable.get("description"),
    }


def scoped_filter(environment_scope: str | None) -> dict[str, Any]:
    if not environment_scope:
        return {}
    return {"filter[environment_scope]": environment_scope}


def get_existing(project: str, key: str, environment_scope: str | None) -> dict[str, Any] | None:
    try:
        return request_json("GET", variable_path(project, key), query=scoped_filter(environment_scope))
    except ApiError as exc:
        if exc.status == 404:
            return None
        raise


def cmd_list(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json(
        "GET",
        variable_path(args.project),
        query={"page": args.page, "per_page": args.per_page},
    )
    return [summarize_variable(variable) for variable in response]


def cmd_get(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json(
        "GET",
        variable_path(args.project, args.key),
        query=scoped_filter(args.environment_scope),
    )
    return summarize_variable(response)


def cmd_set(args: argparse.Namespace) -> dict[str, Any]:
    common = {
        "value": args.value,
        "description": args.description,
        "environment_scope": args.environment_scope,
        "protected": args.protected,
        "masked": args.masked,
        "raw": args.raw,
        "variable_type": args.variable_type,
    }
    existing = get_existing(args.project, args.key, args.environment_scope)
    if existing:
        form = {**common, **scoped_filter(args.environment_scope)}
        response = request_json("PUT", variable_path(args.project, args.key), form=form)
    else:
        form = {
            "key": args.key,
            **common,
            "hidden": args.hidden,
            "masked_and_hidden": args.masked_and_hidden,
        }
        response = request_json("POST", variable_path(args.project), form=form)
    return summarize_variable(response)


def cmd_delete(args: argparse.Namespace) -> dict[str, Any]:
    request_json(
        "DELETE",
        variable_path(args.project, args.key),
        form=scoped_filter(args.environment_scope) or None,
    )
    return {
        "deleted": True,
        "key": args.key,
        "environmentScope": args.environment_scope or "*",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List project variables")
    list_parser.add_argument("project")
    list_parser.add_argument("--page", type=int, default=1)
    list_parser.add_argument("--per-page", type=int, default=100)
    list_parser.set_defaults(func=cmd_list)

    get_parser = subparsers.add_parser("get", help="Get one variable")
    get_parser.add_argument("project")
    get_parser.add_argument("key")
    get_parser.add_argument("--environment-scope")
    get_parser.set_defaults(func=cmd_get)

    set_parser = subparsers.add_parser("set", help="Create or update a variable")
    set_parser.add_argument("project")
    set_parser.add_argument("key")
    set_parser.add_argument("value")
    set_parser.add_argument("--environment-scope")
    set_parser.add_argument("--description")
    set_parser.add_argument("--variable-type", choices=["env_var", "file"], default="env_var")
    set_parser.add_argument("--protected", type=parse_bool, nargs="?", const=True)
    set_parser.add_argument("--masked", type=parse_bool, nargs="?", const=True)
    set_parser.add_argument("--hidden", type=parse_bool, nargs="?", const=True)
    set_parser.add_argument("--masked-and-hidden", type=parse_bool, nargs="?", const=True)
    set_parser.add_argument("--raw", type=parse_bool, nargs="?", const=True)
    set_parser.set_defaults(func=cmd_set)

    delete_parser = subparsers.add_parser("delete", help="Delete a variable")
    delete_parser.add_argument("project")
    delete_parser.add_argument("key")
    delete_parser.add_argument("--environment-scope")
    delete_parser.set_defaults(func=cmd_delete)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        result = args.func(args)
        print(json.dumps(result, indent=2))
        return 0
    except ApiError as exc:
        print(
            json.dumps(
                {"error": exc.reason, "status": exc.status, "response": exc.payload},
                indent=2,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
