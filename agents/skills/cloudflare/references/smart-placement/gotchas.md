# Smart Placement Gotchas

## Common Errors

### "INSUFFICIENT_INVOCATIONS"

**Cause:** Not enough traffic for Smart Placement to analyze
**Solution:**
- Ensure Worker receives consistent global traffic
- Wait longer (analysis takes up to 15 minutes)
- Send test traffic from multiple global locations
- Check Worker has fetch event handler

### "UNSUPPORTED_APPLICATION"

**Cause:** Smart Placement made Worker slower rather than faster
**Reasons:**
- Worker doesn't make backend calls (runs faster at edge)
- Backend calls are cached (network latency to user more important)
- Backend service has good global distribution
- Worker serves static assets or Pages content

**Solutions:**
- Disable Smart Placement: `{ "placement": { "mode": "off" } }`
- Review whether Worker actually benefits from Smart Placement
- Consider caching strategy to reduce backend calls
- For mixed asset/backend workloads, measure whether a separate backend Worker helps

### "No request duration metrics"

**Cause:** Smart Placement not enabled, insufficient time passed, insufficient traffic, or analysis incomplete
**Solution:**
- Ensure Smart Placement enabled in config
- Wait 15+ minutes after deployment
- Verify Worker has sufficient traffic
- Check `placement_status` is `SUCCESS`

### "cf-placement header missing"

**Cause:** Smart Placement not enabled, beta feature removed, or Worker not analyzed yet
**Solution:** Verify Smart Placement enabled, wait for analysis (15min), check if beta feature still available

## Static Assets and Placement

Static assets served directly are delivered near the incoming request. Assets fetched by your code through `env.ASSETS.fetch()` are served where that Worker runs. `run_worker_first` affects which requests execute code; measure the full route before deciding to split frontend/backend Workers. Pages Functions and Workers Static Assets use different configuration models. There is no universal 2–5x penalty or blanket prohibition on combining assets with placement.

[Current placement behavior](https://developers.cloudflare.com/workers/configuration/placement/)

## Monolithic Full-Stack Worker

**Problem:** Frontend and backend logic in single Worker with Smart Placement enabled.

**Cause:** A mixed workload may have different optimal locations. Measure before splitting; placement considers forwarding latency when making decisions.

**Possible solution after measurement:** Split into two Workers:
```jsonc
// frontend/wrangler.jsonc
{
  "name": "frontend",
  "placement": { "mode": "off" },  // Explicit: stay at edge
  "services": [{ "binding": "BACKEND", "service": "backend-api" }]
}

// backend/wrangler.jsonc
{
  "name": "backend-api",
  "placement": { "mode": "smart" },
  "d1_databases": [{ "binding": "DB", "database_id": "xxx" }]
}
```

## Local Development Confusion

**Issue:** Smart Placement doesn't work in `wrangler dev`.

**Explanation:** Smart Placement only activates in production deployments, not local development.

**Solution:** Test Smart Placement in staging environment: `wrangler deploy --env staging`

## Baseline Traffic & Analysis Time

**Note:** Smart Placement routes 1% of requests WITHOUT optimization for comparison (expected).

**Analysis time:** Up to 15 minutes. During analysis, Worker runs at edge. Monitor `placement_status`.

## RPC Placement Is Not Verified

The official documentation has an explicit fetch-only limitation alongside an RPC placement example. Use fetch-based bindings for the examples in this reference. If an existing RPC backend is slow, measure it and verify hosted placement support before changing the API shape.

## Requirements

- **Wrangler 2.20.0+** required
- **Consistent multi-region traffic** needed for analysis
- **Only affects fetch handlers** - RPC methods and named entrypoints not affected

## Limits

| Resource/Limit | Value | Notes |
|----------------|-------|-------|
| Analysis time | Up to 15 minutes | After enabling |
| Baseline traffic | 1% | Routed without optimization |
| Min Wrangler version | 2.20.0+ | Required |
| Traffic requirement | Multi-region | Consistent needed |

## Disabling Smart Placement

```jsonc
{ "placement": { "mode": "off" } }  // Explicit disable
// OR remove "placement" field entirely (same effect)
```

Both behaviors identical - Worker runs at edge closest to user.

## When NOT to Use Smart Placement

- Workers serving only static content or cached responses
- Workers without significant backend communication
- Pure edge logic (auth checks, redirects, simple transformations)
- Workers without fetch event handlers
- Workers using RPC methods instead of fetch handlers

These scenarios won't benefit and may perform worse with Smart Placement.

The official placement page currently contains an RPC example that conflicts with its explicit fetch-only limitation. Rely on fetch-based calls for this reference; verify hosted RPC placement before changing architecture based on that example.
