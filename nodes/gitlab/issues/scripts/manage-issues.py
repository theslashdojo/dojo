#!/usr/bin/env python3
"""List, create, inspect, update, close, and reopen GitLab issues."""

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


def summarize_issue(issue: dict[str, Any]) -> dict[str, Any]:
    return {
        "iid": issue.get("iid"),
        "title": issue.get("title"),
        "state": issue.get("state"),
        "issueType": issue.get("issue_type"),
        "confidential": issue.get("confidential"),
        "labels": issue.get("labels", []),
        "assignees": [assignee.get("username") for assignee in issue.get("assignees", [])],
        "webUrl": issue.get("web_url"),
    }


def issue_path(project: str, issue_iid: int) -> str:
    return f"/projects/{project_ref(project)}/issues/{issue_iid}"


def cmd_list(args: argparse.Namespace) -> list[dict[str, Any]]:
    response = request_json(
        "GET",
        f"/projects/{project_ref(args.project)}/issues",
        query={
            "state": args.state,
            "labels": args.labels,
            "search": args.search,
            "assignee_id": args.assignee_id,
            "author_id": args.author_id,
            "page": args.page,
            "per_page": args.per_page,
        },
    )
    return [summarize_issue(issue) for issue in response]


def cmd_get(args: argparse.Namespace) -> dict[str, Any]:
    response = request_json("GET", issue_path(args.project, args.issue_iid))
    return summarize_issue(response)


def cmd_create(args: argparse.Namespace) -> dict[str, Any]:
    form = {
        "title": args.title,
        "description": args.description,
        "labels": args.labels,
        "confidential": args.confidential,
        "due_date": args.due_date,
        "issue_type": args.issue_type,
        "milestone_id": args.milestone_id,
    }
    if args.assignee_id is not None:
        form["assignee_id"] = args.assignee_id
    assignee_ids = parse_int_csv(args.assignee_ids)
    if assignee_ids:
        form["assignee_ids[]"] = assignee_ids

    response = request_json(
        "POST",
        f"/projects/{project_ref(args.project)}/issues",
        form=form,
    )
    return summarize_issue(response)


def cmd_update(args: argparse.Namespace) -> dict[str, Any]:
    form = {
        "title": args.title,
        "description": args.description,
        "labels": args.labels,
        "add_labels": args.add_labels,
        "remove_labels": args.remove_labels,
        "confidential": args.confidential,
        "due_date": args.due_date,
        "issue_type": args.issue_type,
        "milestone_id": args.milestone_id,
    }
    assignee_ids = parse_int_csv(args.assignee_ids)
    if assignee_ids is not None:
        form["assignee_ids[]"] = assignee_ids

    if all(value is None for value in form.values()):
        raise SystemExit("Provide at least one field to update.")

    response = request_json("PUT", issue_path(args.project, args.issue_iid), form=form)
    return summarize_issue(response)


def cmd_close_or_reopen(args: argparse.Namespace, state_event: str) -> dict[str, Any]:
    response = request_json(
        "PUT",
        issue_path(args.project, args.issue_iid),
        form={"state_event": state_event},
    )
    return summarize_issue(response)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List project issues")
    list_parser.add_argument("project")
    list_parser.add_argument("--state", choices=["opened", "closed", "all"], default="opened")
    list_parser.add_argument("--labels")
    list_parser.add_argument("--search")
    list_parser.add_argument("--assignee-id", type=int)
    list_parser.add_argument("--author-id", type=int)
    list_parser.add_argument("--page", type=int, default=1)
    list_parser.add_argument("--per-page", type=int, default=20)
    list_parser.set_defaults(func=cmd_list)

    get_parser = subparsers.add_parser("get", help="Get one issue by IID")
    get_parser.add_argument("project")
    get_parser.add_argument("issue_iid", type=int)
    get_parser.set_defaults(func=cmd_get)

    create_parser = subparsers.add_parser("create", help="Create an issue")
    create_parser.add_argument("project")
    create_parser.add_argument("title")
    create_parser.add_argument("--description")
    create_parser.add_argument("--labels")
    create_parser.add_argument("--confidential", type=parse_bool, nargs="?", const=True)
    create_parser.add_argument("--due-date")
    create_parser.add_argument("--issue-type", choices=["issue", "incident", "task", "test_case"])
    create_parser.add_argument("--assignee-id", type=int)
    create_parser.add_argument("--assignee-ids")
    create_parser.add_argument("--milestone-id", type=int)
    create_parser.set_defaults(func=cmd_create)

    update_parser = subparsers.add_parser("update", help="Update an issue")
    update_parser.add_argument("project")
    update_parser.add_argument("issue_iid", type=int)
    update_parser.add_argument("--title")
    update_parser.add_argument("--description")
    update_parser.add_argument("--labels")
    update_parser.add_argument("--add-labels")
    update_parser.add_argument("--remove-labels")
    update_parser.add_argument("--confidential", type=parse_bool, nargs="?", const=True)
    update_parser.add_argument("--due-date")
    update_parser.add_argument("--issue-type", choices=["issue", "incident", "task", "test_case"])
    update_parser.add_argument("--assignee-ids")
    update_parser.add_argument("--milestone-id", type=int)
    update_parser.set_defaults(func=cmd_update)

    close_parser = subparsers.add_parser("close", help="Close an issue")
    close_parser.add_argument("project")
    close_parser.add_argument("issue_iid", type=int)
    close_parser.set_defaults(func=lambda args: cmd_close_or_reopen(args, "close"))

    reopen_parser = subparsers.add_parser("reopen", help="Reopen an issue")
    reopen_parser.add_argument("project")
    reopen_parser.add_argument("issue_iid", type=int)
    reopen_parser.set_defaults(func=lambda args: cmd_close_or_reopen(args, "reopen"))

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
