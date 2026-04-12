---
name: pipelines
description: List, inspect, trigger, retry, cancel, and inspect variables for GitLab pipelines. Use when orchestrating CI/CD execution or debugging why a GitLab pipeline did or did not run.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# GitLab Pipelines

Use this skill when the agent must control or inspect pipeline execution.

## Prerequisites

- A project path or ID
- One of `GITLAB_TOKEN`, `OAUTH_TOKEN`, or `CI_JOB_TOKEN`
- Python 3.10+
- Understanding of `.gitlab-ci.yml`, runners, and rules

## Workflow

### 1. List recent pipelines

```bash
python ./scripts/manage-pipelines.py list group/project --ref main --status failed
```

### 2. Trigger a pipeline

```bash
python ./scripts/manage-pipelines.py create group/project main \
  --var DEPLOY_ENV=staging \
  --input level=3 \
  --input scan_security=false
```

### 3. Inspect a run

```bash
python ./scripts/manage-pipelines.py get group/project 311
python ./scripts/manage-pipelines.py variables group/project 311
```

### 4. Recover or stop execution

```bash
python ./scripts/manage-pipelines.py retry group/project 311
python ./scripts/manage-pipelines.py cancel group/project 311
```

## Common Patterns

- Use `--var` for ad hoc pipeline variables and `--input` for typed pipeline inputs.
- Use `CI_JOB_TOKEN` inside GitLab CI when one pipeline triggers or inspects another allowed project.
- Compare stored project variables with `variables` output when debugging deploy inputs.

## Edge Cases

- Merge-request pipelines use a separate API surface from generic branch or tag pipelines.
- `cancel` returns success even when the pipeline is already complete; inspect the returned status.
- Child pipelines are not listed unless the source filter requests them.
