# Tail Workers patterns

Use Tail Workers for custom processing. For standard export to observability tools, first check the platform's [OpenTelemetry destinations](https://developers.cloudflare.com/workers/observability/exporting-opentelemetry-data/): the built-in export may already meet the requirement. Confirm any external SDK against the project's installed package; a vendor name alone is not an API contract.

## Filtering and HTTP export

Start with the safe projection and HTTP status handling in [api.md](api.md). Filter execution failures by `event.outcome` and `event.exceptions.length`; narrow `event.event` before checking response status. For route filtering, parse a validated URL's pathname rather than searching a complete URL string that may match the query or hostname.

Sampling `events.filter(() => Math.random() < 0.1)` selects individual records. Sampling once outside the loop selects an entire batch and can bias results when batch sizes differ. Record the sampling rate when producing aggregate estimates.

## KV with retention

Inside a handler with a `LOGS_KV` binding and an already redacted projection:

```typescript
await Promise.all(payloads.map(payload => env.LOGS_KV.put(
  `log:${crypto.randomUUID()}`,
  JSON.stringify(payload),
  { expirationTtl: 86400 },
)));
```

Script name plus millisecond timestamp is not a unique event key. Use a collision-resistant identifier; keep batch size bounded by the destination's limits. KV TTL is retention, not replay processing.

## Analytics Engine

`writeDataPoint()` is synchronous and returns `void`; do not build a `Promise.all` or `waitUntil` around it.

```typescript
interface MetricsEnv { ANALYTICS: AnalyticsEngineDataset }
export default {
  tail(events, env) {
    for (const event of events) {
      const info = event.event;
      const status = info && "response" in info ? info.response?.status : undefined;
      env.ANALYTICS.writeDataPoint({
        indexes: [event.scriptName ?? "unknown"],
        blobs: [event.outcome],
        doubles: [1, status ?? 0],
      });
    }
  },
} satisfies ExportedHandler<MetricsEnv>;
```

## Multiple destinations and batching

Use bounded `Promise.all` when every destination must succeed, or `Promise.allSettled` when outcomes must be recorded independently. Neither makes delivery to multiple systems atomic. Preserve destination-specific failure evidence and avoid replaying a successful destination accidentally.

A Durable Object can persist a batch and flush it with an alarm; use durable storage and an idempotent receiver. A single global object can become a throughput bottleneck, so choose a partition key based on actual volume and ordering requirements. See [Durable Objects patterns](../durable-objects/patterns.md).

For dynamic dispatch, inspect `scriptName`/`dispatchNamespace` instead of assuming a fixed number of traces. Service-binding subrequests may add events.
