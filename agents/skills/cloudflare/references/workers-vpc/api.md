# VPC binding API

Use generated Worker environment types for the configured bindings. Examples
below use the runtime `Fetcher` interface; `await` also handles the VPC Network
connection result described by the [binding API](https://developers.cloudflare.com/workers-vpc/api/).

## HTTP: services and networks

Both expose `fetch(resource, options?)`. Supply an absolute HTTP(S) URL. On a
Service binding the registered host/port wins; the URL host controls Host/SNI.
On a Network binding the URL determines the destination.

```typescript
type Env = { PRIVATE_API: Fetcher };

// Use within the application's authenticated/authorized route.
export async function loadPrivateStatus(env: Env): Promise<Response> {
  try {
    const response = await env.PRIVATE_API.fetch('https://status.internal/health', {
      method: 'GET',
      redirect: 'manual',
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return new Response('Upstream unavailable', { status: 502 });
    return new Response(response.body, { headers: { 'Content-Type': 'application/json' } });
  } catch {
    return new Response('Upstream unavailable', { status: 502 });
  }
}
```

## TCP: networks only

Call `await env.PRIVATE_VPC.connect({ hostname, port })` or pass `"host:port"`.
The result is a Socket with readable/writable streams, opened/closed promises,
and `close()`. VPC Network raw TCP currently supports plaintext only; do not copy
`secureTransport`/StartTLS options from the separate public sockets API.

A VPC Service does not expose raw network `connect()` to application code. Use
Hyperdrive for supported TCP database services. HTTP `fetch()` cannot speak the
PostgreSQL, Redis, or MQTT wire protocols.

See [patterns.md](./patterns.md) for bounded TCP reads and cleanup.
