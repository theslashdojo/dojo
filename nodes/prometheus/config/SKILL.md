---
name: config
description: >
  Validate, inspect, and hot-reload Prometheus configuration with promtool and
  the management endpoints. Use when changing scrape jobs, rule files, or
  service discovery settings.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Prometheus Config

Use this skill to make configuration changes safely before they hit a running Prometheus server.

## Prerequisites

- `promtool` installed and available on `PATH`, or set `PROMTOOL_BIN`
- Optional `PROMETHEUS_URL` for `reload` and `show-loaded`
- Optional auth via `PROMETHEUS_BEARER_TOKEN` or basic auth env vars

## Workflow

1. Edit `prometheus.yml` with the scrape job, `rule_files`, or `alerting` changes you need.
2. Validate it locally:

```bash
bash scripts/manage-config.sh validate prometheus.yml
```

3. If the job uses service discovery or relabeling, inspect the discovered targets:

```bash
bash scripts/manage-config.sh check-sd prometheus.yml kubernetes-pods
```

4. Reload the running server only after validation passes:

```bash
bash scripts/manage-config.sh reload
```

5. Confirm what the server actually loaded:

```bash
bash scripts/manage-config.sh show-loaded
```

## Useful Environment Variables

- `PROM_CONFIG_SYNTAX_ONLY=true` to skip referenced-file validation
- `PROM_CONFIG_LINT=all` to enable all config lint checks
- `PROM_CONFIG_LINT_FATAL=true` to fail on lint warnings
- `PROM_SD_TIMEOUT=60s` for slow discovery backends

## Edge Cases

- `/-/reload` only works when Prometheus was started with `--web.enable-lifecycle`.
- `check-sd` needs both the config file and a job name.
- A syntactically valid config can still scrape nothing if relabeling removes all targets.
- Auth and TLS for the UI and reload endpoint are often handled via [[prometheus/auth]].
