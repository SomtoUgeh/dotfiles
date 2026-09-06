# Vectorize patterns

## Tenant-aware document retrieval

Authenticate the caller, derive an authorized tenant namespace, and use tenant-qualified vector IDs. Fetch documents only after verifying their keys belong to that tenant. Metadata is data, not an authorization decision.

```typescript
const found = await env.VECTORIZE.query(vector, {
  namespace: tenantId, topK: 5, returnMetadata: "all",
});
const context: string[] = [];
for (const match of found.matches) {
  const key = match.metadata?.key;
  if (typeof key !== "string" || !key.startsWith(`${tenantId}/`)) continue;
  const object = await env.DOCUMENTS.get(key);
  if (object) context.push(await object.text());
}
```

Here `tenantId` is a server-derived identifier with a delimiter-safe format; enforce document-level permissions too if users have different access within the tenant. Bound document sizes and total prompt context. Tell the generation model to treat retrieved text as untrusted source material and validate application actions independently of model output.

## Ingestion

```typescript
for (let offset = 0; offset < vectors.length; offset += 1000) {
  const batch = vectors.slice(offset, offset + 1000);
  await env.VECTORIZE.upsert(batch);
}
```

The Workers binding allows up to 1000 vectors per batch. Apply backpressure and bounded retries, record failures and mutation IDs, and do not declare ingestion complete until visibility requirements are met. Use stable IDs so a retry does not duplicate documents.

## Filtering versus hybrid retrieval

A metadata filter such as category/date restrictions narrows vector search. It is not lexical full-text ranking. For hybrid search, retrieve lexical candidates through a separate search system and deliberately combine/rerank results. Keep authorization consistent across both systems.

Namespace capacity is plan-dependent; exceeding it requires deliberate partitioning or metadata filtering with application authorization, not shared unqualified IDs. Do not choose a tenant architecture solely from a copied numeric limit.
