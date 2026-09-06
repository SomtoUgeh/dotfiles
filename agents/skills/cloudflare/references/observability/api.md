## API Reference

### GraphQL Analytics API

**Endpoint**: `https://api.cloudflare.com/client/v4/graphql`

**Query Workers Metrics**:
```graphql
query ($accountId: String!) {
  viewer {
    accounts(filter: { accountTag: $accountId }) {
      workersInvocationsAdaptive(
        limit: 100
        filter: {
          datetime_geq: "2025-01-01T00:00:00Z"
          datetime_leq: "2025-01-31T23:59:59Z"
          scriptName: "my-worker"
        }
      ) {
        sum {
          requests
          errors
          subrequests
        }
        quantiles {
          cpuTimeP50
          cpuTimeP99
          wallTimeP50
          wallTimeP99
        }
      }
    }
  }
}
```

### Analytics Engine SQL API

**Endpoint**: `https://api.cloudflare.com/client/v4/accounts/{account_id}/analytics_engine/sql`

**Authentication**: `Authorization: Bearer <API_TOKEN>` (Account Analytics Read permission)

**Common Queries**:

```sql
-- List all datasets
SHOW TABLES;

-- Time-series aggregation (5-minute buckets)
SELECT
  intDiv(toUInt32(timestamp), 300) * 300 AS time_bucket,
  blob1 AS endpoint,
  SUM(_sample_interval) AS total_requests,
  SUM(_sample_interval * double1) / SUM(_sample_interval) AS avg_response_time_ms
FROM api_metrics
WHERE timestamp >= NOW() - INTERVAL '24' HOUR
GROUP BY time_bucket, endpoint
ORDER BY time_bucket DESC;

-- Top customers by usage
SELECT
  index1 AS customer_id,
  SUM(_sample_interval * double1) AS total_api_calls,
  SUM(_sample_interval * double2) / SUM(_sample_interval) AS avg_response_time_ms
FROM api_usage
WHERE timestamp >= NOW() - INTERVAL '7' DAY
GROUP BY customer_id
ORDER BY total_api_calls DESC
LIMIT 100;

-- Error rate analysis
SELECT
  blob1 AS error_type,
  SUM(_sample_interval) AS occurrences,
  MAX(timestamp) AS last_seen
FROM error_tracking
WHERE timestamp >= NOW() - INTERVAL '1' HOUR
GROUP BY error_type
ORDER BY occurrences DESC;
```

### Console Logging API

**Methods**:
```typescript
// Standard methods (all appear in Workers Logs)
console.log('info message');
console.info('info message');
console.warn('warning message');
console.error('error message');
console.debug('debug message');

// Structured logging (recommended)
console.log({
  level: 'info',
  user_id: '123',
  action: 'checkout',
  amount: 99.99,
  currency: 'USD'
});
```

**Log Levels**: All console methods produce logs; use structured fields for filtering:
```typescript
console.log({
  level: 'error',
  message: 'Payment failed',
  error_code: 'CARD_DECLINED'
});
```

### Binding and Tail Types

Use `wrangler types` and the generated `AnalyticsEngineDataset`, `AnalyticsEngineDataPoint`, `TraceItem`, and `ExportedHandler` types. Do not maintain a simplified copy that silently diverges from the runtime.

Current Analytics Engine limits are 20 blobs, 20 doubles, **one index**, and 250 data points per invocation. Blobs also accept supported binary types; see the generated declarations and [limits](https://developers.cloudflare.com/analytics/analytics-engine/limits/).

A `TraceItem` has top-level `outcome`, `cpuTime`, `wallTime`, `logs`, and `exceptions`. Its `event` describes the triggering request/schedule/etc. and can be null; it is not a nested timing/outcome object. Use a typed handler:

```typescript
interface Env { LOG_SINK: Fetcher; }
export default {
  async tail(events, env) {
    const failures = events.filter(event => event.outcome !== 'ok');
    if (failures.length === 0) return;
    const response = await env.LOG_SINK.fetch('https://log-sink/ingest', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(failures),
    });
    if (!response.ok) throw new Error(`Log sink failed: ${response.status}`);
  },
} satisfies ExportedHandler<Env>;
```

Log messages and exception details may contain sensitive values; apply the project's redaction policy before external export. [Tail handler reference](https://developers.cloudflare.com/workers/runtime-apis/handlers/tail/).
