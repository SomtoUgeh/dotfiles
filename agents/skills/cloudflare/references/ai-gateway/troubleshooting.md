# AI Gateway Troubleshooting

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| 401 | Missing `cf-aig-authorization` header | Add header with CF API token |
| 403 | Invalid provider key / BYOK expired | Check provider key in dashboard |
| 429 | Rate limit exceeded | Increase limit or implement backoff |

### Authentication and retries

Match the token and model naming scheme to the endpoint; see [configuration.md](configuration.md). Set the SDK `apiKey` explicitly from the correct server secret.

Prefer the SDK's bounded `maxRetries` or the gateway retry policy. Do not stack multiple retry loops unknowingly; generation retries can repeat billed work. Set an overall request deadline and inspect the final error.

## Gotchas

| Issue | Reality |
|-------|---------|
| Metadata limits | Max 5 entries, flat only (no nesting) |
| Cache key collision | Use unique keys per expected response |
| BYOK + Unified Billing | Mutually exclusive |
| Rate limit scope | Per-gateway, not per-user (use dynamic routing for per-user) |
| Log delay | 30-60 seconds normal |
| Streaming + caching | Verify for the endpoint and provider; no blanket incompatibility guarantee |
| Model name (unified API) | Prefix required: `openai/gpt-4o`, not `gpt-4o` |

## Cache Not Working

**Causes:**
- Different request params (temperature, etc.)
- Response mode or endpoint behavior differs from the tested configuration
- Caching disabled in settings

**Check:** `response.headers.get('cf-aig-cache-status')` → HIT or MISS

## Logs Not Appearing

1. Check logging enabled: Dashboard → Gateway → Settings
2. Remove `cf-aig-collect-log: false` header
3. Wait 30-60 seconds
4. Check the current account log quota and retention

## Debugging

```bash
# Test connectivity
curl --fail-with-body https://gateway.ai.cloudflare.com/v1/{account}/{gateway}/openai/models \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "cf-aig-authorization: Bearer $CF_TOKEN"
```

```typescript
// Check response headers
console.log('Cache:', response.headers.get('cf-aig-cache-status'));
console.log('Request ID:', response.headers.get('cf-ray'));
```

## Analytics

Dashboard → AI Gateway → Select gateway

**Metrics:** Requests, tokens, latency (p50/p95/p99), cache hit rate, costs

**Log filters:** `status: error`, `provider: openai`, `cost > 0.01`, `duration > 1000`

**Export:** Logpush to S3/GCS/Datadog/Splunk

[Current REST and authentication examples](https://developers.cloudflare.com/ai-gateway/usage/rest-api/). HTTP 401/403 can originate from either the gateway or provider; inspect the response without logging credentials.
