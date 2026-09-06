# AI Search Configuration

Create or choose an AI Search instance and configure its data source and indexing settings before querying. Supported ingestion formats, source requirements, and capacity must be checked against the current instance documentation.

## Instance binding

```jsonc
{
  "ai_search": [{ "binding": "DOCS", "instance_name": "prod-docs" }],
  "env": {
    "staging": {
      "ai_search": [{ "binding": "DOCS", "instance_name": "staging-docs" }]
    }
  }
}
```

Bindings are environment-specific; configure each environment explicitly.

## Namespace binding

Use a namespace when the application must select among authorized instances:

```jsonc
{
  "ai_search_namespaces": [{ "binding": "AI_SEARCH", "namespace": "default" }]
}
```

```typescript
interface Env { AI_SEARCH: AiSearchNamespace }

async function inspect(env: Env) {
  const instance = env.AI_SEARCH.get("docs");
  const info = await instance.info();
  const stats = await instance.stats();
  const page = await env.AI_SEARCH.list({ page: 1, per_page: 20 });
  return { info, stats, page };
}
```

Regenerate `wrangler types` after binding changes. The initial migration requires Wrangler 4.68.1 or later; use the current project-supported release. Prefer generated types over copied handwritten interfaces.

Store REST credentials in secrets, never in browser code or Wrangler vars. A Workers binding supplies its own service access; application authentication and tenant authorization are still your responsibility.

Sources: [Workers binding migration](https://developers.cloudflare.com/ai-search/api/migration/workers-binding/), [AI Search docs](https://developers.cloudflare.com/ai-search/).
