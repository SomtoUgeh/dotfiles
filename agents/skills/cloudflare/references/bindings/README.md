# Cloudflare Bindings Skill Reference

Expert guidance on Cloudflare Workers Bindings - the runtime APIs that connect Workers to Cloudflare platform resources.

## What Are Bindings?

Bindings are how Workers access Cloudflare resources (storage, compute, services) via the `env` object. They're configured in `wrangler.jsonc`, type-safe via TypeScript, and available without embedding Cloudflare API credentials.

## Reading Order

Load the reference for the current task:

- Select a binding: use the catalog below.
- Add or change a binding: [configuration.md](configuration.md).
- Access bindings or generate types: [api.md](api.md).
- Design service calls, tests, or storage access: [patterns.md](patterns.md).
- Diagnose a failure: [gotchas.md](gotchas.md).

Follow product-specific links only for the selected binding.

## Binding Catalog

### Storage Bindings

| Binding | Use Case | Access Pattern |
|---------|----------|----------------|
| **KV** | Key-value cache, CDN-backed reads | `env.MY_KV.get(key)` |
| **R2** | Object storage (S3-compatible) | `env.MY_BUCKET.get(key)` |
| **D1** | SQL database (SQLite) | `env.DB.prepare(sql).all()` |
| **Durable Objects** | Coordination, real-time state | `env.MY_DO.get(id)` |
| **Vectorize** | Vector embeddings search | `env.VECTORIZE.query(vector)` |
| **Queues** | Async message processing | `env.MY_QUEUE.send(msg)` |

### Compute Bindings

| Binding | Use Case | Access Pattern |
|---------|----------|----------------|
| **Service** | Worker-to-Worker RPC | `env.MY_SERVICE.fetch(req)` |
| **Workers AI** | LLM inference | `env.AI.run(model, input)` |
| **Browser Rendering** | Headless Chrome | `puppeteer.launch(env.BROWSER)` |

### Platform Bindings

| Binding | Use Case | Access Pattern |
|---------|----------|----------------|
| **Analytics Engine** | Custom metrics | `env.ANALYTICS.writeDataPoint(data)` |
| **mTLS** | Client certificates | `env.MY_CERT.fetch(request)` |
| **Hyperdrive** | Database pooling | `env.HYPERDRIVE.connectionString` |
| **Rate Limiting** | Request throttling | `env.RATE_LIMITER.limit({ key: id })` |
| **Workflows** | Long-running workflows | `env.MY_WORKFLOW.create()` |

### Configuration Bindings

| Binding | Use Case | Access Pattern |
|---------|----------|----------------|
| **Environment Variables** | Non-sensitive config | `env.API_URL` (string) |
| **Secrets** | Sensitive values | `env.API_KEY` (string) |
| **Text/Data Blobs** | Static files | `env.MY_BLOB` (string) |
| **WASM** | WebAssembly modules | `env.MY_WASM` (WebAssembly.Module) |

## Quick Selection Guide

**Need persistent storage?**
- Key-value < 25MB → **KV**
- Files/objects → **R2**
- Relational data → **D1**
- Real-time coordination → **Durable Objects**

**Need AI/compute?**
- LLM inference → **Workers AI**
- Scraping/PDFs → **Browser Rendering**
- Call another Worker → **Service binding**

**Need async processing?**
- Background jobs → **Queues**

**Need config?**
- Public values → **Environment Variables**
- Secrets → **Secrets** (never commit)

## Quick Start

1. **Add binding to wrangler.jsonc:**
```jsonc
{
  "kv_namespaces": [
    { "binding": "MY_KV", "id": "your-kv-id" }
  ]
}
```

2. **Generate types:**
```bash
npx wrangler types
```

3. **Access in Worker:**
```typescript
export default {
  async fetch(request, env, ctx) {
    await env.MY_KV.put('key', 'value');
    return new Response('OK');
  }
}
```

## Type Safety

Bindings are fully typed via `wrangler types`. See [api.md](api.md) for details.

## Limits

- Limits differ by binding type and account plan; check the current platform limits.
- See [gotchas.md](gotchas.md) for per-binding limits

## Key Concepts

**Capability access:** Bindings avoid manual API credentials; storage and service operations still have latency, quotas, and possible charges.
**Type-safe:** Full TypeScript support via `wrangler types`
**Per-environment:** Different IDs for dev/staging/production
**Secrets vs Vars:** Secrets encrypted at rest, never in config files

## See Also

- [Cloudflare Docs: Bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/)
- [Wrangler Configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
