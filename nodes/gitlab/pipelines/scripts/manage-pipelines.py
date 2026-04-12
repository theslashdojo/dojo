#!/usr/bin/env python3
"""List, inspect, create, retry, cancel, and inspect variables for GitLab pipelines."""

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


def request_json(
    method: str,
    path: str,
    *,
    query: dict[str, Any] | None = None,
    json_body: dict[str, Any] | None = None,
) -> Any:
    url = f"{base_url()}{path}"
    if query:
        cleaned_query = {key: value for key, value in query.items() if value is not None}
        if cleaned_query:
            url = f"{url}?{parse.urlencode(cleaned_query, doseq=True)}"

    headers = {"Accept": "application/json", **auth_headers()}
    data: bytes | None = None
    if json_body is not None:
        cleaned_body = {key: value for key, value in json_body.items() if value is not None}
        data = json.dumps(cleaned_body).encode("utf-8")
        headers["Content-Type"] = "application/json"

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


def summarize_pipeline(pipeline: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": pipeline.get("id"),
        "iid": pipeline.get("iid"),
        "status": pipeline.get("status"),
        "ref": pipeline.get("ref"),
        "source": pipeline.get("source"),
        "webUrl": pipeline.get("web_url"),
        "createdAt": pipeline.get("created_at"),
        "updatedAt": pipeline.get("updated_at"),
    }


def pipeline_path(project: str, pipeline_id: int | None = None) -> str:
    base = f"/projects/{project_ref(project)}/pipelines"
    return base if pipeline_id is None else f"{base}/{pipeline_id}"


def parse_key_value(items: list[str] | None, *, typed: bool = False, variable_type: str = "env_var") -> list[dict[str, Any]] | dict[str, Any]:
    if typed:
        result: dict[str, Any] = {}
        for item in items or []:
            if "=" not in item:
                raise SystemExit(f"Expected KEY=VALUE for --input, got: {item}")
            key, raw_value = item.split("=", 1)
            try:
                value = json.loads(raw_value)
            except json.JSONDecodeError:
                value = raw_value
            result[key] = value
        return result

    result_list: list[dict[str, Any]] = []
    for item in items or []:
        if "=" not in item:
            raise SystemExit(f"Expected KEY=VALUE, got: {item}")
        key, value = item.split("=", 1)
        result_list.append({"key": key, "value": value, "variable_type": variable_type})
    return result_list


def cmd_list(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json(
        "GET",
        pipeline_path(args.project),
        query={
            "ref": args.ref,
            "status": args.status,
            "source": args.source,
            "scope": args.scope,
            "page": args.page,
            "per_page": args.per_page,
        },
    )
    return [summarize_pipeline(pipeline) for pipeline in response]


def cmd_get(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json("GET", pipeline_path(args.project, args.pipeline_id))
    return summarize_pipeline(response)


def cmd_create(args: argparse.Namespace) -> dict[str, Any]:
    variables = parse_key_value(args.var, typed=False, variable_type="env_var")
    variables += parse_key_value(args.file_var, typed=False, variable_type="file")
    inputs = parse_key_value(args.input, typed=True)
    body: dict[str, Any] = {}
    if variables:
        body["variables"] = variables
    if inputs:
        body["inputs"] = inputs
    response = request_json(
        "POST",
        f"/projects/{project_ref(args.project)}/pipeline",
        query={"ref": args.ref},
        json_body=body or None,
    )
    return summarize_pipeline(response)


def cmd_retry(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json("POST", f"{pipeline_path(args.project, args.pipeline_id)}/retry")
    return summarize_pipeline(response)


def cmd_cancel(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json("POST", f"{pipeline_path(args.project, args.pipeline_id)}/cancel")
    return summarize_pipeline(response)


def cmd_variables(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json("GET", f"{pipeline_path(args.project, args.pipeline_id)}/variables")
    return response


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List project pipelines")
    list_parser.add_argument("project")
    list_parser.add_argument("--ref")
    list_parser.add_argument("--status")
    list_parser.add_argument("--source")
    list_parser.add_argument("--scope")
    list_parser.add_argument("--page", type=int, default=1)
    list_parser.add_argument("--per-page", type=int, default=20)
    list_parser.set_defaults(func=cmd_list)

    get_parser = subparsers.add_parser("get", help="Get one pipeline")
    get_parser.add_argument("project")
    get_parser.add_argument("pipeline_id", type=int)
    get_parser.set_defaults(func=cmd_get)

    create_parser = subparsers.add_parser("create", help="Create a pipeline on a ref")
    create_parser.add_argument("project")
    create_parser.add_argument("ref")
    create_parser.add_argument("--var", action="append", default=[], help="Pipeline variable KEY=VALUE")
    create_parser.add_argument("--file-var", action="append", default=[], help="File variable KEY=VALUE")
    create_parser.add_argument("--input", action="append", default=[], help="Typed input KEY=JSON_OR_STRING")
    create_parser.set_defaults(func=cmd_create)

    retry_parser = subparsers.add_parser("retry", help="Retry a pipeline")
    retry_parser.add_argument("project")
    retry_parser.add_argument("pipeline_id", type=int)
    retry_parser.set_defaults(func=cmd_retry)

    cancel_parser = subparsers.add_parser("cancel", help="Cancel a pipeline")
    cancel_parser.add_argument("project")
    cancel_parser.add_argument("pipeline_id", type=int)
    cancel_parser.set_defaults(func=cmd_cancel)

    variables_parser = subparsers.add_parser("variables", help="List variables attached to a pipeline")
    variables_parser.add_argument("project")
    variables_parser.add_argument("pipeline_id", type=int)
    variables_parser.set_defaults(func=cmd_variables)

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
