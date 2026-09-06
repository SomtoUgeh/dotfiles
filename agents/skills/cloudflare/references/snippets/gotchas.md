# Gotchas & Best Practices

## Common Errors

### 1206: "Snippet threw exception"
Runtime error or syntax error. Wrap code in try/catch:
```javascript
try { return await fetch(request); }
catch (error) { return new Response("Upstream request failed", { status: 502 }); }
```

### 1203: "Exceeded CPU time limit"
Code takes >5ms CPU. Simplify logic or move to Workers.

### 1201: "Multiple origin fetches"
Call `fetch(request)` exactly once:
```javascript
// ❌ Multiple origin fetches
const r1 = await fetch(request); const r2 = await fetch(request);
// ✅ Single fetch, reuse response
const response = await fetch(request);
```

### 1202: "Subrequest limit exceeded"
Pro: 2, Business: 3, Enterprise: 5 subrequests (including redirect hops). Reduce fetch calls.

### "Cannot set property on immutable object"
Clone before modifying:
```javascript
const modifiedRequest = new Request(request);
modifiedRequest.headers.set("X-Custom", "value");
```

### Cache behavior
Snippets support the Cache API; use the documented custom-cache pattern and respect method/cacheability constraints.

### "Module not found"
Ensure referenced files are uploaded and compatible code is bundled within the package limit; Node.js built-ins are not supported.

## Best Practices

### Performance
- Keep code <10KB (32KB limit)
- Optimize for 5ms CPU
- Clone only when modifying
- Minimize subrequests

### Security
- Validate all inputs
- Use Web Crypto API for hashing
- Sanitize headers before origin
- Don't log secrets

### Debugging
```javascript
newResponse.headers.set("X-Debug-Country", request.cf.country);
```
```bash
curl -H "X-Test: true" https://example.com -v
```

## Available APIs

**✅ Available:** `fetch()`, `Request`, `Response`, `Headers`, `URL`, `crypto.subtle`, `crypto.randomUUID()`, `atob()`/`btoa()`, `JSON`

**Not Worker bindings:** `KV`, `D1`, `R2`, Durable Objects. Use Workers when you need these. Snippets support Cache API and HTMLRewriter; do not infer an entire Workers API surface.

## Limits

| Resource | Limit |
|----------|-------|
| Snippet size | 32KB |
| Execution time | 5ms CPU |
| Subrequests (Pro/Business/Enterprise) | 2/3/5 |
| Snippets/zone (Pro/Business/Enterprise) | 25/50/300 |

## Runtime Checks

Do not use made-up operation timings: network fetch wall time is not CPU time. The limits are 5 ms CPU, 2 MB memory, and 32 KB total package size. Error 1204 indicates memory exhaustion; 1205 indicates deployment propagation. Test CPU/memory and supported APIs on a staging zone.

**Migrate to Workers when:** >5ms needed, >5 subrequests, need storage (KV/D1/R2), need npm packages, >32KB code

[Current Snippets availability and limits](https://developers.cloudflare.com/rules/snippets/) · [Cache example](https://developers.cloudflare.com/rules/snippets/examples/custom-cache/) · [HTMLRewriter example](https://developers.cloudflare.com/rules/snippets/examples/rewrite-site-links/)
