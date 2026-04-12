#!/usr/bin/env python3
"""List, inspect, create, and merge GitLab merge requests."""

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


def parse_int_csv(value: str | None) -> list[int] | None:
    if value is None:
        return None
    items = [item.strip() for item in value.split(",") if item.strip()]
    return [int(item) for item in items]


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


def mr_path(project: str, merge_request_iid: int | None = None) -> str:
    base = f"/projects/{project_ref(project)}/merge_requests"
    return base if merge_request_iid is None else f"{base}/{merge_request_iid}"


def summarize_mr(mr: dict[str, Any]) -> dict[str, Any]:
    return {
        "iid": mr.get("iid"),
        "title": mr.get("title"),
        "state": mr.get("state"),
        "draft": mr.get("draft"),
        "sourceBranch": mr.get("source_branch"),
        "targetBranch": mr.get("target_branch"),
        "webUrl": mr.get("web_url"),
        "detailedMergeStatus": mr.get("detailed_merge_status"),
        "mergeStatus": mr.get("merge_status"),
    }


def cmd_list(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json(
        "GET",
        mr_path(args.project),
        query={
            "state": args.state,
            "source_branch": args.source_branch,
            "target_branch": args.target_branch,
            "search": args.search,
            "reviewer_id": args.reviewer_id,
            "assignee_id": args.assignee_id,
            "page": args.page,
            "per_page": args.per_page,
        },
    )
    return [summarize_mr(mr) for mr in response]


def cmd_get(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json("GET", mr_path(args.project, args.merge_request_iid))
    return summarize_mr(response)


def cmd_create(args: argparse.Namespace) -> dict[str, Any]:
    title = args.title
    if args.draft and not title.lower().startswith(("draft:", "wip:")):
        title = f"Draft: {title}"

    form = {
        "source_branch": args.source_branch,
        "target_branch": args.target_branch,
        "title": title,
        "description": args.description,
        "labels": args.labels,
        "target_project_id": args.target_project_id,
        "remove_source_branch": args.remove_source_branch,
        "squash": args.squash,
    }
    assignee_ids = parse_int_csv(args.assignee_ids)
    reviewer_ids = parse_int_csv(args.reviewer_ids)
    if assignee_ids:
        form["assignee_ids[]"] = assignee_ids
    if reviewer_ids:
        form["reviewer_ids[]"] = reviewer_ids

    response = request_json("POST", mr_path(args.project), form=form)
    return summarize_mr(response)


def cmd_merge(args: argparse.Namespace) -> dict[str, Any]:
    form = {
        "sha": args.sha,
        "squash": args.squash,
        "should_remove_source_branch": args.remove_source_branch,
        "auto_merge": args.auto_merge,
        "merge_commit_message": args.merge_commit_message,
    }
    response = request_json("PUT", f"{mr_path(args.project, args.merge_request_iid)}/merge", form=form)
    return summarize_mr(response)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List project merge requests")
    list_parser.add_argument("project")
    list_parser.add_argument("--state", choices=["opened", "closed", "locked", "merged", "all"], default="opened")
    list_parser.add_argument("--source-branch")
    list_parser.add_argument("--target-branch")
    list_parser.add_argument("--search")
    list_parser.add_argument("--reviewer-id", type=int)
    list_parser.add_argument("--assignee-id", type=int)
    list_parser.add_argument("--page", type=int, default=1)
    list_parser.add_argument("--per-page", type=int, default=20)
    list_parser.set_defaults(func=cmd_list)

    get_parser = subparsers.add_parser("get", help="Get one merge request by IID")
    get_parser.add_argument("project")
    get_parser.add_argument("merge_request_iid", type=int)
    get_parser.set_defaults(func=cmd_get)

    create_parser = subparsers.add_parser("create", help="Create a merge request")
    create_parser.add_argument("project")
    create_parser.add_argument("source_branch")
    create_parser.add_argument("target_branch")
    create_parser.add_argument("title")
    create_parser.add_argument("--description")
    create_parser.add_argument("--labels")
    create_parser.add_argument("--assignee-ids")
    create_parser.add_argument("--reviewer-ids")
    create_parser.add_argument("--target-project-id", type=int)
    create_parser.add_argument("--remove-source-branch", type=parse_bool, nargs="?", const=True)
    create_parser.add_argument("--squash", type=parse_bool, nargs="?", const=True)
    create_parser.add_argument("--draft", action="store_true")
    create_parser.set_defaults(func=cmd_create)

    merge_parser = subparsers.add_parser("merge", help="Merge a merge request")
    merge_parser.add_argument("project")
    merge_parser.add_argument("merge_request_iid", type=int)
    merge_parser.add_argument("--sha")
    merge_parser.add_argument("--squash", type=parse_bool, nargs="?", const=True)
    merge_parser.add_argument("--remove-source-branch", type=parse_bool, nargs="?", const=True)
    merge_parser.add_argument("--auto-merge", type=parse_bool, nargs="?", const=True)
    merge_parser.add_argument("--merge-commit-message")
    merge_parser.set_defaults(func=cmd_merge)

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
