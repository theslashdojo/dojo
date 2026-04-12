---
name: projects
description: Create, list, inspect, and update GitLab projects via the REST API. Use when bootstrapping a repository, resolving a project path or ID, or aligning GitLab project settings with policy.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# GitLab Projects

Use this skill when a workflow starts at the project boundary: discovering the right project, creating a new repository space, or changing project settings before downstream issue, merge request, or pipeline automation.

## Prerequisites

- One of `GITLAB_TOKEN`, `OAUTH_TOKEN`, or `CI_JOB_TOKEN`
- Optional `GITLAB_HOST` for self-managed instances
- Python 3.10+

## Workflow

### 1. Resolve the host and token

```bash
export GITLAB_HOST=https://gitlab.example.com
export GITLAB_TOKEN=glpat-xxxx
```

### 2. Discover the project

```bash
python ./scripts/manage-projects.py list --search platform --membership
python ./scripts/manage-projects.py get group/project
```

### 3. Create a project

```bash
python ./scripts/manage-projects.py create my-service \
  --namespace-id 12345 \
  --description 'Service owned by platform' \
  --visibility private \
  --initialize-with-readme
```

### 4. Update settings

```bash
python ./scripts/manage-projects.py update group/project \
  --topics platform,service \
  --visibility private \
  --issues-access-level enabled \
  --merge-requests-access-level enabled \
  --builds-access-level enabled
```

## Common Patterns

- Use `group/project` when that is what you know; the script URL-encodes it automatically.
- Use numeric IDs once you have them if you are chaining many follow-up API calls.
- Set `--initialize-with-readme` when you also need `--default-branch` at creation time.
- Use project discovery before issue, merge request, pipeline, or variable automation.

## Edge Cases

- `default_branch` at project creation requires `initialize_with_readme=true`.
- `initialize_with_readme` and `import_url` are mutually exclusive in the API.
- Self-managed hosts must include the scheme, for example `https://gitlab.example.com`.
- Listing projects can return partial data for low-privilege or unauthenticated access.
