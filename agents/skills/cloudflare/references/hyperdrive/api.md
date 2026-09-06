# API Reference

See [README.md](./README.md) for overview, [configuration.md](./configuration.md) for setup.

## Binding Interface

```typescript
interface Hyperdrive {
  connectionString: string;  // PostgreSQL
  // MySQL properties:
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
}

interface Env {
  HYPERDRIVE: Hyperdrive;
}
```

**Generate types:** `npx wrangler types` (auto-creates worker-configuration.d.ts from wrangler.jsonc)

## PostgreSQL (node-postgres) - RECOMMENDED

```typescript
import { Client } from "pg";  // pg@^8.17.2

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const client = new Client({connectionString: env.HYPERDRIVE.connectionString});
    try {
      await client.connect();
      const result = await client.query("SELECT * FROM users WHERE id = $1", [123]);
      return Response.json(result.rows);
    } finally {
      await client.end();
    }
  },
};
```

**⚠️ Workers connection limit: 6 simultaneously opening outbound connections per invocation** - use connection pooling wisely.

## PostgreSQL (postgres.js)

```typescript
import postgres from "postgres";  // postgres@^3.4.8

const sql = postgres(env.HYPERDRIVE.connectionString, {
  max: 5,             // Bound driver concurrency; account for other outbound operations
  prepare: true,      // Enabled by default, required for caching
  fetch_types: false, // Reduce latency if not using arrays
});

const users = await sql`SELECT * FROM users WHERE active = ${true} LIMIT 10`;
```

**⚠️ `prepare: true` is enabled by default and required for Hyperdrive caching.** Setting to `false` disables prepared statements + cache.

## MySQL (mysql2)

```typescript
import { createConnection } from "mysql2/promise";  // mysql2@^3.16.2

const conn = await createConnection({
  host: env.HYPERDRIVE.host,
  user: env.HYPERDRIVE.user,
  password: env.HYPERDRIVE.password,
  database: env.HYPERDRIVE.database,
  port: env.HYPERDRIVE.port,
  disableEval: true,  // ⚠️ REQUIRED for Workers
});

const [results] = await conn.query("SELECT * FROM users WHERE active = ? LIMIT ?", [true, 10]);
ctx.waitUntil(conn.end());
```

**⚠️ MySQL support is less mature than PostgreSQL** - expect fewer optimizations and potential edge cases.

## Query Caching

**Cacheable:**
```sql
SELECT * FROM posts WHERE published = true;
SELECT COUNT(*) FROM users;
```

**NOT cacheable:**
```sql
-- Writes
INSERT/UPDATE/DELETE

-- Volatile functions
SELECT NOW();
SELECT random();
SELECT LASTVAL();  -- PostgreSQL
SELECT UUID();     -- MySQL
```

**Cache config:**
- Default: `max_age=60s`, `swr=15s`
- Max `max_age`: 3600s
- Disable: `--caching-disabled=true`

**Multiple configs pattern:**
```typescript
// Reads: cached
const sqlCached = postgres(env.HYPERDRIVE_CACHED.connectionString);
const posts = await sqlCached`SELECT * FROM posts ORDER BY views DESC LIMIT 10`;

// Writes/time-sensitive: no cache
const sqlNoCache = postgres(env.HYPERDRIVE_NO_CACHE.connectionString);
const orders = await sqlNoCache`SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '5 minutes'`;
```

## ORMs

**Drizzle:**
```typescript
import { eq } from "drizzle-orm";
import { users } from "./schema";
import { drizzle } from "drizzle-orm/postgres-js";  // drizzle-orm@^0.45.1
import postgres from "postgres";

const client = postgres(env.HYPERDRIVE.connectionString, {max: 5, prepare: true});
const db = drizzle(client);
const rows = await db.select().from(users).where(eq(users.active, true)).limit(10);
```

**Kysely:**
```typescript
import { Kysely, PostgresDialect } from "kysely";
import { Pool } from "pg";
interface Database { users: { id: number; active: boolean } }
const db = new Kysely<Database>({
  dialect: new PostgresDialect({ pool: new Pool({ connectionString: env.HYPERDRIVE.connectionString, max: 5 }) }),
});
try {
  const rows = await db.selectFrom("users").selectAll().where("active", "=", true).execute();
  console.log(rows);
} finally {
  await db.destroy();
}
```

See [patterns.md](./patterns.md) for use cases, [gotchas.md](./gotchas.md) for limits.

## Connection lifetime and freshness

Create clients inside the request. Wrap query work in `try/finally` and close `pg` with `await client.end()`, postgres.js with `await sql.end()`, mysql2 with `await conn.end()`, or Kysely with `await db.destroy()`. Apply this to the abbreviated query fragments above, including error paths. Roll back failed explicit transactions before closing. Never reuse a connection created in another request.

Writes do not invalidate cached SELECT results. Route both writes and freshness-sensitive reads through a cache-disabled Hyperdrive configuration; use the cached binding only where staleness is acceptable. Local driver tests do not verify hosted Hyperdrive caching or pooling.
