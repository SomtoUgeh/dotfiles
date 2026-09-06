# Durable Objects Patterns

## When to Use Which Pattern

| Need | Pattern | ID Strategy |
|------|---------|-------------|
| Rate limit per user/IP | Rate Limiting | `idFromName(identifier)` |
| Mutual exclusion | Distributed Lock | `idFromName(resource)` |
| >1K req/s throughput | Sharding | `newUniqueId()` or hash |
| Real-time updates | WebSocket Collab | `idFromName(room)` |
| User sessions | Session Management | `idFromName(sessionId)` |
| Background cleanup | Alarm-based | Any |

## RPC vs fetch()

**RPC** (compat ≥2024-04-03): Type-safe, simpler, default for new projects  
**fetch()**: Legacy compat, HTTP semantics, proxying

```typescript
const count = await stub.increment();  // RPC
const count = await (await stub.fetch(req)).json();  // fetch()
```

## Sharding (High Throughput)

Single DO ~1K req/s max. Shard for higher throughput:

```typescript
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const userId = new URL(req.url).searchParams.get("user");
    if (!userId) return new Response("Missing user", { status: 400 });
    const hash = hashCode(userId) % 100;  // 100 shards
    const id = env.COUNTER.idFromName(`shard:${hash}`);
    return env.COUNTER.get(id).fetch(req);
  }
};

function hashCode(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) hash = ((hash << 5) - hash) + str.charCodeAt(i);
  return Math.abs(hash);
}
```

**Decisions:**
- **Shard count**: 10-1000 typical (start with 100, measure, adjust)
- **Shard key**: User ID, IP, session - must distribute evenly (use hash)
- **Aggregation**: Coordinator DO or external system (D1, R2)

## Rate Limiting

```typescript
async checkLimit(key: string, limit: number, windowMs: number): Promise<boolean> {
  const req = this.ctx.storage.sql.exec<{ count: number }>("SELECT COUNT(*) as count FROM requests WHERE key = ? AND timestamp > ?", key, Date.now() - windowMs).one();
  if (req.count >= limit) return false;
  this.ctx.storage.sql.exec("INSERT INTO requests (key, timestamp) VALUES (?, ?)", key, Date.now());
  return true;
}
```

## Distributed Lock

```typescript
// SQLite-backed DO; stored lease survives eviction.
async acquire(timeoutMs = 5000): Promise<string | null> {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) throw new Error("Invalid lease duration");
  const lease = this.ctx.storage.kv.get<{ owner: string; expiresAt: number }>("lease");
  if (lease && lease.expiresAt > Date.now()) return null;
  const owner = crypto.randomUUID();
  const expiresAt = Date.now() + timeoutMs;
  this.ctx.storage.kv.put("lease", { owner, expiresAt });
  await this.ctx.storage.setAlarm(expiresAt);
  return owner;
}
async release(owner: string): Promise<boolean> {
  const lease = this.ctx.storage.kv.get<{ owner: string; expiresAt: number }>("lease");
  if (!lease || lease.owner !== owner) return false;
  this.ctx.storage.kv.delete("lease");
  await this.ctx.storage.deleteAlarm();
  return true;
}
async alarm() {
  const lease = this.ctx.storage.kv.get<{ owner: string; expiresAt: number }>("lease");
  if (!lease) return;
  if (lease.expiresAt <= Date.now()) this.ctx.storage.kv.delete("lease");
  else await this.ctx.storage.setAlarm(lease.expiresAt);
}
```

This is a lease, not a guarantee that an external task stopped at expiry. External resources need fencing or idempotent operations to reject stale lease holders.

## Hibernation-Aware Pattern

Preserve state across hibernation:

```typescript
async fetch(req: Request): Promise<Response> {
  const [client, server] = Object.values(new WebSocketPair());
  const userId = new URL(req.url).searchParams.get("user");
  if (!userId) return new Response("Missing user", { status: 400 });
  server.serializeAttachment({ userId });  // Survives hibernation
  this.ctx.acceptWebSocket(server, ["room:lobby"]);
  server.send(JSON.stringify({ type: "init", state: this.ctx.storage.kv.get("state") }));
  return new Response(null, { status: 101, webSocket: client });
}

async webSocketMessage(ws: WebSocket, msg: string) {
  const attachment: unknown = ws.deserializeAttachment();  // Retrieve after wake
  if (typeof attachment !== "object" || attachment === null ||
      !("userId" in attachment) || typeof attachment.userId !== "string") {
    ws.close(1008, "Missing user metadata");
    return;
  }
  const state = this.ctx.storage.kv.get<Record<string, unknown>>("state") ?? {};
  state[attachment.userId] = JSON.parse(msg);
  this.ctx.storage.kv.put("state", state);
  for (const c of this.ctx.getWebSockets("room:lobby")) c.send(msg);
}
```

