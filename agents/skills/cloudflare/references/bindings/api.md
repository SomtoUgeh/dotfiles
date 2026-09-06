# Bindings API Reference

## TypeScript Types

Cloudflare generates binding types via `npx wrangler types`. This creates `worker-configuration.d.ts` with your Env interface.

### Generated Env Interface

After running `wrangler types`, TypeScript knows your bindings:

```typescript
interface Env {
  // From wrangler.jsonc bindings
  MY_KV: KVNamespace;
  MY_BUCKET: R2Bucket;
  DB: D1Database;
  MY_SERVICE: Fetcher;
  AI: Ai;
  
  // From vars
  API_URL: string;
  
  // From secrets (set via wrangler secret put)
  API_KEY: string;
}
```

### Binding Types

| Config | TypeScript Type | Package |
|--------|-----------------|---------|
| `kv_namespaces` | `KVNamespace` | `@cloudflare/workers-types` |
| `r2_buckets` | `R2Bucket` | `@cloudflare/workers-types` |
| `d1_databases` | `D1Database` | `@cloudflare/workers-types` |
| `durable_objects.bindings` | `DurableObjectNamespace` | `@cloudflare/workers-types` |
| `vectorize` | `VectorizeIndex` | `@cloudflare/workers-types` |
| `queues.producers` | `Queue` | `@cloudflare/workers-types` |
| `services` | `Fetcher` | `@cloudflare/workers-types` |
| `ai` | `Ai` | `@cloudflare/workers-types` |
| `browser` | `Fetcher` | `@cloudflare/workers-types` |
| `analytics_engine_datasets` | `AnalyticsEngineDataset` | `@cloudflare/workers-types` |
| `hyperdrive` | `Hyperdrive` | `@cloudflare/workers-types` |
| `rate_limiting` | `RateLimit` | `@cloudflare/workers-types` |
| `workflows` | `Workflow` | `@cloudflare/workers-types` |
| `mtls_certificates` | `Fetcher` | Built-in |
| `vars` / `text_blobs` / `data_blobs` | JSON value / `string` / `ArrayBuffer` | Built-in |
| `wasm_modules` | `WebAssembly.Module` | Built-in |

## Accessing Bindings

### Method 1: fetch() Handler (Recommended)

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const value = await env.MY_KV.get('key');
    return new Response(value);
  }
}
```

**Why:** Type-safe, aligns with Workers API, supports ctx for waitUntil/passThroughOnException.

### Method 2: Hono Framework

```typescript
import { Hono } from 'hono';

const app = new Hono<{ Bindings: Env }>();

app.get('/', async (c) => {
  const value = await c.env.MY_KV.get('key');
  return c.json({ value });
});

export default app;
```

**Why:** c.env auto-typed, ergonomic for routing-heavy apps.

### Module-level env access

Modern Workers can import `env` from `cloudflare:workers`. Request-handler injection is convenient for testing, but module-scope access is not universally unavailable. Do not start I/O during module initialization or cache derived clients without considering binding changes and request lifetime.

## Type Generation Workflow

### Initial Setup

```bash
# Install wrangler
npm install -D wrangler

# Generate types from wrangler.jsonc
npx wrangler types
```

### After Changing Bindings

```bash
# Added/modified binding in wrangler.jsonc
npx wrangler types

# TypeScript now sees updated Env interface
```

**Note:** `wrangler types` outputs to `worker-configuration.d.ts`. Include the generated file in tsconfig. It contains runtime declarations too; do not load duplicate declarations from `@cloudflare/workers-types`.

## Key Binding Methods

**KV:**
```typescript
await env.MY_KV.get(key, { type: 'json' });  // text|json|arrayBuffer|stream
await env.MY_KV.put(key, value, { expirationTtl: 3600 });
await env.MY_KV.delete(key);
await env.MY_KV.list({ prefix: 'user:' });
```

**R2:**
```typescript
await env.BUCKET.get(key);
await env.BUCKET.put(key, value);
await env.BUCKET.delete(key);
await env.BUCKET.list({ prefix: 'images/' });
```

**D1:**
```typescript
await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
await env.DB.batch([stmt1, stmt2]);
```

**Service:**
```typescript
await env.MY_SERVICE.fetch(new Request('https://fake/path'));
```

**Workers AI:**
```typescript
await env.AI.run('@cf/meta/llama-3.1-8b-instruct-fp8', { prompt: 'Hello' });
```

**Queues:**
```typescript
await env.MY_QUEUE.send({ userId: 123, action: 'process' });
```

**Durable Objects:**
```typescript
const id = env.MY_DO.idFromName('user-123');
const stub = env.MY_DO.get(id);
await stub.fetch(new Request('https://fake/increment'));
```

## Runtime types

Prefer the project's `wrangler types` output, which reflects its compatibility settings and bindings. `@cloudflare/workers-types` is an alternative declaration source when the project needs it, not an additional required runtime library. Secret types depend on the local declarations/configuration used by generation; setting a remote secret does not automatically fetch its value or infer every local type.

## Type Safety Best Practices

1. **Never use `any` for env:**
```typescript
// ❌ BAD
async fetch(request: Request, env: any) { }

// ✅ GOOD
async fetch(request: Request, env: Env) { }
```

2. **Run wrangler types after config changes:**
```bash
# After editing wrangler.jsonc
npx wrangler types
```

3. **Check generated types match config:**
```bash
# View generated Env interface
cat worker-configuration.d.ts
```

## See Also

- [Workers Types Package](https://www.npmjs.com/package/@cloudflare/workers-types)
- [Wrangler Types Command](https://developers.cloudflare.com/workers/wrangler/commands/#types)
