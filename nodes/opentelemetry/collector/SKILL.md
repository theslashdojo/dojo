---
name: collector
description: Configure, validate, run, and troubleshoot OpenTelemetry Collector pipelines; use when telemetry needs a local agent, gateway, debug exporter, batching, sampling, or fan-out.
---

# OpenTelemetry Collector

Use this skill to create and validate Collector configs for local development, agents, or gateway deployments.

## When to Use

- SDKs need one OTLP endpoint instead of direct vendor export
- Telemetry needs batching, retries, memory protection, redaction, or enrichment
- Traces need tail sampling or fan-out to multiple backends
- You need to prove whether data reaches the Collector before debugging a backend
- You are deploying OpenTelemetry in Docker Compose, Kubernetes, systemd, or CI tests

## Workflow

1. Generate a baseline config:

```bash
python3 nodes/opentelemetry/collector/scripts/collector-config.py render \
  --out otelcol.yaml \
  --debug
```

2. Validate with the Collector binary:

```bash
otelcol validate --config=otelcol.yaml
```

3. Run locally:

```bash
otelcol --config=otelcol.yaml
```

4. Point SDKs at the Collector:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

5. Watch Collector logs and internal metrics:

```bash
curl -fsS http://localhost:13133/
curl -fsS http://localhost:8888/metrics | grep '^otelcol_' | head
```

## Baseline Pipeline

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  batch:
exporters:
  debug:
    verbosity: detailed
service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
```

## Rules

- Defining a component does not activate it; it must be referenced under `service`.
- Put `memory_limiter` early and `batch` late in processor lists.
- Use `debug` exporter during verification, then reduce verbosity or remove it.
- For tail sampling, make sure all spans for a trace reach the same Collector instance.
- Component availability depends on the Collector distribution (`otelcol` vs `otelcol-contrib`).

## Edge Cases

- OTLP/HTTP 404 usually means endpoint path rules are wrong.
- Empty backend but debug exporter sees data means backend exporter auth, TLS, endpoint, or quota is the issue.
- Collector starts but drops data: inspect `otelcol_exporter_send_failed_*` and processor drop metrics.
- In Kubernetes, check Service ports expose both `4317` and `4318` if both protocols are enabled.
- Tail sampling requires enough memory for pending traces; tune `decision_wait` and `num_traces`.

## References

- `references/pipeline-patterns.md` has reusable local, gateway, and tail-sampling config patterns.
