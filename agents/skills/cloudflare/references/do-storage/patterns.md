# DO Storage Patterns & Best Practices

## Schema Migration

**Note:** `PRAGMA user_version` is **not supported** in Durable Objects SQLite storage. Use a `_sql_schema_migrations` table instead:

```typescript
import { DurableObject } from "cloudflare:workers";

export class MyDurableObject extends DurableObject<Env> {
  sql: SqlStorage;
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;

    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS _sql_schema_migrations (
        id INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `);

    const ver = this.sql
      .exec<{ version: number }>("SELECT COALESCE(MAX(id), 0) as version FROM _sql_schema_migrations")
      .one().version;

    if (ver < 1) {
      this.sql.exec(`CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT)`);
      this.sql.exec("INSERT INTO _sql_schema_migrations (id) VALUES (1)");
    }
    if (ver < 2) {
      this.sql.exec(`ALTER TABLE users ADD COLUMN email TEXT`);
      this.sql.exec("INSERT INTO _sql_schema_migrations (id) VALUES (2)");
    }
  }
}
```

For production apps, consider [`durable-utils`](https://github.com/lambrospetrou/durable-utils#sqlite-schema-migrations) — provides a `SQLSchemaMigrations` class that tracks executed migrations both in memory and in storage. Also see [`@cloudflare/actors` storage utilities](https://github.com/cloudflare/actors/blob/main/packages/storage/src/sql-schema-migrations.ts) — a reference implementation of the same pattern used by the Cloudflare Actors framework.

## In-Memory Caching

```typescript
import { DurableObject } from "cloudflare:workers";

interface User { name: string; email: string }

export class UserCache extends DurableObject<Env> {
  cache = new Map<string, User>();
  async getUser(id: string): Promise<User | undefined> {
    if (this.cache.has(id)) {
      const cached = this.cache.get(id);
      if (cached) return cached;
    }
    const user = await this.ctx.storage.get<User>(`user:${id}`);
    if (user) this.cache.set(id, user);
    return user;
  }
  async updateUser(id: string, data: Partial<User>) {
    const user = await this.getUser(id);
    if (!user) throw new Error("User not found");
    const updated = { ...user, ...data };
    await this.ctx.storage.put(`user:${id}`, updated);
    this.cache.set(id, updated);
    return updated;
  }
}
```

## Rate Limiting

```typescript
import { DurableObject } from "cloudflare:workers";

export class RateLimiter extends DurableObject<Env> {
  sql: SqlStorage;
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS requests (key TEXT NOT NULL, timestamp INTEGER NOT NULL)");
    this.sql.exec("CREATE INDEX IF NOT EXISTS requests_key_time ON requests(key, timestamp)");
  }
  async checkLimit(key: string, limit: number, window: number): Promise<boolean> {
    if (!Number.isSafeInteger(limit) || limit < 1 || !Number.isSafeInteger(window) || window < 1) {
      throw new RangeError("limit and window must be positive safe integers");
    }
    const now = Date.now();
    this.sql.exec('DELETE FROM requests WHERE key = ? AND timestamp <= ?', key, now - window);
    const count = this.sql.exec<{ count: number }>('SELECT COUNT(*) as count FROM requests WHERE key = ?', key).one().count;
    if (count >= limit) return false;
    this.sql.exec('INSERT INTO requests (key, timestamp) VALUES (?, ?)', key, now);
    return true;
  }
}
```

## Batch Processing with Alarms

```typescript
import { DurableObject } from "cloudflare:workers";

export class BatchProcessor extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS pending_items (id INTEGER PRIMARY KEY AUTOINCREMENT, item TEXT);
      CREATE TABLE IF NOT EXISTS processed_items (item TEXT, timestamp INTEGER);`);
  }
  async addItem(item: string) {
    this.ctx.storage.sql.exec("INSERT INTO pending_items(item) VALUES (?)", item);
    if (await this.ctx.storage.getAlarm() === null) {
      await this.ctx.storage.setAlarm(Date.now() + 5000);
    }
  }
  async alarm() {
    this.ctx.storage.transactionSync(() => {
      this.ctx.storage.sql.exec("INSERT INTO processed_items SELECT item, ? FROM pending_items", Date.now());
      this.ctx.storage.sql.exec("DELETE FROM pending_items");
    });
  }
}
```

## Initialization Pattern

```typescript
import { DurableObject } from "cloudflare:workers";

export class Counter extends DurableObject<Env> {
  value = 0;
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => { this.value = (await ctx.storage.get<number>("value")) ?? 0; });
  }
  async increment() {
    this.value++;
    this.ctx.storage.put("value", this.value); // Don't await (output gate protects)
    return this.value;
  }
}
```

## Safe Counter / Optimized Write

```typescript
// Input gate blocks other requests
async getUniqueNumber(): Promise<number> {
  const val = (await this.ctx.storage.get<number>("counter")) ?? 0;
  await this.ctx.storage.put("counter", val + 1);
  return val;
}

// No await on write - output gate delays response until write confirms
async increment(): Promise<Response> {
  const val = (await this.ctx.storage.get<number>("counter")) ?? 0;
  this.ctx.storage.put("counter", val + 1);
  return new Response(String(val));
}
```

## Parent-Child Coordination

Hierarchical DO pattern where parent manages child DOs:

```typescript
import { DurableObject } from "cloudflare:workers";

interface Env { DOCUMENT: DurableObjectNamespace<Document> }

// Parent DO coordinates children
export class Workspace extends DurableObject<Env> {
  sql: SqlStorage;
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS documents (id TEXT PRIMARY KEY, name TEXT NOT NULL, created INTEGER NOT NULL)");
  }
  async createDocument(name: string): Promise<string> {
    const docId = crypto.randomUUID();
    const childId = this.env.DOCUMENT.idFromName(`${this.ctx.id.toString()}:${docId}`);
    const childStub = this.env.DOCUMENT.get(childId);
    await childStub.initialize(name);
    
    // Track child in parent storage
    this.sql.exec('INSERT INTO documents (id, name, created) VALUES (?, ?, ?)', 
      docId, name, Date.now());
    return docId;
  }
  
  async listDocuments(): Promise<string[]> {
    return this.sql.exec<{ id: string }>('SELECT id FROM documents').toArray().map(r => r.id);
  }
}

// Child DO
export class Document extends DurableObject<Env> {
  async initialize(name: string) {
    this.ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS content(key TEXT PRIMARY KEY, value TEXT)');
    this.ctx.storage.sql.exec('INSERT INTO content VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', 'name', name);
  }
}
```

## Write Coalescing Pattern

Multiple writes to same key coalesce atomically (last write wins):

```typescript
async updateMetrics(userId: string, actions: Action[]) {
  // All writes coalesce - no await needed
  for (const action of actions) {
    this.ctx.storage.put(`user:${userId}:lastAction`, action.type);
    this.ctx.storage.put(`user:${userId}:count`, 
      ((await this.ctx.storage.get<number>(`user:${userId}:count`)) ?? 0) + 1);
  }
  // Output gate ensures all writes confirm before response
  return new Response("OK");
}

// Atomic batch with SQL
async batchUpdate(items: Item[]) {
  this.ctx.storage.transactionSync(() => {
    for (const item of items) {
      this.sql.exec('INSERT OR REPLACE INTO items VALUES (?, ?)', item.id, item.value);
    }
  });
}
```

## Cleanup

```typescript
async cleanup() {
  await this.ctx.storage.deleteAll(); // Also removes alarms with compatibility_date >= 2026-02-24
}
```
