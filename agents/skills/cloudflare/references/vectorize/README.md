# Cloudflare Vectorize

Vectorize stores dense vectors for semantic retrieval. Choose dimensions and a distance metric that match the embedding model, then use the same model and preprocessing for ingestion and queries. A dimension change requires a new index and re-embedding.

```typescript
const embeddings = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [query] });
if (!("data" in embeddings) || !embeddings.data) throw new Error("Expected synchronous embeddings");
const vector = embeddings.data[0];
if (!vector) throw new Error("Embedding missing");
const result = await env.VECTORIZE.query(vector, {
  topK: 5, returnMetadata: "all",
});
```

The example model produces 768 dimensions. Validate model availability and schema in the [current catalog](https://developers.cloudflare.com/workers-ai/models/) before selecting it for a new workload.

| Task | Reference |
|---|---|
| Index, binding, metadata indexes | [configuration.md](configuration.md) |
| CRUD, query, filters, mutation tracking | [api.md](api.md) |
| RAG, tenants, batches | [patterns.md](patterns.md) |
| Dimensions, consistency, limits | [gotchas.md](gotchas.md) |

Namespaces and metadata filters narrow search **before** top-K selection. They do not authorize access. Enforce tenant ownership in the application for queries, ID lookups, mutations, and document fetches.

[Client API](https://developers.cloudflare.com/vectorize/reference/client-api/) · [Metadata filtering](https://developers.cloudflare.com/vectorize/reference/metadata-filtering/) · [Current limits](https://developers.cloudflare.com/vectorize/platform/limits/)
