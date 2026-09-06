# Observability Patterns

## Usage-Based Billing

```typescript
env.ANALYTICS.writeDataPoint({
  blobs: [customerId, request.url, request.method],
  doubles: [1], // request_count
  indexes: [customerId]
});
```

```sql
SELECT blob1 AS customer_id, SUM(_sample_interval * double1) AS total_calls
FROM api_usage WHERE timestamp >= DATE_TRUNC('month', NOW())
GROUP BY customer_id
```

## Performance Monitoring

```typescript
const start = Date.now();
const response = await fetch(url);
env.ANALYTICS.writeDataPoint({
  blobs: [url, response.status.toString()],
  doubles: [Date.now() - start, response.status]
});
```

```sql
SELECT blob1 AS url, SUM(_sample_interval * double1) / SUM(_sample_interval) AS avg_ms,
  quantileExactWeighted(0.95)(double1, _sample_interval) AS p95_ms
FROM fetch_metrics WHERE timestamp >= NOW() - INTERVAL '1' HOUR
GROUP BY url
```

## Error Tracking

```typescript
env.ANALYTICS.writeDataPoint({
  blobs: [error.name, request.url, request.method],
  doubles: [1],
  indexes: [error.name]
});
```

## Multi-Tenant Tracking

```typescript
env.ANALYTICS.writeDataPoint({
  indexes: [tenantId], // efficient filtering
  blobs: [tenantId, url.pathname, method, status],
  doubles: [1, duration, bytesSize]
});
```

## Tail Worker Log Filtering

```typescript
export default {
  async tail(events, env, ctx) {
    const critical = events.filter(e =>
      e.exceptions.length > 0 || e.outcome !== 'ok'
    );
    if (critical.length === 0) return;

    ctx.waitUntil(
      fetch('https://logging.example.com/ingest', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${env.API_KEY}` },
        body: JSON.stringify(critical.map(e => ({
          outcome: e.outcome,
          errors: e.exceptions
        })))
      })
    );
  }
};
```

## OpenTelemetry Export

Use Cloudflare's built-in [OTel destinations](https://developers.cloudflare.com/workers/observability/exporting-opentelemetry-data/) for supported providers. Configure destination IDs under the producer's observability logs/traces settings and verify actual receipt. Do not fabricate unrelated span IDs from tail events or omit span timestamps: that loses trace relationships and does not form a valid export pipeline. If custom transformation is required, use a maintained OTLP SDK and the provider's current schema, with authentication and response checks.
