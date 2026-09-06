# Pipelines Patterns

Code-first patterns. For observability dataset/field schemas and Logpush dataset lists, pull `https://developers.cloudflare.com/pipelines/observability/metrics/` and `https://developers.cloudflare.com/pipelines/streams/logpush/`.

## Optional telemetry producer

This does not guarantee delivery before the response. For required ingestion await send(), then separately reconcile events at the sink.

```typescript
export default {
  async fetch(req, env, ctx) {
    const event = { event_id: crypto.randomUUID(), event_type: "page_view", timestamp: new Date().toISOString() };
    ctx.waitUntil(env.MY_STREAM.send([event]).catch(error => console.error("Telemetry send failed", error)));  // don't block the response
    return new Response("OK");
  }
};
```

## Client-Side Validation with Zod

Structured streams drop invalid events silently during processing. Validate before sending for immediate feedback.

```typescript
import { z } from "zod";

const EventSchema = z.object({
  event_id: z.string(),
  category: z.enum(["purchase", "view"]),
  amount: z.number().positive().optional(),
});

const validated = EventSchema.parse(rawEvent);  // throws synchronously
await env.MY_STREAM.send([validated]);
```

## Scheduled Collector Worker

```jsonc
// wrangler.jsonc
{
  "name": "collector",
  "pipelines": [{ "stream": "<STREAM_ID>", "binding": "EVENT_STREAM" }],
  "triggers": { "crons": ["*/5 * * * *"] }
}
```

```typescript
import { z } from "zod";
import type { Pipeline } from "cloudflare:pipelines";

const Items = z.array(z.object({ type: z.string(), value: z.number() }));
interface Env { EVENT_STREAM: Pipeline }

export default {
  async scheduled(event, env, ctx) {
    const response = await fetch("https://api.example.com/data");
    if (!response.ok) throw new Error(`Collector HTTP ${response.status}`);
    const items = Items.parse(await response.json());
    const events = items.map(i => ({
      event_id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      category: i.type, amount: i.value,
    }));
    await env.EVENT_STREAM.send(events);
  },
} satisfies ExportedHandler<Env>;
```

## Logpush → Pipelines

Pipelines is a native Logpush destination — ingest Cloudflare logs, transform with SQL, store as Iceberg/Parquet. For the current supported dataset list and field names, pull the Logpush doc above.

```sql
INSERT INTO http_logs_sink
SELECT
  EdgeResponseStatus,
  to_timestamp_micros(EdgeStartTimestamp) AS event_time,
  upper(ClientRequestMethod) AS method,
  sha256(ClientIP) AS hashed_ip          -- pseudonymize; unsalted IP hashes can be enumerated
FROM http_logs_stream
WHERE EdgeResponseStatus >= 400;
```

Configure via Dashboard (**Logpush → Create a job → Pipelines** destination) or API.

## Pipelines + Queues Fan-out

These are independent writes, not an atomic transaction. Use stable event IDs, consumer deduplication, and reconciliation when one succeeds and the other fails.

```typescript
await Promise.all([
  env.ANALYTICS_STREAM.send([event]),  // long-term storage + SQL
  env.PROCESS_QUEUE.send(event),       // immediate processing + retries
]);
```

Use Pipelines for long-term storage + SQL; Queues for immediate processing/retries/DLQ; both for fan-out.

## Observability (GraphQL Analytics)

Use a token with the required analytics permissions; R2 access alone does not establish GraphQL access. Endpoint: `https://api.cloudflare.com/client/v4/graphql`. Datasets cover ingestion, processing (incl. `decodeErrors`), delivery, sink writes (`filesWritten`), and user/validation errors — see the metrics doc for the full dataset/field catalog.

```bash
curl -X POST "https://api.cloudflare.com/client/v4/graphql" \
  -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"query": "query { viewer { accounts(filter: {accountTag: \"'$ACCOUNT_ID'\"}) { pipelinesIngestionAdaptiveGroups(filter: {pipelineId: \"PIPELINE-UUID-WITH-DASHES\", datetime_geq: \"2026-03-01T00:00:00Z\"}, limit: 10) { sum { ingestedRecords ingestedBytes } dimensions { datetimeHour } } } } }"}'
```

> **Sink/pipeline IDs need dashes for GraphQL** but wrangler may show them without: `b909fe6e544844abbd63f6dcbc81d602` → `b909fe6e-5448-44ab-bd63-f6dcbc81d602`. Metrics take 5–10 min to populate.

### Detecting Silent Data Loss

If a sink's bucket is deleted or its token expires, events are accepted but lost. Tell-tale: `recordsWritten > 0` but `filesWritten = 0`. Always verify data lands in R2 within the roll interval and R2 SQL returns expected counts.

## Schema Evolution

For an incompatible schema change, version the stream and plan a cutover. Dual-write is non-atomic and may duplicate events:

```bash
npx wrangler pipelines streams create events_v2 --schema-file v2.json
```
```typescript
await Promise.all([env.EVENTS_V1.send([event]), env.EVENTS_V2.send([event])]);
// query across versions with UNION ALL in R2 SQL
```

## End-to-End: Streaming Analytics Dashboard

```
External APIs → Collector Worker (cron) → Pipeline → R2 (Iceberg) → Dashboard Worker → R2 SQL
```

1. Create bucket + enable catalog ([r2-data-catalog](../r2-data-catalog/configuration.md))
2. Create stream + sink + pipeline (here)
3. Collector Worker with cron + stream binding (above)
4. Dashboard Worker querying R2 SQL ([r2-sql/patterns.md](../r2-sql/patterns.md))
5. Enable automatic compaction

## See Also

- [configuration.md](configuration.md) · [api.md](api.md) · [gotchas.md](gotchas.md) · [r2-sql](../r2-sql/)
