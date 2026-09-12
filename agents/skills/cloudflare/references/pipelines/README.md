# Cloudflare Pipelines

Streaming ingest: receive events over HTTP/Workers/Logpush, transform with SQL, write to R2 as Iceberg tables or Parquet/JSON files.

## Documentation

This reference is a fast-start; verify the selected API and runtime path before claiming it works. For limits, settings, full SQL syntax, and pricing, **retrieve the live docs** — use the `cloudflare-docs` MCP/search tool if available, otherwise `webfetch` the URL. Docs are source of truth over this file.

| Topic | URL |
|-------|-----|
| Overview / getting started | `https://developers.cloudflare.com/pipelines/getting-started/` |
| Streams (write, manage, Logpush) | `https://developers.cloudflare.com/pipelines/streams/` |
| Sinks | `https://developers.cloudflare.com/pipelines/sinks/` |
| Pipelines & SQL transforms | `https://developers.cloudflare.com/pipelines/pipelines/` |
| SQL reference (statements, types) | `https://developers.cloudflare.com/pipelines/sql-reference/` |
| Wrangler commands | `https://developers.cloudflare.com/pipelines/reference/wrangler-commands/` |
| Terraform | `https://developers.cloudflare.com/pipelines/reference/terraform/` |
| Limits | `https://developers.cloudflare.com/pipelines/platform/limits/` |
| Pricing | `https://developers.cloudflare.com/pipelines/platform/pricing/` |
| Metrics (GraphQL) | `https://developers.cloudflare.com/pipelines/observability/metrics/` |

## Three Components

```
Sources → Stream → Pipeline (SQL) → Sink → R2
          ↑          ↓                 ↓
   HTTP / Workers / Transform     Iceberg (Data Catalog)
   Logpush          (row-level)   or Parquet/JSON files
```

| Component | Purpose |
|-----------|---------|
| **Stream** | Receives events (HTTP endpoint, Worker binding, or Logpush). Structured (schema-validated) or unstructured. |
| **Pipeline** | SQL connecting a stream to a sink. Row-level transforms only — no GROUP BY/aggregation. |
| **Sink** | Writes to R2 — Iceberg via Data Catalog, or raw Parquet/JSON. |

**Status:** Open beta (Workers Paid for production). Pricing announced; verify billing status in docs.

## Quick Start

```bash
# Interactive — creates stream + sink + pipeline, optionally bucket + catalog
npx wrangler pipelines setup
```

Minimal Worker producer:
```typescript
import type { Pipeline } from "cloudflare:pipelines";

interface Env { MY_STREAM: Pipeline; }

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    await env.MY_STREAM.send([{ event_id: crypto.randomUUID(), amount: 29.99 }]);
    return new Response("Accepted for processing", { status: 202 });
  }
} satisfies ExportedHandler<Env>;
```

## Which Sink Type?

```
Need SQL queries / ACID / time-travel on the data?
  → R2 Data Catalog (Iceberg)   ✅ R2 SQL, schema evolution   ❌ more setup

Just archival / external tools (Spark, Athena)?
  → R2 raw files (Parquet/JSON) ✅ simple, partitioned files  ❌ no built-in SQL
```

## Critical Behaviors (read before building)

These are non-obvious and prevent most failures — see [gotchas.md](gotchas.md) for detail.

- **Schemas/SQL and some sink settings are immutable** — check the field and resource. Stream HTTP authentication/CORS can be updated; schema changes require versioned streams. Never delete buffered events as routine configuration repair.
- **Sinks create their own table** — they cannot target an existing Iceberg table.
- **`__ingest_ts` is added automatically** (TIMESTAMP, partitioned by day). Don't define it in your schema.
- **Data isn't queryable immediately** — first flush takes **several minutes (measure the actual pipeline)** (warm-up + table creation) even with a short roll interval.
- **Schema validation is deferred** — invalid events are accepted then silently dropped. Monitor via GraphQL error metrics.
- **Binding field renamed `pipeline` → `stream`** (June 2026); old field still accepted.

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## See Also

- [r2-data-catalog](../r2-data-catalog/) — Iceberg sink destination
- [r2-sql](../r2-sql/) — query the ingested data
- [r2](../r2/) · [queues](../queues/) · [workers](../workers/)
