---
name: variables
description: List, inspect, set, and delete GitLab project-level CI/CD variables. Use when managing secrets or environment-scoped configuration for pipelines without changing repository YAML.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# GitLab Variables

Use this skill for project-scoped CI/CD configuration and secret management.

## Prerequisites

- A project path or ID
- One of `GITLAB_TOKEN`, `OAUTH_TOKEN`, or `CI_JOB_TOKEN`
- Python 3.10+

## Workflow

### 1. Inspect current variables

```bash
python ./scripts/manage-variables.py list group/project
python ./scripts/manage-variables.py get group/project AWS_ROLE_ARN --environment-scope production
```

### 2. Set or update a variable

```bash
python ./scripts/manage-variables.py set group/project AWS_ROLE_ARN arn:aws:iam::123456789012:role/deploy \
  --environment-scope production \
  --protected
```

### 3. Store a file variable

```bash
python ./scripts/manage-variables.py set group/project GOOGLE_CREDENTIALS "$(< service-account.json)" \
  --variable-type file
```

### 4. Delete a scoped variable

```bash
python ./scripts/manage-variables.py delete group/project AWS_ROLE_ARN --environment-scope production
```

## Common Patterns

- Treat wildcard (`*`) and environment-specific scopes as separate variables.
- Use project variables for secrets and keep YAML variables non-sensitive.
- Use `--raw false` when a variable value should expand nested variables at runtime.

## Edge Cases

- The same key can exist multiple times with different scopes; always specify scope when precision matters.
- `masked`, `hidden`, and `masked-and-hidden` are different controls with different UI and log behavior.
- `file` variables are delivered to jobs as files rather than plain environment strings.
