# Cloudflare AI Gateway

Expert guidance for implementing Cloudflare AI Gateway - a universal gateway for AI model providers with analytics, caching, rate limiting, and routing capabilities.

## When to Use This Reference

- Setting up AI Gateway for any AI provider (OpenAI, Anthropic, Workers AI, etc.)
- Implementing caching, rate limiting, or request retry/fallback
- Configuring dynamic routing with A/B testing or model fallbacks
- Managing provider API keys securely with BYOK
- Adding security features (guardrails, DLP)
- Setting up observability with logging and custom metadata
- Debugging AI Gateway requests or optimizing configurations

## Quick Start

**What's your setup?**

- **Using Vercel AI SDK** → Pattern 1 (recommended) - see [sdk-integration.md](./sdk-integration.md)
- **Using OpenAI SDK** → Pattern 2 - see [sdk-integration.md](./sdk-integration.md)
- **Cloudflare Worker + Workers AI** → Pattern 3 - see [sdk-integration.md](./sdk-integration.md)
- **Direct HTTP (any language)** → Pattern 4 - see [configuration.md](./configuration.md)
- **Framework (LangChain, etc.)** → See [sdk-integration.md](./sdk-integration.md)

## Choose the integration

- AI SDK 7: use ai-gateway-provider 4 and its own provider adapters, including explicit OpenAI .chat() models. See [working integration shapes](sdk-integration.md).
- OpenAI SDK single-model calls: use the current Cloudflare REST endpoint `/client/v4/accounts/{account}/ai/v1`, a Cloudflare token, and the cf-aig-gateway-id header.
- Provider-native calls: use the provider route, its model format and provider credential, plus gateway authentication where enabled.
- Dynamic routes: use `/compat` with dynamic/route-name; the compat endpoint remains supported for routing.
- Workers AI: configure an AI binding and select the gateway in AI.run call options.

## Headers Quick Reference

| Header | Purpose | Example | Notes |
|--------|---------|---------|-------|
| `cf-aig-authorization` | Gateway auth | `Bearer {token}` | Required for authenticated gateways |
| `cf-aig-metadata` | Tracking | `{"userId":"x"}` | Use current metadata limits and avoid sensitive values |
| `cf-aig-cache-ttl` | Cache duration | `3600` | Seconds; verify current limits |
| `cf-aig-skip-cache` | Bypass cache | `true` | - |
| `cf-aig-cache-key` | Custom cache key | `my-key` | Must be unique per response |
| `cf-aig-collect-log` | Skip logging | `false` | Default: true |
| `cf-aig-cache-status` | Cache hit/miss | Response only | `HIT` or `MISS` |

## In This Reference

| File | Purpose |
|------|---------|
| [sdk-integration.md](./sdk-integration.md) | Vercel AI SDK, OpenAI SDK, Workers binding patterns |
| [configuration.md](./configuration.md) | Dashboard setup, wrangler, API tokens |
| [features.md](./features.md) | Caching, rate limits, guardrails, DLP, BYOK, unified billing |
| [dynamic-routing.md](./dynamic-routing.md) | Fallbacks, A/B testing, conditional routing |
| [troubleshooting.md](./troubleshooting.md) | Debugging, errors, observability, gotchas |

## Reading Order

| Task | Files |
|------|-------|
| First-time setup | README + [configuration.md](./configuration.md) |
| SDK integration | README + [sdk-integration.md](./sdk-integration.md) |
| Enable caching | README + [features.md](./features.md) |
| Setup fallbacks | README + [dynamic-routing.md](./dynamic-routing.md) |
| Debug errors | README + [troubleshooting.md](./troubleshooting.md) |

## Architecture

AI Gateway acts as a proxy between your application and AI providers:

```
Your App → AI Gateway → AI Provider (OpenAI, Anthropic, etc.)
         ↓
    Analytics, Caching, Rate Limiting, Logging
```

**Key URL patterns:**
- Dynamic-route API (OpenAI-compatible): `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/compat/chat/completions`
- Provider-specific: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/{provider}/{endpoint}`
- Dynamic routes: Use route name instead of model: `dynamic/{route-name}`

## Gateway Types

1. **Unauthenticated Gateway**: Open access (not recommended for production)
2. **Authenticated Gateway**: Requires `cf-aig-authorization` header with Cloudflare API token (recommended)

## Provider Authentication Options

1. **Unified Billing**: Use AI Gateway billing to pay for inference (keyless mode - no provider API key needed)
2. **BYOK (Store Keys)**: Store provider API keys in Cloudflare dashboard
3. **Request Headers**: Include provider API key in each request

## Related Skills

- [Workers AI](../workers-ai/README.md) - For `env.AI.run()` details
- [Agents SDK](../agents-sdk/README.md) - For stateful AI patterns
- [Vectorize](../vectorize/README.md) - For RAG patterns with embeddings

## Resources

- [Official Docs](https://developers.cloudflare.com/ai-gateway/)
- [API Reference](https://developers.cloudflare.com/api/resources/ai_gateway/)
- [Provider Guides](https://developers.cloudflare.com/ai-gateway/usage/providers/)
- [Discord Community](https://discord.cloudflare.com)
