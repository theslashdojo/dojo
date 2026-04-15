# Collector Pipeline Patterns

## Local Debug

Use when verifying SDK instrumentation.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
processors:
  batch:
exporters:
  debug:
    verbosity: detailed
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
```

## Gateway Fan-Out

Use when applications send to one regional Collector and the Collector exports to multiple backends.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1024
  batch:
exporters:
  otlp/primary:
    endpoint: backend-a:4317
    tls:
      insecure: true
  otlphttp/secondary:
    endpoint: https://backend-b.example.com
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/primary, otlphttp/secondary]
```

## Tail Sampling

Use when you need to retain errors and slow traces while reducing normal traffic.

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 2048
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000
    policies:
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: slow
        type: latency
        latency:
          threshold_ms: 1000
      - name: baseline
        type: probabilistic
        probabilistic:
          sampling_percentage: 10
  batch:
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters: [otlp]
```
