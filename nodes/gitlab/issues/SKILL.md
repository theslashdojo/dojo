---
name: issues
description: Create, list, inspect, update, close, and reopen GitLab issues inside a project. Use when triaging bugs, filing incidents, or automating project work tracking in GitLab.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# GitLab Issues

Use this skill for issue tracker automation inside a GitLab project.

## Prerequisites

- A project path or numeric project ID
- One of `GITLAB_TOKEN`, `OAUTH_TOKEN`, or `CI_JOB_TOKEN`
- Python 3.10+

## Workflow

### 1. Search before creating

```bash
python ./scripts/manage-issues.py list group/project --state opened --labels bug --search deploy
```

### 2. Create an issue

```bash
python ./scripts/manage-issues.py create group/project 'Bug: deploy failed on main' \
  --labels bug,platform \
  --description 'Build passed, deploy job failed with a 403'
```

### 3. Inspect or update by IID

```bash
python ./scripts/manage-issues.py get group/project 42
python ./scripts/manage-issues.py update group/project 42 \
  --add-labels triaged \
  --description 'Confirmed on the latest pipeline'
```

### 4. Close or reopen

```bash
python ./scripts/manage-issues.py close group/project 42
python ./scripts/manage-issues.py reopen group/project 42
```

## Common Patterns

- Store issue references as `{ project, iid }`; most follow-up endpoints use the IID.
- Use `--labels` to replace the full label set and `--add-labels` for incremental tagging.
- Use `issue_type incident` when an operational event should be modeled separately from normal bugs.

## Edge Cases

- GitLab issue creation can be rate-limited; retry with backoff for high-volume intake.
- If issues are disabled for a project, create calls return `403 Forbidden`.
- `iid` is not the same as the global issue `id`; use the IID for project issue updates.
