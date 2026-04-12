#!/usr/bin/env python3
"""List, inspect, create, and update GitLab projects."""

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


def parse_topics(value: str | None) -> list[str] | None:
    if value is None:
        return None
    return [item.strip() for item in value.split(",") if item.strip()]


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
    json_body: dict[str, Any] | None = None,
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
    elif json_body is not None:
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


def summarize_project(project: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": project.get("id"),
        "name": project.get("name"),
        "pathWithNamespace": project.get("path_with_namespace"),
        "defaultBranch": project.get("default_branch"),
        "visibility": project.get("visibility"),
        "webUrl": project.get("web_url"),
        "sshUrl": project.get("ssh_url_to_repo"),
        "httpUrl": project.get("http_url_to_repo"),
        "archived": project.get("archived"),
        "topics": project.get("topics", []),
    }


def cmd_list(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json(
        "GET",
        "/projects",
        query={
            "search": args.search,
            "owned": args.owned or None,
            "membership": args.membership or None,
            "visibility": args.visibility,
            "page": args.page,
            "per_page": args.per_page,
            "order_by": args.order_by,
            "simple": True,
        },
    )
    return [summarize_project(project) for project in response]


def cmd_get(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json(
        "GET",
        f"/projects/{project_ref(args.project)}",
        query={"statistics": args.statistics or None},
    )
    return summarize_project(response)


def cmd_create(args: argparse.Namespace) -> dict[str, Any]:
    if args.default_branch and args.initialize_with_readme is not True:
        raise SystemExit("--default-branch at creation time requires --initialize-with-readme true")

    payload = {
        "name": args.name,
        "path": args.path,
        "namespace_id": args.namespace_id,
        "description": args.description,
        "visibility": args.visibility,
        "default_branch": args.default_branch,
        "initialize_with_readme": args.initialize_with_readme,
        "topics": parse_topics(args.topics),
        "merge_method": args.merge_method,
        "issues_access_level": args.issues_access_level,
        "merge_requests_access_level": args.merge_requests_access_level,
        "builds_access_level": args.builds_access_level,
    }
    response = request_json("POST", "/projects", json_body=payload)
    return summarize_project(response)


def cmd_update(args: argparse.Namespace) -> dict[str, Any]:
    payload = {
        "description": args.description,
        "visibility": args.visibility,
        "default_branch": args.default_branch,
        "topics": parse_topics(args.topics),
        "issues_access_level": args.issues_access_level,
        "merge_requests_access_level": args.merge_requests_access_level,
        "builds_access_level": args.builds_access_level,
        "remove_source_branch_after_merge": args.remove_source_branch_after_merge,
    }
    if all(value is None for value in payload.values()):
        raise SystemExit("Provide at least one field to update.")

    response = request_json(
        "PUT",
        f"/projects/{project_ref(args.project)}",
        json_body=payload,
    )
    return summarize_project(response)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List visible projects")
    list_parser.add_argument("--search")
    list_parser.add_argument("--owned", action="store_true")
    list_parser.add_argument("--membership", action="store_true")
    list_parser.add_argument("--visibility", choices=["private", "internal", "public"])
    list_parser.add_argument("--page", type=int, default=1)
    list_parser.add_argument("--per-page", type=int, default=20)
    list_parser.add_argument(
        "--order-by",
        choices=["id", "name", "path", "created_at", "updated_at", "star_count", "last_activity_at"],
        default="last_activity_at",
    )
    list_parser.set_defaults(func=cmd_list)

    get_parser = subparsers.add_parser("get", help="Get one project by ID or path")
    get_parser.add_argument("project")
    get_parser.add_argument("--statistics", action="store_true")
    get_parser.set_defaults(func=cmd_get)

    create_parser = subparsers.add_parser("create", help="Create a project")
    create_parser.add_argument("name")
    create_parser.add_argument("--path")
    create_parser.add_argument("--namespace-id", type=int)
    create_parser.add_argument("--description")
    create_parser.add_argument("--visibility", choices=["private", "internal", "public"], default="private")
    create_parser.add_argument("--default-branch")
    create_parser.add_argument("--initialize-with-readme", type=parse_bool, nargs="?", const=True)
    create_parser.add_argument("--topics")
    create_parser.add_argument("--merge-method", choices=["merge", "rebase_merge", "ff"])
    create_parser.add_argument("--issues-access-level", choices=["disabled", "private", "enabled"])
    create_parser.add_argument("--merge-requests-access-level", choices=["disabled", "private", "enabled"])
    create_parser.add_argument("--builds-access-level", choices=["disabled", "private", "enabled"])
    create_parser.set_defaults(func=cmd_create)

    update_parser = subparsers.add_parser("update", help="Update a project")
    update_parser.add_argument("project")
    update_parser.add_argument("--description")
    update_parser.add_argument("--visibility", choices=["private", "internal", "public"])
    update_parser.add_argument("--default-branch")
    update_parser.add_argument("--topics")
    update_parser.add_argument("--issues-access-level", choices=["disabled", "private", "enabled"])
    update_parser.add_argument("--merge-requests-access-level", choices=["disabled", "private", "enabled"])
    update_parser.add_argument("--builds-access-level", choices=["disabled", "private", "enabled"])
    update_parser.add_argument("--remove-source-branch-after-merge", type=parse_bool, nargs="?", const=True)
    update_parser.set_defaults(func=cmd_update)

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
