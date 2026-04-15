---
name: rules
description: >
  Author, lint, test, and inspect Prometheus recording and alerting rules. Use
  when you need reusable metrics, production alerts, or regression-tested PromQL.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Prometheus Rules

Use this skill when PromQL expressions should become durable operational policy instead of ad hoc queries.

## Prerequisites

- `promtool` installed, or set `PROMTOOL_BIN`
- Optional `PROMETHEUS_URL` for `list` and `alerts`
- Working knowledge of [[prometheus/promql]]

## Workflow

1. Put related rules in a group with a clear `name` and evaluation cadence.
2. Validate syntax and expression references:

```bash
bash scripts/manage-rules.sh check rules/*.yml
```

3. Add promtool unit tests for edge cases and regressions:

```bash
bash scripts/manage-rules.sh test tests/*.test.yml
```

4. Load the rule files through [[prometheus/config]] and then inspect the live server:

```bash
bash scripts/manage-rules.sh list
bash scripts/manage-rules.sh alerts
```

## What To Store As Rules

- Recording rules for expensive, repeated queries
- Alerting rules for symptoms with stable labels and annotations
- Not raw exploratory queries that change every incident

## Edge Cases

- `for:` delays firing until the condition stays true for the full duration.
- Unit tests need input series plus expected samples or alerts.
- Alert labels affect Alertmanager deduplication and routing.
- Recording rules can amplify cardinality if labels are not aggregated deliberately.
