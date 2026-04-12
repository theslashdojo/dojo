---
name: merge-requests
description: List, inspect, create, and merge GitLab merge requests. Use when changes have been pushed to a branch and the agent needs to start or complete the review and merge workflow.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# GitLab Merge Requests

Use this skill after branch work is pushed and ready for review or merge.

## Prerequisites

- A project path or ID
- A source branch already pushed to GitLab
- One of `GITLAB_TOKEN`, `OAUTH_TOKEN`, or `CI_JOB_TOKEN`
- Python 3.10+

## Workflow

### 1. Inspect existing merge requests

```bash
python ./scripts/manage-merge-requests.py list group/project --state opened --source-branch feature/refactor
```

### 2. Create a merge request

```bash
python ./scripts/manage-merge-requests.py create group/project feature/refactor main 'Refactor deploy flow' \
  --description 'Splits deployment into reusable steps' \
  --remove-source-branch \
  --squash
```

### 3. Inspect merge status

```bash
python ./scripts/manage-merge-requests.py get group/project 17
```

### 4. Merge safely

```bash
python ./scripts/manage-merge-requests.py merge group/project 17 --sha 4f8a1b2c3d
```

## Common Patterns

- Use the `--sha` guard when merging so only the reviewed commit set can land.
- Prefix the title with `Draft:` if the merge request should be created in draft state.
- If the branch is behind target, fix the branch with normal Git operations before merging.

## Edge Cases

- Merge-request pipelines are distinct from ordinary branch pipelines.
- `detailed_merge_status` is more useful than the legacy `merge_status` field.
- Cross-project merge requests may need `--target-project-id`.
