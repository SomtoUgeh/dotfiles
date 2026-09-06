## Common Errors

### "Logs not appearing"

**Cause:** Observability disabled, Worker not redeployed, no traffic, low sampling rate, or log size exceeds 256 KB
**Solution:**
```bash
# Verify config
cat wrangler.jsonc # Read JSONC directly; jq does not accept comments

# Check deployment
wrangler deployments list --name <WORKER_NAME>

# Test with curl
curl https://your-worker.workers.dev
```
Ensure `observability.enabled = true`, redeploy Worker, check `head_sampling_rate`, verify traffic

### "Traces not being captured"

**Cause:** Traces not enabled, incorrect sampling rate, Worker not redeployed, or destination unavailable
**Solution:**
```jsonc
// Temporarily set to 100% sampling for debugging
{
  "observability": {
    "enabled": true,
    "head_sampling_rate": 1.0,
    "traces": {
      "enabled": true
    }
  }
}
```
Ensure `observability.traces.enabled = true`, set `head_sampling_rate` to 1.0 for testing, redeploy, check destination status

## Limits

| Resource/Limit | Value | Notes |
|----------------|-------|-------|
| Max log size | 256 KB | Logs exceeding this are truncated |
| Default sampling rate | 1.0 (100%) | Reduce for high-traffic Workers |
| Max destinations | Varies by plan | Check dashboard |
| Analytics Engine data points | 250 per invocation | One index and up to 20 blobs/20 doubles per point |

## Performance Gotchas

### Spectre Mitigation Timing

**Problem:** Workers clocks advance with I/O rather than measuring time spent in synchronous JavaScript
**Cause:** Spectre vulnerability mitigation in V8
**Solution:** Use CPU profiling or execution telemetry for synchronous work; do not use a clock delta as a CPU benchmark
```typescript
// Wall-clock deltas across I/O are useful; synchronous CPU timing needs profiling
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // For user-facing timing, Date.now() is fine
    const start = Date.now();
    const response = await processRequest(request);
    const duration = Date.now() - start;

    // For detailed performance analysis, use Workers Traces instead
    return response;
  }
}
```

### Analytics Engine _sample_interval Aggregation

**Problem:** Queries return incorrect totals when not multiplying by `_sample_interval`
**Cause:** Analytics Engine stores sampled data points, each representing multiple events
**Solution:** Always multiply counts/sums by `_sample_interval` in aggregations
```sql
-- WRONG: Undercounts actual events
SELECT blob1 AS customer_id, COUNT(*) AS total_calls
FROM api_usage GROUP BY customer_id;

-- CORRECT: Accounts for sampling
SELECT blob1 AS customer_id, SUM(_sample_interval) AS total_calls
FROM api_usage GROUP BY customer_id;
```

### Trace context and pricing

Use the current [tracing limitations](https://developers.cloudflare.com/workers/observability/traces/) rather than assuming a universal 100-span depth limit. A custom correlation ID can aid logging, but is not a replacement for propagated trace context.

For current billing and retention, see [README.md](README.md). Workers Logs is metered with historical retention, tracing beta pricing has a dated transition, and Analytics Engine's published future rates are not proof that billing is active.
