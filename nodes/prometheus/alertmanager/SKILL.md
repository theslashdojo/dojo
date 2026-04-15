---
name: alertmanager
description: >
  Inspect Alertmanager status, validate routing config, and manage silences and
  grouped alerts. Use when routing notifications, muting noisy alerts, or
  checking delivery state during incidents.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Alertmanager

Use this skill after [[prometheus/rules]] produces alerts and you need to understand or change how they are handled.

## Prerequisites

- `ALERTMANAGER_URL` set to the Alertmanager base URL, for example `http://localhost:9093`
- Optional auth via bearer token or basic auth env vars
- `amtool` installed for `validate-config` and `routes`, or set `AMTOOL_BIN`

## Workflow

1. Check cluster and config status first:

```bash
python scripts/manage-alertmanager.py status
```

2. Inspect current silences or active grouped alerts:

```bash
python scripts/manage-alertmanager.py list-silences
python scripts/manage-alertmanager.py groups --receiver 'team-.*'
```

3. Silence a known maintenance window with explicit scope and comment:

```bash
python scripts/manage-alertmanager.py create-silence \
  --matcher 'alertname=InstanceDown' \
  --matcher 'instance=~web-.*' \
  --duration 2h \
  --comment 'planned reboot window'
```

4. Validate or visualize routing before rollout:

```bash
python scripts/manage-alertmanager.py validate-config alertmanager.yml
python scripts/manage-alertmanager.py routes --config-file alertmanager.yml
```

## Edge Cases

- Prometheus should normally send alerts; do not build a primary alert pipeline by posting directly to `/api/v2/alerts`.
- Silence matchers are exact or regex and can include negative forms like `!=` and `!~`.
- Route trees are easier to reason about with `amtool config routes` than by scanning YAML manually.
- Expiring the wrong silence is immediate, so always scope matchers narrowly.
