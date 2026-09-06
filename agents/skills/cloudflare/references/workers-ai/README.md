# Workers AI

Workers AI provides hosted inference through a Worker binding or REST API. Choose models from the current catalog based on task quality, input/output schema, context window, latency, availability, and measured cost. Do not use a fixed “best model” ranking or guessed neurons-per-request table.

The base `@cf/meta/llama-3.1-8b-instruct` model was deprecated on May 30, 2026. The following example uses the currently listed FP8 variant; verify model status when starting a new project.

```typescript
interface Env { AI: Ai }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const output = await env.AI.run("@cf/meta/llama-3.1-8b-instruct-fp8", {
      messages: [{ role: "user", content: "Explain what a Worker does." }],
      max_tokens: 128,
    });
    return Response.json(output);
  },
} satisfies ExportedHandler<Env>;
```

This is a binding smoke example. A public inference endpoint also needs application authentication/authorization, bounded input, abuse limits, error handling, and a budget appropriate to the product.

| Task | Reference |
|---|---|
| Bindings, local development, SDK setup | [configuration.md](configuration.md) |
| Text, embeddings, streams, REST | [api.md](api.md) |
| RAG, tools, retries, caching | [patterns.md](patterns.md) |
| Models, responses, limits | [gotchas.md](gotchas.md) |

`wrangler dev` can run the Worker locally while AI inference uses a remote binding and real account usage. Full `--remote` development is not mandatory. There is no local GPU inference emulator in that binding.

[Model catalog](https://developers.cloudflare.com/workers-ai/models/) · [FP8 model schema](https://developers.cloudflare.com/workers-ai/models/llama-3.1-8b-instruct-fp8/) · [Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
