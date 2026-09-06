# Workers Gotchas

## Common Errors

### "Too much CPU time used"

**Cause:** Worker exceeded CPU time limit (10ms on Free plan, 30s default / 5min max on Paid)  
**Solution:** Profile and reduce active computation, or move suitable work to a service with the required budget. `waitUntil()` does not grant more CPU.

### "Module-Level State Lost"

**Cause:** Workers are stateless between requests; module-level variables reset unpredictably  
**Solution:** Use KV, D1, or Durable Objects for persistent state; don't rely on module-level variables

### "Body has already been used"

**Cause:** Attempting to read response body twice (bodies are streams)  
**Solution:** Clone response before reading: `response.clone()` or read once and create new Response with the text

### "Node.js module not found"

**Cause:** Node.js built-ins not available by default  
**Solution:** Use Workers APIs (e.g., R2 for file storage) or enable Node.js compat with `"compatibility_flags": ["nodejs_compat"]`

### "Cannot fetch in global scope"

**Cause:** Attempting to use fetch during module initialization  
**Solution:** Move fetch calls inside handler functions (fetch, scheduled, etc.) where they're allowed

### "Subrequest depth limit exceeded"

**Cause:** Too many nested subrequests creating deep call chain  
**Solution:** Flatten request chain or use service bindings for direct Worker-to-Worker communication

### "D1 read-after-write inconsistency"

**Cause:** D1 read replicas can lag; read replication is opt-in through Sessions.
**Solution:** Use D1 Sessions (2024+) to guarantee read-after-write consistency within a session:

```typescript
const session = env.DB.withSession();
await session.prepare('INSERT INTO users (name) VALUES (?)').bind('Alice').run();
const user = await session.prepare('SELECT * FROM users WHERE name = ?').bind('Alice').first(); // Guaranteed to see Alice
```

**When to use sessions:** Write → Read patterns, sequentially consistent reads; Sessions do not make separate statements an atomic transaction

### "wrangler types not generating TypeScript definitions"

Use the [generated type setup](./configuration.md#automatic-type-generation-recommended). Wrangler 4 defaults to `worker-configuration.d.ts`.

### "Durable Object RPC method not available"

Extend `DurableObject`, export the class, configure its namespace, and regenerate types. See the [complete RPC pattern](./api.md#durable-objects). HTTP `stub.fetch()` is supported; changing to RPC does not fix missing configuration.

### "WebSocket connection closes unexpectedly"

Inspect close codes, runtime errors, authentication expiry, and network behavior. Hibernation requires `ctx.acceptWebSocket` in a Durable Object; it is not a blanket fix for CPU limits or disconnects. Use the [complete example](../../../durable-objects/SKILL.md).

### "Framework middleware not working with Workers"

**Cause:** Framework expects Node.js primitives (e.g., Express uses Node streams)  
**Solution:** Use Workers-native frameworks (Hono, itty-router, Worktop) or adapt middleware:

```typescript
// ✅ Hono (Workers-native)
import { Hono } from 'hono';
const app = new Hono();
app.use('*', async (c, next) => { /* middleware */ await next(); });
```

See [frameworks.md](./frameworks.md) for full patterns

## Limits

| Limit | Value | Notes |
|-------|-------|-------|
| CPU time | Plan and workload dependent | Check active-compute and wall-time limits separately |
| Request body | Account plan dependent | Do not assume a universal 100 MB cap |
| Storage/binding operations | Product dependent | Check quotas and per-invocation restrictions |

Use the [current platform limits](https://developers.cloudflare.com/workers/platform/limits/) before stating numeric limits.

## See Also

- [Patterns](./patterns.md) - Best practices
- [API](./api.md) - Runtime APIs
- [Configuration](./configuration.md) - Setup
- [Frameworks](./frameworks.md) - Hono, routing, validation
