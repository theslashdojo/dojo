# OpenTelemetry Node.js Environment Variables

Use these values at deployment time so the same build artifact can run in multiple environments.

| Variable | Use |
| --- | --- |
| `OTEL_SERVICE_NAME` | Sets `service.name`; prefer this for service identity. |
| `OTEL_RESOURCE_ATTRIBUTES` | Comma-separated resource attributes such as `service.version=1.7.3,deployment.environment.name=production`. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Base OTLP endpoint. For HTTP, SDKs append `/v1/traces`, `/v1/metrics`, and `/v1/logs`. |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | Final traces endpoint, used as-is. |
| `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | Final metrics endpoint, used as-is. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Transport such as `http/protobuf` or `grpc`. |
| `OTEL_EXPORTER_OTLP_HEADERS` | Comma-separated headers for auth or tenancy. URL-encode values where required. |
| `OTEL_TRACES_SAMPLER` | Sampler name, commonly `parentbased_traceidratio`. |
| `OTEL_TRACES_SAMPLER_ARG` | Sampler argument, commonly a ratio like `0.10`. |
| `OTEL_PROPAGATORS` | Propagators, commonly `tracecontext,baggage`. |
| `OTEL_SDK_DISABLED` | Set `true` to disable SDK telemetry in emergencies. |

Safe baseline:

```bash
export OTEL_SERVICE_NAME=my-service
export OTEL_RESOURCE_ATTRIBUTES=service.version=$(git rev-parse --short HEAD),deployment.environment.name=staging
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_PROPAGATORS=tracecontext,baggage
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.10
```
