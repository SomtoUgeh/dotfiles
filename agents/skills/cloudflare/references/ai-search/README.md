# Cloudflare AI Search

AI Search manages content ingestion, retrieval, and optional answer generation. Use it for a managed knowledge base; use Vectorize when the application needs to own embedding and indexing logic.

Use the current AI Search instance or namespace binding. The legacy Workers AI `env.AI.autorag(name)` API continues to exist, but its request and response shapes differ and it does not receive new features. Do not mix examples from the two APIs.

## Quick start

Configure an existing instance:

```jsonc
{
  "ai_search": [{ "binding": "DOCS", "instance_name": "my-search-instance" }]
}
```

```typescript
interface Env { DOCS: AiSearchInstance }

export default {
  async fetch(_request, env) {
    const result = await env.DOCS.search({
      messages: [{ role: "user", content: "How do I configure caching?" }],
      ai_search_options: { retrieval: { return_on_failure: false } }
    });
    return Response.json(result);
  }
} satisfies ExportedHandler<Env>;
```

`search()` returns retrieved `chunks`. `chatCompletions()` returns generated `choices` and supporting chunks, or an SSE stream when `stream: true`.

Instances support source synchronization and item management. Check indexing status for the selected source; do not assume every source takes six hours or that an upload is immediately searchable. Current limits and enabled retrieval modes depend on the instance and plan.

Read [configuration.md](configuration.md) for setup, [api.md](api.md) for calls, [patterns.md](patterns.md) for tenant isolation and streaming, and [gotchas.md](gotchas.md) for migration and debugging.

Sources: [AI Search](https://developers.cloudflare.com/ai-search/), [Workers binding migration](https://developers.cloudflare.com/ai-search/api/migration/workers-binding/). Generate current binding types with `wrangler types`.
