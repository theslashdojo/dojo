---
name: nodejs
description: Instrument Node.js services with OpenTelemetry auto-instrumentation, manual spans, metrics, and OTLP export; use when a Node process needs production traces or metrics.
---

# OpenTelemetry Node.js

Use this skill to add OpenTelemetry to Node.js services, workers, CLIs, or queue consumers.

## When to Use

- Add distributed tracing to an Express, Fastify, NestJS, or plain HTTP service
- Export Node.js telemetry to an OpenTelemetry Collector or OTLP backend
- Add manual spans around business operations
- Add low-cardinality metrics from application code
- Fix missing Node.js spans caused by SDK startup order

## Workflow

1. Install SDK packages:

```bash
npm install @opentelemetry/api @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/exporter-metrics-otlp-http @opentelemetry/sdk-metrics @opentelemetry/resources @opentelemetry/semantic-conventions
```

2. Generate a bootstrap file:

```bash
node nodes/opentelemetry/nodejs/scripts/create-node-bootstrap.mjs \
  --service-name checkout-api \
  --service-version 1.7.3 \
  --out instrumentation.mjs
```

3. Start the app with the bootstrap loaded first:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
node --import ./instrumentation.mjs ./server.js
```

4. Verify the Collector receives data. Add a `debug` exporter while testing.

5. Add manual spans only where auto-instrumentation cannot infer business meaning.

## Manual Span Pattern

```javascript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('checkout-service', '1.7.3');

export async function reserveInventory(order) {
  return tracer.startActiveSpan('checkout.reserve_inventory', async (span) => {
    try {
      span.setAttribute('checkout.item_count', order.items.length);
      const result = await inventory.reserve(order.items);
      span.setAttribute('inventory.reserved', result.ok);
      return result;
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      throw error;
    } finally {
      span.end();
    }
  });
}
```

## Environment Variables

```bash
export OTEL_SERVICE_NAME=checkout-api
export OTEL_RESOURCE_ATTRIBUTES=service.version=1.7.3,deployment.environment.name=production
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.10
```

## Edge Cases

- If no spans appear, the SDK likely started after instrumented modules were imported.
- If the service is named `unknown_service`, set `OTEL_SERVICE_NAME`.
- If OTLP/HTTP returns 404, check whether you used a base endpoint or a signal-specific endpoint.
- If gRPC fails behind a proxy, use `http/protobuf` on port `4318`.
- Do not use user IDs, request IDs, UUIDs, emails, or full URLs as metric attributes.
- Avoid secrets and PII in span attributes, logs, events, and baggage.

## References

- `references/env-vars.md` summarizes the environment variables most agents need.
