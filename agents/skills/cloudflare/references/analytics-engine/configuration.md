# Analytics Engine Configuration

## Setup

1. Add binding to `wrangler.jsonc`
2. Deploy Worker
3. Dataset created automatically on first write
4. Query via SQL API

## wrangler.jsonc

```jsonc
{
  "name": "my-worker",
  "analytics_engine_datasets": [
    { "binding": "ANALYTICS", "dataset": "my_events" }
  ]
}
```

Multiple datasets for separate concerns:
```jsonc
{
  "analytics_engine_datasets": [
    { "binding": "API_ANALYTICS", "dataset": "api_requests" },
    { "binding": "USER_EVENTS", "dataset": "user_activity" }
  ]
}
```

## TypeScript

```typescript
interface Env {
  ANALYTICS: AnalyticsEngineDataset;
}

function record(env: Env, customerId: string, pathname: string, latency: number) {
  env.ANALYTICS.writeDataPoint({
    blobs: [pathname],
    doubles: [latency, 1],
    indexes: [customerId]
  });
}
```

## Data Point Limits

| Field | Limit | SQL Access |
|-------|-------|------------|
| blobs | 20 strings, 16 KB total across blobs | `blob1`...`blob20` |
| doubles | 20 numbers | `double1`...`double20` |
| indexes | 1 string, 96 bytes | `index1` |

## Write behavior and cost

Writes and queries can be sampled by index group. Use weighted SQL; do not try to suppress sampling with an isolate-local buffer. Invalid data may throw synchronously. Confirm ingestion and query results separately.

Consult [limits](https://developers.cloudflare.com/analytics/analytics-engine/limits/) and [pricing](https://developers.cloudflare.com/analytics/analytics-engine/pricing/) before capacity or cost estimates.

## Environment-Specific

```jsonc
{
  "analytics_engine_datasets": [
    { "binding": "ANALYTICS", "dataset": "prod_events" }
  ],
  "env": {
    "staging": {
      "analytics_engine_datasets": [
        { "binding": "ANALYTICS", "dataset": "staging_events" }
      ]
    }
  }
}
```

## Monitoring

```bash
npx wrangler tail  # Check for sampling/write errors
```

```sql
-- Check write activity
SELECT DATE_TRUNC('hour', timestamp) AS hour, SUM(_sample_interval) AS writes
FROM my_dataset
WHERE timestamp >= NOW() - INTERVAL '24' HOUR
GROUP BY hour
```

Sampling reference: [Analytics Engine sampling](https://developers.cloudflare.com/analytics/analytics-engine/sampling/).
