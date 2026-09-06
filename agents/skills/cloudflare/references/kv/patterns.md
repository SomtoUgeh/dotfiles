# KV Patterns

## Typed cache with runtime validation

Use complete keys containing source version and every public response dimension. Do not share personalized responses under a global key. A decoder must validate the stored value; a generic `get<T>` is only a TypeScript promise.

```typescript
async function getCached<T>(kv: KVNamespace, key: string, decode: (value: unknown) => T, fetcher: () => Promise<T>): Promise<T> {
  const cached = await kv.get<unknown>(key, "json");
  if (cached !== null) return decode(cached);
  const data = await fetcher();
  await kv.put(key, JSON.stringify(data), { expirationTtl: 300 });
  return data;
}
```

Concurrent misses may perform duplicate fetches. Use a Durable Object if regeneration must be serialized. Avoid an unbounded isolate-level Map; it adds another stale cache and cannot coordinate Workers.

## Prefix pagination

```typescript
async function listUserIds(kv: KVNamespace): Promise<string[]> {
  const prefix = "user:";
  const ids: string[] = [];
  let cursor: string | undefined;
  while (true) {
    const page = await kv.list({ prefix, cursor });
    ids.push(...page.keys.map(key => key.name.slice(prefix.length)));
    if (page.list_complete) return ids;
    cursor = page.cursor;
  }
}
```

Prefixes are naming conventions, not authorization boundaries. Derive tenant prefixes from a verified server-side identity.

## Sessions and feature flags

KV can hold noncritical preferences and cached session data when delayed creation/revocation is acceptable. Check absolute expiry on each read and fail closed on missing or invalid session data. Use a strongly consistent authority for authorization, immediate logout, locks, counters, and rate limits.

## Metadata and schema changes

Metadata is limited to 1024 bytes. Validate it before use. Store a schema version with each document and use versioned keys or a coordinated migration. A read-then-write migration on the request path can overwrite a concurrent update; KV has no compare-and-swap operation.

Coalescing related cold keys reduces reads but rewrites the whole object and increases contention. Choose keys around actual read/write patterns.

See [API](api.md), [configuration](configuration.md), and [gotchas](gotchas.md).