## Real-time Collaboration

Broadcast updates to all connected clients:

```typescript
async webSocketMessage(ws: WebSocket, msg: string) {
  const data = JSON.parse(msg);
  this.ctx.storage.kv.put("doc", data.content);  // Persist
  for (const c of this.ctx.getWebSockets()) if (c !== ws) c.send(msg);  // Broadcast
}
```

### WebSocket Reconnection

**Client-side** (exponential backoff):
```typescript
class ResilientWS {
  private delay = 1000;
  connect(url: string) {
    const ws = new WebSocket(url);
    ws.onclose = () => setTimeout(() => {
      this.connect(url);
      this.delay = Math.min(this.delay * 2, 30000);
    }, this.delay);
  }
}
```

**Server-side** (cleanup on close):
```typescript
async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
  const { userId } = ws.deserializeAttachment();
  this.ctx.storage.sql.exec("UPDATE users SET online = false WHERE id = ?", userId);
  for (const c of this.ctx.getWebSockets()) c.send(JSON.stringify({ type: "user_left", userId }));
}
```

## Session Management

```typescript
async createSession(userId: string, data: object): Promise<string> {
  const id = crypto.randomUUID(), exp = Date.now() + 86400000;
  this.ctx.storage.sql.exec("INSERT INTO sessions VALUES (?, ?, ?, ?)", id, userId, JSON.stringify(data), exp);
  const current = await this.ctx.storage.getAlarm();
  if (current === null || exp < current) await this.ctx.storage.setAlarm(exp);
  return id;
}

async getSession(id: string): Promise<object | null> {
  const row = this.ctx.storage.sql.exec<{ data: string }>("SELECT data FROM sessions WHERE id = ? AND expires_at > ?", id, Date.now()).toArray()[0];
  return row ? JSON.parse(row.data) : null;
}

async alarm() {
  this.ctx.storage.sql.exec("DELETE FROM sessions WHERE expires_at <= ?", Date.now());
  const next = this.ctx.storage.sql.exec<{ expires_at: number | null }>("SELECT MIN(expires_at) AS expires_at FROM sessions").one().expires_at;
  if (next !== null) await this.ctx.storage.setAlarm(next);
}
```

## Multiple Events (Single Alarm)

Queue pattern to schedule multiple events:

```typescript
async scheduleEvent(id: string, runAt: number) {
  await this.ctx.storage.put(`event:${id}`, { id, runAt });
  const curr = await this.ctx.storage.getAlarm();
  if (!curr || runAt < curr) await this.ctx.storage.setAlarm(runAt);
}

async alarm() {
  const events = await this.ctx.storage.list<{ id: string; runAt: number }>({ prefix: "event:" }), now = Date.now();
  for (const [key, ev] of events) {
    if (ev.runAt <= now) {
      await this.processEvent(ev);
      const current = await this.ctx.storage.get<{ id: string; runAt: number }>(key);
      if (current?.runAt === ev.runAt) await this.ctx.storage.delete(key);
    }
  }
  // External processing can admit newly scheduled or rescheduled events.
  const remaining = await this.ctx.storage.list<{ id: string; runAt: number }>({ prefix: "event:" });
  let next: number | null = null;
  for (const ev of remaining.values()) if (next === null || ev.runAt < next) next = ev.runAt;
  if (next !== null) await this.ctx.storage.setAlarm(next);
}
```

`processEvent` must be idempotent: a failure after its side effect can cause the alarm to retry it. Keep failed events stored, preserve reschedules, and recompute the next alarm from current storage.

## Graceful Cleanup

Synchronous SQL cleanup finishes before the method returns:

```typescript
async myMethod() {
  const response = { success: true };
  this.ctx.storage.sql.exec("DELETE FROM old_data WHERE timestamp < ?", cutoff); // SQL is synchronous
  return response;
}
```

## Best Practices

- **Design**: Use `idFromName()` for coordination, `newUniqueId()` for sharding, minimize constructor work
- **Storage**: Prefer SQLite, batch with transactions, set alarms for cleanup, use PITR before risky ops
- **Performance**: ~1K req/s per DO max - shard for more, cache in memory, use alarms for deferred work
- **Reliability**: Handle 503 with retry+backoff, design for cold starts, test migrations with `--dry-run`
- **Security**: Validate inputs in Workers, rate limit DO creation, use jurisdiction for compliance

## See Also

- **[API](./api.md)** - ctx methods, WebSocket handlers
- **[Gotchas](./gotchas.md)** - Hibernation caveats, common errors
- **[DO Storage](../do-storage/README.md)** - Storage patterns and transactions
