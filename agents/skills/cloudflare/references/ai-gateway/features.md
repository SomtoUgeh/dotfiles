# Features & Capabilities

## Caching

Dashboard: Settings → Cache Responses → Enable

```typescript
// Custom TTL (1 hour)
headers: { 'cf-aig-cache-ttl': '3600' }

// Skip cache
headers: { 'cf-aig-skip-cache': 'true' }

// Custom cache key
headers: { 'cf-aig-cache-key': responseEquivalentKey // Includes tenant, prompt, model, and relevant options }
```

**Limits:** TTL 60s - 30 days. Check caching behavior for the selected endpoint and response mode; do not assume all streaming is unsupported.

## Rate Limiting

Dashboard: Settings → Rate-limiting → Enable

- **Fixed window:** Resets at intervals
- **Sliding window:** Rolling window (more accurate)
- Returns `429` when exceeded

## Guardrails

Dashboard: Settings → Guardrails → Enable

Filter prompts/responses for inappropriate content. Actions: Flag (log) or Block (reject).

## Data Loss Prevention (DLP)

Dashboard: Settings → DLP → Enable

Detect PII (emails, SSNs, credit cards). Actions: Flag, Block, or Redact.

## Billing Modes

| Mode | Description | Setup |
|------|-------------|-------|
| **Unified Billing** | Pay through Cloudflare, no provider keys | Use the authentication scheme for the selected Cloudflare endpoint |
| **BYOK** | Store provider keys in dashboard | Add keys in Provider Keys section |
| **Pass-through** | Send provider key with each request | Include provider's auth header |

## Zero Data Retention

Dashboard: Settings → Privacy → Zero Data Retention

No prompts/responses stored. Request counts and costs still tracked.

## Logging

Dashboard: configure logs and verify the current account retention/quota.

Each entry: prompt, response, provider, model, tokens, cost, duration, cache status, metadata.

```typescript
// Skip logging for request
headers: { 'cf-aig-collect-log': 'false' }
```

**Export:** Use Logpush to S3, GCS, Datadog, Splunk, etc.

## Custom Cost Tracking

For models not in Cloudflare's pricing database:

Dashboard: Gateway → Settings → Custom Costs

Or via API: set `model`, `input_cost`, `output_cost`.

## Supported providers

Consult the [current model catalog](https://developers.cloudflare.com/ai-gateway/models/) for provider IDs, billing support, and endpoint compatibility. Provider-native, compat, and current REST model names are not interchangeable.

## Best Practices

1. Enable caching for deterministic prompts
2. Set rate limits to prevent abuse
3. Use guardrails for user-facing AI
4. Enable DLP for sensitive data
5. Use unified billing or BYOK for simpler key management
6. Enable logging for debugging
7. Use zero data retention when privacy required

A custom cache key opts a request into caching and must be shared only by response-equivalent requests. Never use a constant key across different users or prompts. [Caching documentation](https://developers.cloudflare.com/ai-gateway/features/caching/).
