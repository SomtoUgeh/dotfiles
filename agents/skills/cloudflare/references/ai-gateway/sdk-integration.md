# AI Gateway SDK Integration

## OpenAI SDK: current Cloudflare REST endpoint

```typescript
import OpenAI from "openai";

function gatewayClient(accountId: string, gatewayId: string, cloudflareToken: string) {
  return new OpenAI({
    apiKey: cloudflareToken,
    baseURL: `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/v1`,
    defaultHeaders: { "cf-aig-gateway-id": gatewayId },
    maxRetries: 2
  });
}
```

Use provider-prefixed model IDs from the current model catalog with `chat.completions.create` or a supported Responses API model. Store the Cloudflare credential in a server secret. Confirm the selected model's billing and stored-key configuration before sending requests.

The provider-native route `gateway.ai.cloudflare.com/v1/{account}/{gateway}/openai` instead uses an OpenAI key, an unprefixed OpenAI model ID, and `cf-aig-authorization` when gateway authentication is enabled. Do not interchange those credentials or model formats.

## AI SDK 7 and ai-gateway-provider 4

```typescript
import { createAiGateway } from "ai-gateway-provider";
import { createOpenAI } from "ai-gateway-provider/providers/openai";
import { generateText } from "ai";

async function generate(accountId: string, gatewayId: string, token: string, providerKey: string) {
  const gateway = createAiGateway({
    accountId,
    gateway: gatewayId,
    apiKey: token,
    options: {
      cacheTtl: 3600,
      metadata: { requestType: "example" },
      retries: { maxAttempts: 3, retryDelayMs: 1000, backoff: "exponential" }
    }
  });
  const openai = createOpenAI({ apiKey: providerKey });
  return generateText({
    model: gateway(openai.chat("gpt-4.1-mini")),
    prompt: "Hello",
    maxRetries: 0 // Let the configured gateway retry policy own this request.
  });
}
```

Use this package's provider adapters, including the explicit `.chat()` model for OpenAI chat completions. Gateway request options belong in `createAiGateway({ options: ... })`, not a second argument to the model wrapper. For fallback, pass an array of compatible adapter models to `gateway([...])`; test the failing-primary path and avoid multiplying retries across layers.

## Workers AI binding

```toml
[ai]
binding = "AI"
```

Select the gateway in the call options, not a nonexistent `[[ai.gateway]]` Wrangler section:

```typescript
async function run(env: { AI: Ai }) {
  return env.AI.run("@cf/meta/llama-3.3-70b-instruct-fp8-fast", {
    messages: [{ role: "user", content: "Hello" }]
  }, { gateway: { id: "my-gateway" } });
}
```

For supported AI SDK adapters, `createAiGateway({ binding: env.AI.gateway("my-gateway") })` uses the binding transport.

## Dynamic routes

Use `/compat` and `dynamic/route-name`; see [dynamic-routing.md](dynamic-routing.md). This remains supported for routes even though single-model use of that endpoint is deprecated.

Sources: [Cloudflare REST API](https://developers.cloudflare.com/ai-gateway/usage/rest-api/), [AI Gateway provider source](https://github.com/cloudflare/ai/tree/main/packages/ai-gateway-provider).
