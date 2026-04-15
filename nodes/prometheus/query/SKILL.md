---
name: query
description: >
  Query Prometheus through the HTTP API for instant values, range data, targets,
  rules, alerts, and TSDB status. Use when debugging incidents, checking scrape
  health, or extracting metrics for automation.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Prometheus Query

Use this skill when you need live data from a Prometheus server instead of static documentation.

## Prerequisites

- `PROMETHEUS_URL` set to the Prometheus base URL, for example `http://localhost:9090`
- Optional auth via `PROMETHEUS_BEARER_TOKEN` or `PROMETHEUS_BASIC_AUTH_USERNAME` and `PROMETHEUS_BASIC_AUTH_PASSWORD`
- Python 3.11+

## Workflow

1. Pick the endpoint:
   - `instant` for a single evaluation time
   - `range` for chart-style data across a window
   - `series` for label sets matching one or more selectors
   - `targets`, `rules`, `alerts`, `status-config`, or `status-tsdb` for server state
2. Write or reuse a valid PromQL expression for `instant` or `range`.
3. Run the script and inspect the JSON response.
4. If the query is expensive or reused often, move it into [[prometheus/rules]] as a recording rule.

## Examples

```bash
python scripts/query-api.py instant --query 'up{job="node"}'
python scripts/query-api.py range --query 'rate(http_requests_total[5m])' --start 2026-04-12T00:00:00Z --end 2026-04-12T02:00:00Z --step 30s
python scripts/query-api.py series --match 'up' --match 'process_start_time_seconds'
python scripts/query-api.py targets
python scripts/query-api.py status-tsdb
```

## Interpretation

- `resultType=vector` means an instant set of time series.
- `resultType=matrix` means a range query with samples across time.
- Empty `data.result` is still a valid success response.
- `targets` exposes scrape health before you start debugging PromQL.

## Edge Cases

- Range queries require `--start`, `--end`, and `--step`.
- `series` uses repeated `match[]` selectors, not a single PromQL expression.
- Some deployments protect the API behind [[prometheus/auth]] or a reverse proxy.
- Large cardinality queries can be slow; add `--limit` where the endpoint supports it.
