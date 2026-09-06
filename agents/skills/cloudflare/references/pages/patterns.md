# Patterns

## API Routes

```typescript
// functions/api/todos/[id].ts
export const onRequestGet: PagesFunction<Env> = async ({ env, params }) => {
  const todo = await env.DB.prepare('SELECT * FROM todos WHERE id = ?').bind(params.id).first();
  if (!todo) return new Response('Not found', { status: 404 });
  return Response.json(todo);
};

export const onRequestPut: PagesFunction<Env> = async ({ env, params, request }) => {
  const body = await request.json();
  await env.DB.prepare('UPDATE todos SET title = ?, completed = ? WHERE id = ?')
    .bind(body.title, body.completed, params.id).run();
  return Response.json({ success: true });
};
// Also: onRequestDelete, onRequestPost
```

## Auth Middleware

```typescript
// functions/_middleware.ts
const auth: PagesFunction<Env> = async (context) => {
  const pathname = new URL(context.request.url).pathname;
  if (pathname === '/public' || pathname.startsWith('/public/')) return context.next();
  const authHeader = context.request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const payload = await verifyJWT(authHeader.substring(7), context.env.JWT_SECRET);
    context.data.user = payload;
    return context.next();
  } catch (err) {
    return new Response('Invalid token', { status: 401 });
  }
};
export const onRequest = [auth];
```

## CORS

```typescript
// functions/api/_middleware.ts
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
};

export const onRequest: PagesFunction = async (context) => {
  if (context.request.method === 'OPTIONS') {
    return new Response(null, {headers: corsHeaders});
  }
  const upstream = await context.next();
  const response = new Response(upstream.body, upstream);
  Object.entries(corsHeaders).forEach(([k, v]) => response.headers.set(k, v));
  return response;
};
```

## Form Handling

Validate required fields and await the Queue send before confirming submission. Current Wrangler supports Queue producer bindings on Pages; Queue consumers must be separate Workers.

```typescript
interface FormEnv { QUEUE: Queue<{ name: string; email: string }>; }
export const onRequestPost: PagesFunction<FormEnv> = async ({ request, env }) => {
  const form = await request.formData();
  const name = form.get('name');
  const email = form.get('email');
  if (typeof name !== 'string' || typeof email !== 'string' || !name || !email) {
    return new Response('Name and email required', { status: 400 });
  }
  await env.QUEUE.send({ name, email });
  return new Response('Thanks!');
};
```

## Background Tasks

```typescript
export const onRequestPost: PagesFunction = async ({ request, waitUntil }) => {
  const data = await request.json();
  waitUntil(fetch('https://api.example.com/webhook', {
    method: 'POST', body: JSON.stringify(data)
  }));
  return Response.json({ queued: true });
};
```

## Error Handling

```typescript
// functions/_middleware.ts
const errorHandler: PagesFunction = async (context) => {
  try {
    return await context.next();
  } catch (error) {
    console.error('Error:', error);
    if (new URL(context.request.url).pathname.startsWith('/api/')) {
      return Response.json({ error: 'Internal server error' }, { status: 500 });
    }
    return new Response('<h1>Internal server error</h1>', {
      status: 500, headers: { 'Content-Type': 'text/html' }
    });
  }
};
export const onRequest = [errorHandler];
```

## Caching

```typescript
// functions/api/data.ts
export const onRequestGet: PagesFunction<Env> = async ({ env, request }) => {
  const cacheKey = `data:${new URL(request.url).pathname}`;
  const cached = await env.KV.get(cacheKey, 'json');
  if (cached) return Response.json(cached, { headers: { 'X-Cache': 'HIT' } });

  const data = await env.DB.prepare('SELECT * FROM data').first();
  await env.KV.put(cacheKey, JSON.stringify(data), {expirationTtl: 3600});
  return Response.json(data, {headers: {'X-Cache': 'MISS'}});
};
```

## Smart Placement for Database Apps

Enable Smart Placement for apps with D1 or centralized data sources:

```jsonc
// wrangler.jsonc
{
  "name": "global-app",
  "placement": {
    "mode": "smart"
  },
  "d1_databases": [{
    "binding": "DB",
    "database_id": "your-db-id"
  }]
}
```

```typescript
// functions/api/data.ts
export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  // Smart Placement optimizes execution location over time
  // Balances user location vs database location
  const data = await env.DB.prepare('SELECT * FROM products LIMIT 10').all();
  return Response.json(data);
};
```

**Best for**: Read-heavy apps with D1/Durable Objects in specific regions.
**Measure first**: User distribution alone does not predict benefit; backend latency matters.

## Framework Integration

Follow [current Cloudflare framework guides](https://developers.cloudflare.com/workers/framework-guides/) for the installed adapter and chosen Pages/Workers target. For existing Pages projects, preserve working adapters and update binding access based on their actual version. Next.js and React Router have supported Workers deployment guides; an old Pages adapter's deprecation does not require a framework migration.

## Monorepo

Dashboard → Settings → Build → Root directory. Set to subproject (e.g., `apps/web`).

## Best Practices

**Performance**: Exclude static via `_routes.json`; cache with KV; measure bundle/startup cost
**Security**: Use secrets (not vars); validate inputs; enforce rate limits with a DO or rate-limiting Worker, not KV read-modify-write
**Workflow**: Preview per branch; local dev with `wrangler pages dev`; instant rollbacks in Dashboard
