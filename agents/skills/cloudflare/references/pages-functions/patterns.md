# Common Patterns

## Background Tasks (waitUntil)

```typescript
interface Env { KV: KVNamespace; ANALYTICS: AnalyticsEngineDataset; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  ctx.env.ANALYTICS.writeDataPoint({ blobs: ['view'], doubles: [1] });
  ctx.waitUntil(ctx.env.KV.put('last-visit', new Date().toISOString()));
  return Response.json({ success: true });
};
```

`writeDataPoint` returns void and uses the declared blobs/doubles/indexes fields. `waitUntil` extends limited request lifetime; use Queues or Workflows for durable jobs.

## Middleware & Auth

```typescript
// functions/_middleware.js (global) or functions/users/_middleware.js (scoped)
export async function onRequest(ctx) {
  try { return await ctx.next(); }
  catch (err) { console.error(err); return new Response('Internal server error', { status: 500 }); }
}

// Chained: export const onRequest = [errorHandler, auth, logger];

// Auth
async function auth(ctx: EventContext<Env, string, Record<string, unknown>>) {
  const header = ctx.request.headers.get('authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  if (!token) return new Response('Unauthorized', { status: 401 });
  const session = await ctx.env.KV.get(`session:${token}`);
  if (!session) return new Response('Invalid', { status: 401 });
  ctx.data.user = JSON.parse(session);
  return ctx.next();
}
```

## CORS & Rate Limiting

```typescript
// CORS middleware
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST' };
export async function onRequestOptions() { return new Response(null, { headers: cors }); }
export async function onRequest(ctx) {
  const upstream = await ctx.next();
  const res = new Response(upstream.body, upstream);
  Object.entries(cors).forEach(([k, v]) => res.headers.set(k, v));
  return res;
}

```

For enforcement, use a separately deployed Worker with a rate-limiting binding or a Durable Object, accessed through a Pages service/DO binding. KV read-modify-write is eventually consistent, races across requests, and has per-key write limits; it is unsuitable for enforcing counters.

## Forms, Caching, Redirects

```typescript
// JSON & file upload
export async function onRequestPost(ctx) {
  const ct = ctx.request.headers.get('content-type') || '';
  if (ct.includes('application/json')) return Response.json(await ctx.request.json());
  if (ct.includes('multipart/form-data')) {
    const file = (await ctx.request.formData()).get('file');
    if (!(file instanceof File)) return new Response('File required', { status: 400 });
    if (file.size > 10 * 1024 * 1024) return new Response('File too large', { status: 413 });
    const key = crypto.randomUUID(); // Do not trust a supplied filename as the storage key.
    await ctx.env.BUCKET.put(key, file.stream());
    return Response.json({ uploaded: key });
  }
  return new Response('Unsupported media type', { status: 415 });
}

// Cache API
export async function onRequest(ctx) {
  if (ctx.request.method !== 'GET') return ctx.next();
  let res = await caches.default.match(ctx.request);
  if (!res) {
    res = new Response('Data');
    res.headers.set('Cache-Control', 'public, max-age=3600');
    ctx.waitUntil(caches.default.put(ctx.request, res.clone()));
  }
  return res;
}

// Redirects
export async function onRequest(ctx) {
  if (new URL(ctx.request.url).pathname === '/old') {
    return Response.redirect(new URL('/new', ctx.request.url), 301);
  }
  return ctx.next();
}
```

## Testing

Use `wrangler pages dev` for routing/middleware integration tests. For unit tests, extract pure logic or supply a complete typed Pages context; an assertion on a partial object hides missing `next`, `waitUntil`, and error-fallback methods. The Workers Vitest runtime is useful for bindings, but does not itself prove Pages file routing.

## Advanced Mode (_worker.js)

Use `_worker.js` for complex routing (replaces `/functions`):

```typescript
interface Env { ASSETS: Fetcher; KV: KVNamespace; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      return Response.json({ data: await env.KV.get('key') });
    }
    return env.ASSETS.fetch(request); // Static files
  }
} satisfies ExportedHandler<Env>;
```

**When:** Existing Worker, framework-generated when the selected adapter targets Pages, custom routing logic

**See also:** [api.md](./api.md) for `env.ASSETS.fetch()` | [gotchas.md](./gotchas.md) for debugging
