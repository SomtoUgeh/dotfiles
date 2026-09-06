# Workers Runtime APIs

## Fetch Handler

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/api') {
      const body = await request.json();
      return new Response(JSON.stringify({ id: 1 }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    return new Response('Not found', { status: 404 });
  },
};
```

## Execution Context

```typescript
ctx.waitUntil(logAnalytics(request));  // Background work, don't block response
// Use passThroughOnException only when the route has an origin and fail-open is intended.
```

Await operations required for the response. Use `ctx.waitUntil()` for optional completion after returning; it does not increase CPU limits.

## Bindings

```typescript
// KV
await env.MY_KV.get('key');
await env.MY_KV.put('key', 'value', { expirationTtl: 3600 });

// R2
const obj = await env.MY_BUCKET.get('file.txt');
await env.MY_BUCKET.put('file.txt', 'content');

// D1
const result = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(1).first();

// D1 Sessions (2024+) - read-after-write consistency
const session = env.DB.withSession();
await session.prepare('INSERT INTO users (name) VALUES (?)').bind('Alice').run();
const user = await session.prepare('SELECT * FROM users WHERE name = ?').bind('Alice').first(); // Guaranteed fresh

// Queues
await env.MY_QUEUE.send({ timestamp: Date.now() });

// Secrets/vars
const key = env.API_KEY;
```

## Cache API

```typescript
// Only for an explicitly public, identical-for-all-users GET route.
if (request.method !== 'GET' || request.headers.has('Authorization') || request.headers.has('Cookie')) {
  return handleRequest(request, env);
}
const cache = caches.default;
let response = await cache.match(request);
if (!response) {
  response = await handleRequest(request, env);
  if (response.ok && !response.headers.has('Set-Cookie')) {
    response = new Response(response.body, response);
    response.headers.set('Cache-Control', 'public, max-age=3600');
    ctx.waitUntil(cache.put(request, response.clone()));
  }
}
return response;
```

## HTMLRewriter

```typescript
return new HTMLRewriter()
  .on('a[href]', {
    element(el) {
      const href = el.getAttribute('href');
      if (href?.startsWith('http://')) {
        el.setAttribute('href', href.replace('http://', 'https://'));
      }
    }
  })
  .transform(response);
```

**Use cases**: A/B testing, analytics injection, link rewriting

## WebSockets

### Standard WebSocket

```typescript
const [client, server] = Object.values(new WebSocketPair());

server.accept();
server.addEventListener('message', event => {
  server.send(`Echo: ${event.data}`);
});

return new Response(null, { status: 101, webSocket: client });
```

### WebSocket Hibernation (Recommended for idle connections)

Use the complete [Durable Object WebSocket example](../../../durable-objects/SKILL.md). The class must extend `DurableObject` and accept the server socket with `ctx.acceptWebSocket`; declaring event methods alone does not enable hibernation.

## Durable Objects

### RPC Pattern (Recommended 2024+)

```typescript
import { DurableObject } from 'cloudflare:workers';
  
export class Counter extends DurableObject<Env> {
  async increment(): Promise<number> {
    return this.ctx.storage.transaction(async (tx) => {
      const next = (await tx.get<number>('value') ?? 0) + 1;
      await tx.put('value', next);
      return next;
    });
  }
  async getValue(): Promise<number> {
    return await this.ctx.storage.get<number>('value') ?? 0;
  }
}
const stub = env.COUNTER.getByName('global');
const count = await stub.increment();
```

Configure the exported class and generate namespace types before using RPC. HTTP `stub.fetch()` remains supported for HTTP/WebSocket interfaces. RPC serializes arguments and results; it does not provide zero serialization or zero latency.

**When to use DOs**: Real-time collaboration, rate limiting, strongly consistent state

## Other Handlers

```typescript
// Cron: async scheduled(event, env, ctx) { ctx.waitUntil(doCleanup(env)); }
// Queue: async queue(batch) { for (const msg of batch.messages) { await process(msg.body); msg.ack(); } }
// Tail: async tail(events, env) { for (const e of events) if (e.outcome === 'exception') await log(e); }
```

## Service Bindings

```typescript
// Worker-to-worker HTTP through a service binding
return env.SERVICE_B.fetch(request);

// With RPC (2024+) - same as Durable Objects RPC
import { WorkerEntrypoint } from 'cloudflare:workers';
export class ServiceWorker extends WorkerEntrypoint<Env> {
  async getData() { return { data: 'value' }; }
}
// Usage: const data = await env.SERVICE_B.getData();
```

**Benefits**: Type-safe method calls, no HTTP overhead, share code between Workers

## See Also

- [Configuration](./configuration.md) - Binding setup
- [Patterns](./patterns.md) - Common workflows
- [KV](../kv/README.md), [D1](../d1/README.md), [R2](../r2/README.md), [Durable Objects](../durable-objects/README.md), [Queues](../queues/README.md)
