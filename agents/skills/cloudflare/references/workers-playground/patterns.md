# Playground examples

## JSON endpoint with input errors

```javascript
export default {
  async fetch(request) {
    const path = new URL(request.url).pathname;
    if (path === '/api/hello' && request.method === 'GET') {
      return Response.json({ message: 'Hello' });
    }
    if (path !== '/api/echo') return new Response('Not found', { status: 404 });
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'POST' } });
    }
    let body;
    try { body = await request.json(); } catch {
      return Response.json({ error: 'Invalid JSON' }, { status: 400 });
    }
    if (!body || typeof body !== 'object' || typeof body.message !== 'string') {
      return Response.json({ error: 'message must be a string' }, { status: 400 });
    }
    return Response.json({ received: body.message });
  }
};
```

## Small route table

Use a Map so paths cannot accidentally select inherited object properties:

```javascript
const routes = new Map([
  ['/', () => new Response('Home')],
  ['/api/users', () => Response.json([{ id: 1, name: 'Alice' }])],
]);

export default {
  fetch(request) {
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET' } });
    }
    const handler = routes.get(new URL(request.url).pathname);
    return handler ? handler() : new Response('Not found', { status: 404 });
  }
};
```

## Fixed upstream

For a real proxy, set the complete trusted origin, allow only the intended paths
and methods, choose which headers may leave the Worker, and handle upstream errors
and redirects. Do not forward arbitrary caller Authorization/cookies or expose
an unrestricted proxy merely to demonstrate `fetch`.

```javascript
export default {
  async fetch(request) {
    if (request.method !== 'GET') return new Response('Method not allowed', { status: 405 });
    try {
      const upstream = await fetch('https://example.com/', {
        redirect: 'manual', signal: AbortSignal.timeout(5000),
      });
      if (!upstream.ok) return new Response('Upstream unavailable', { status: 502 });
      const response = new Response(upstream.body, upstream);
      response.headers.set('X-Example', 'playground');
      return response;
    } catch {
      return new Response('Upstream unavailable', { status: 502 });
    }
  }
};
```

## Frameworks, CORS, authentication, and caching

Build Hono or other npm dependencies in a local project, then use the resulting
modules where supported; a bare CDN URL is not a reproducible dependency setup.
Configure CORS for the actual endpoint and browser origins. CORS does not
authorize requests. Real authentication requires a server secret/binding and a
verified token/session; hardcoded Playground strings are not an auth example.

For caching, verify cache eligibility and exclude personalized requests/responses.
The Playground's Cache API is a no-op; use a local/runtime or scoped deployment
fixture for cache behavior. In-memory state is temporary and cannot substitute
for shared durable state.
