# Binding Patterns and Best Practices

## Service Binding Patterns

### HTTP via Service Bindings

```typescript
// auth-worker
export default {
  async fetch(request: Request, env: Env) {
    const token = request.headers.get('Authorization');
    return new Response(JSON.stringify({ valid: await validateToken(token) }));
  }
}

// api-worker
const response = await env.AUTH_SERVICE.fetch(
  new Request('https://fake-host/validate', {
    headers: { 'Authorization': token }
  })
);
```

**Why a service binding?** It targets the configured Worker without public DNS routing or API credentials. Calls still incur runtime work and latency.

**HTTP vs Service:**
```typescript
// Public HTTP endpoint
await fetch('https://auth-worker.example.com/validate');

// Configured service binding
await env.AUTH_SERVICE.fetch(new Request('https://fake-host/validate'));
```

**Binding selects the target:** The target still receives the URL, path, query, and headers and may use them for routing or authorization.

### Typed Service RPC

Use a class extending `WorkerEntrypoint` for actual RPC, and generate the caller's binding type from that class. See the [runtime example](../workers/api.md#service-bindings). For HTTP JSON APIs, validate input and response shapes at runtime; a TypeScript annotation does not authenticate a token or validate JSON.

## Secrets Management

```bash
# Set secret
npx wrangler secret put API_KEY
cat api-key.txt | npx wrangler secret put API_KEY
npx wrangler secret put API_KEY --env staging
```

```typescript
// Use secret
const response = await fetch('https://api.example.com', {
  headers: { 'Authorization': `Bearer ${env.API_KEY}` }
});
```

**Never commit secrets:**
```jsonc
// ❌ NEVER
{ "vars": { "API_KEY": "sk_live_abc123" } }
```

## Testing with Mock Bindings

### Runtime tests

Use the [Wrangler harness](../wrangler/api.md) or Cloudflare Vitest integration for binding semantics. For pure-function tests define a narrow dependency interface and mock it directly; do not cast an incomplete object to `KVNamespace` or `ExecutionContext`.

## Binding Access Patterns

### Lazy Access

```typescript
// ✅ Access only when needed
if (url.pathname === '/cached') {
  const cached = await env.MY_KV.get('data');
  if (cached) return new Response(cached);
}
```

### Parallel Access

```typescript
// ✅ Parallelize independent calls
const [user, config, cache] = await Promise.all([
  env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first(),
  env.MY_KV.get('config'),
  env.CACHE.get('data')
]);
```

## Storage Selection

### KV: CDN-Backed Reads

```typescript
const config = await env.MY_KV.get('app-config', { type: 'json' });
```

**Use when:** Read-heavy, <25MB, global distribution, eventual consistency OK  
**Consistency:** Reads can be cached; propagation can take 60 seconds or more. Measure latency for the actual workload.

### D1: Relational Queries

```typescript
const results = await env.DB.prepare(`
  SELECT u.name, COUNT(o.id) FROM users u
  LEFT JOIN orders o ON u.id = o.user_id GROUP BY u.id
`).all();
```

**Use when:** Relational data, JOINs, ACID transactions  
**Limits:** Check current D1 plan and query limits.

### R2: Large Objects

```typescript
const object = await env.MY_BUCKET.get('large-file.zip');
if (!object) return new Response('Not found', { status: 404 });
return new Response(object.body);
```

**Use when:** Files >25MB, S3-compatible API needed  
**Limits:** Check object-size, multipart, account, and billing limits.

### Durable Objects: Coordination

```typescript
const id = env.COUNTER.idFromName('global');
const stub = env.COUNTER.get(id);
await stub.fetch(new Request('https://fake/increment'));
```

**Use when:** Strong consistency, real-time coordination, WebSocket state  
**Guarantees:** Single-threaded execution, transactional storage

## Anti-Patterns

**❌ Hardcoding credentials:** `const apiKey = 'sk_live_abc123'`  
**✅** `npx wrangler secret put API_KEY`

**❌ Using REST API:** `fetch('https://api.cloudflare.com/.../kv/...')`  
**✅** `env.MY_KV.get('key')`

**❌ Polling storage:** `setInterval(() => env.KV.get('config'), 1000)`  
**✅** Use Durable Objects for real-time state

**❌ Large data in vars:** `{ "vars": { "HUGE_CONFIG": "..." } }` (5KB max)  
**✅** `env.MY_KV.put('config', data)`

**Derived clients:** Handler injection makes dependencies explicit. Imported module-level env is supported, but cached derived clients need a binding-update/lifetime policy.

## See Also

- [Service Bindings Docs](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/)
- [Miniflare Testing](https://miniflare.dev/)
