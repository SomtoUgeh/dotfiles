# AI Gateway Configuration

Create or select a gateway, then configure authentication, model credentials or billing, caching, rate limits, and logging for its intended environment. Management changes and model requests affect the account and may incur charges.

## Workers configuration

```toml
[ai]
binding = "AI"
```

Pass `{ gateway: { id: "my-gateway" } }` in `env.AI.run` options, or use `env.AI.gateway("my-gateway")`. There is no `[[ai.gateway]]` Wrangler config section.

## Endpoint and authentication selection

| Path | Authentication and model format |
|------|---------------------------------|
| Cloudflare `/accounts/{account}/ai/v1` | Cloudflare token; provider-prefixed model; optional `cf-aig-gateway-id` (required for Workers AI models) |
| Gateway provider-native `/.../{gateway}/openai` | Provider key; unprefixed OpenAI model; gateway token in `cf-aig-authorization` if enabled |
| Gateway `/.../{gateway}/compat` | Cloudflare token for stored-key dynamic routing; `dynamic/{route}` |

For new single-model OpenAI-compatible calls, use the Cloudflare REST endpoint. `/compat` remains required for dynamic routes. See [SDK examples](sdk-integration.md).

Unified Billing and stored provider keys have provider/model-specific support. Check the current configuration rather than assuming every listed provider is keyless. An OpenAI SDK constructor still requires `apiKey`; leaving it out only works if its expected environment variable exists.

## Secrets

```bash
wrangler secret put CF_API_TOKEN
wrangler secret put OPENAI_API_KEY
```

Only add secrets required by the chosen transport. Do not expose provider or gateway tokens in browser code. Select API-token permissions from the current endpoint's accepted permissions; management access and inference access are different.

## Management

Use the dashboard or the [current management API](https://developers.cloudflare.com/api/resources/ai_gateway/). Read existing configuration before updates and preserve unrelated fields. Verify the resulting gateway settings; a local configuration validation does not exercise hosted routing.

Sources: [REST API](https://developers.cloudflare.com/ai-gateway/usage/rest-api/), [gateway authentication](https://developers.cloudflare.com/ai-gateway/configuration/authentication/).
