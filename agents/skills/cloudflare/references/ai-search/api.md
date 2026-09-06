# AI Search API

## Retrieval

```typescript
async function searchDocs(instance: AiSearchInstance, query: string) {
  const result = await instance.search({
    messages: [{ role: "user", content: query }],
    ai_search_options: {
      retrieval: {
        max_num_results: 10,
        match_threshold: 0.4,
        return_on_failure: false
      },
      query_rewrite: { enabled: true }
    }
  });
  return result.chunks.map(chunk => ({
    id: chunk.id,
    text: chunk.text,
    key: chunk.item.key,
    score: chunk.score
  }));
}
```

Current types also support `query` instead of `messages` for retrieval; supply exactly one. A chunk contains `id`, `type`, `score`, `text`, and `item` metadata. It is not the legacy `data[].content[]` shape.

## Generation and streaming

```typescript
async function answer(instance: AiSearchInstance, query: string) {
  return instance.chatCompletions({
    messages: [{ role: "user", content: query }],
    ai_search_options: { retrieval: { return_on_failure: false } }
  });
}

async function streamAnswer(instance: AiSearchInstance, query: string) {
  const stream = await instance.chatCompletions({
    messages: [{ role: "user", content: query }],
    stream: true,
    ai_search_options: { retrieval: { return_on_failure: false } }
  });
  return new Response(stream, {
    headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" }
  });
}
```

Non-streaming responses expose `choices[].message.content` and `chunks`. Check for empty choices and nullable content. The instance's model can be used, or pass a supported `model`.

## Metadata filtering

Filters live at `ai_search_options.retrieval.filters` and use Vectorize metadata syntax:

```typescript
const options = {
  retrieval: {
    filters: {
      tenant_id: { $eq: "tenant-123" },
      timestamp: { $gte: 1704067200 }
    },
    return_on_failure: false
  }
} satisfies AiSearchOptions;
```

Configure and populate the metadata fields used by filters. Comparison operators include `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, and `$nin`; consult the current filter documentation for supported combinations. A lower-bound comparison is not a path-prefix match.

## Management

`AiSearchNamespace` exposes `get`, `list`, `create`, and `delete`. An instance exposes `info`, `stats`, `update`, `items`, and `jobs`. Management calls change real resources; distinguish them from search calls. There is no `env.AI.autorag("_").listInstances()` method.

Use current [API documentation](https://developers.cloudflare.com/ai-search/) for REST routes and token permissions. The old `/autorag/rags/...` API belongs to the legacy interface; do not send current binding-shaped payloads to it.
