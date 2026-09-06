# Analytics Engine API Reference

## Writing Data

### `writeDataPoint()`

Fire-and-forget (returns `void`, not Promise). Writes happen asynchronously.

```typescript
interface AnalyticsEngineDataPoint {
  blobs?: string[];      // Up to 20 strings (dimensions), 16 KB total across blobs
  doubles?: number[];    // Up to 20 numbers (metrics)
  indexes?: string[];    // 1 indexed string for high-cardinality filtering
}

env.ANALYTICS.writeDataPoint({
  blobs: ["/api/users", "GET", "200"],
  doubles: [145.2, 1],  // latency_ms, count
  indexes: ["customer_abc123"]
});
```

**Behaviors:** Returns void and automatically timestamps points. Invalid inputs can throw synchronously; a return is not proof of durable ingestion. Queries must account for sampling using `_sample_interval`.

**Blob vs Index:** Blobs hold dimensions; the index defines the sampling group and supports filtering and grouping. Choose a non-secret customer or entity ID.

### Full Example

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const start = Date.now();
    const url = new URL(request.url);
    try {
      const response = await handleRequest(request);
      env.ANALYTICS.writeDataPoint({
        blobs: [url.pathname, request.method, response.status.toString()],
        doubles: [Date.now() - start, 1],
        indexes: ["anonymous" // Replace with a non-secret ID from verified authentication]
      });
      return response;
    } catch (error) {
      env.ANALYTICS.writeDataPoint({
        blobs: [url.pathname, request.method, "500"],
        doubles: [Date.now() - start, 1, 0],
      });
      throw error;
    }
  }
};
```

## SQL API (HTTP)

```bash
curl -X POST https://api.cloudflare.com/client/v4/accounts/{account_id}/analytics_engine/sql \
  -H "Authorization: Bearer $TOKEN" \
  -d "SELECT blob1 AS endpoint, SUM(_sample_interval) AS requests FROM dataset WHERE timestamp >= NOW() - INTERVAL '1' HOUR GROUP BY blob1"
```

### Column References

```sql
-- blob1..blob20, double1..double20, index1, timestamp
SELECT blob1 AS endpoint, SUM(double1 * _sample_interval) AS latency, SUM(_sample_interval) AS requests
FROM my_dataset
WHERE index1 = 'customer_123' AND timestamp >= NOW() - INTERVAL '7' DAY
GROUP BY blob1
HAVING SUM(_sample_interval) > 100
ORDER BY requests DESC LIMIT 100
```

**Aggregations:** `SUM()`, `AVG()`, `COUNT()`, `MIN()`, `MAX()`, `quantileExactWeighted(0.95)(value, _sample_interval)`

**Time ranges:** `NOW() - INTERVAL '1' HOUR`, `BETWEEN '2026-01-01' AND '2026-01-31'`

### Query Examples

```sql
-- Top endpoints
SELECT blob1, SUM(_sample_interval) AS requests, SUM(double1 * _sample_interval) / SUM(_sample_interval) AS avg_latency
FROM api_requests WHERE timestamp >= NOW() - INTERVAL '24' HOUR
GROUP BY blob1 ORDER BY requests DESC LIMIT 20

-- Error rate
SELECT blob1, SUM(_sample_interval) AS total,
  SUM(CASE WHEN blob3 LIKE '5%' THEN _sample_interval ELSE 0 END) AS errors
FROM api_requests WHERE timestamp >= NOW() - INTERVAL '1' HOUR
GROUP BY blob1 HAVING total > 50

-- P95 latency
SELECT blob1, quantileExactWeighted(0.95)(double1, _sample_interval) AS p95
FROM api_requests GROUP BY blob1
```

## Response Format

```json
{"data": [{"endpoint": "/api/users", "requests": 1523}], "rows": 2}
```

## Limits

| Resource | Limit |
|----------|-------|
| Blobs/Doubles per point | 20 each |
| Indexes per point | 1 |
| Total blobs / index size | 16 KB / 96 bytes |
| Data retention | 90 days |
| Query timeout | 30s |

Sampling can occur during ingestion and queries. There is no documented universal one-million-per-minute exemption. Weight aggregates by `_sample_interval`.

Sampling reference: [Analytics Engine sampling](https://developers.cloudflare.com/analytics/analytics-engine/sampling/).
