# Playground runtime API examples

These are handler fragments unless a complete module is shown. Supply the named
values from the surrounding application; use [patterns.md](./patterns.md) for
runnable examples.

## Request bodies

Clone before consuming a body if two readers are actually needed:

```javascript
const copy = request.clone();
const body = await request.json();
const sameBody = await copy.json();
```

Prefer one read when possible. Handle malformed JSON and validate its shape.
Request metadata can be absent in local/constructed requests: use
`request.cf?.country` or `request.cf?.colo`.

## Responses

```javascript
const json = Response.json({ ok: true });
const redirect = Response.redirect(new URL('/new-path', request.url), 302);
const modified = new Response(response.body, response);
modified.headers.set('X-Example', 'value');
```

A redirect requires an absolute URL. Clone response metadata into a mutable
Response before changing headers.

## Background work

```javascript
ctx.waitUntil(sendApplicationMetric());
return new Response('OK');
```

`sendApplicationMetric` is an existing application function. `waitUntil` extends
lifetime for asynchronous work; it does not remove CPU/subrequest limits or make
CPU-heavy computation run on a separate thread.

## Other APIs

Standard `fetch`, Streams, `crypto.randomUUID`, and Web Crypto are available.
Use `await crypto.subtle.digest('SHA-256', bytes)` for hashing. Cache API operations
in Playground previews have no effect, so a preview cannot verify a cache hit.

Sources: [runtime APIs](https://developers.cloudflare.com/workers/runtime-apis/),
[Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/).
