# DO Storage Configuration

## SQLite-backed (Recommended)

**wrangler.jsonc:**
```jsonc
{
  "exports": {
    "Counter": { "type": "durable-object", "storage": "sqlite" },
    "Session": { "type": "durable-object", "storage": "sqlite" },
    "RateLimiter": { "type": "durable-object", "storage": "sqlite" }
  }
}
```

For a new deployment, `exports` declares the Durable Object lifecycle without migration tags.

## KV-backed (Legacy)

Existing migration-based deployments remain supported. Keep using migrations for their lifecycle changes; `migrations` and Durable Object `exports` are mutually exclusive in one Wrangler configuration.

**wrangler.jsonc:**
```jsonc
{
  "migrations": [
    {
      "tag": "v1",
      "new_classes": ["OldCounter"]
    }
  ]
}
```

## TypeScript Setup

```typescript
import { DurableObject } from "cloudflare:workers";

export class MyDurableObject extends DurableObject<Env> {
  sql: SqlStorage;
  
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    
    // Initialize schema
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
      );
    `);
  }

  listUsers() {
    return this.sql.exec<{ id: number; name: string; email: string | null }>("SELECT id, name, email FROM users").toArray();
  }
}

// Binding
interface Env {
  MY_DO: DurableObjectNamespace<MyDurableObject>;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const id = env.MY_DO.idFromName('singleton');
    const stub = env.MY_DO.get(id);
    
    // Modern RPC: call methods directly (recommended)
    const result = await stub.listUsers();
    return Response.json(result);
    
    // Legacy: forward request (still works)
    // return stub.fetch(request);
  }
}
```

## CPU Limits

```jsonc
{
  "limits": {
    "cpu_ms": 300000  // 5 minutes (default 30s)
  }
}
```

## Location Control

```typescript
// Jurisdiction (GDPR/FedRAMP)
const euNamespace = env.MY_DO.jurisdiction("eu");
const id = euNamespace.newUniqueId();
const stub = euNamespace.get(id);

// Location hint (best effort)
const stub = env.MY_DO.get(id, { locationHint: "enam" });
// Hints: wnam, enam, sam, weur, eeur, apac, oc, afr, me
```

## Initialization

```typescript
import { DurableObject } from "cloudflare:workers";

export class Counter extends DurableObject<Env> {
  value = 0;
  
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    
    // Block concurrent requests during init
    ctx.blockConcurrencyWhile(async () => {
      this.value = (await ctx.storage.get<number>("value")) ?? 0;
    });
  }
}
```
