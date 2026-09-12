# Hyperdrive

Accelerates database queries from Workers via connection pooling, edge setup, query caching.

## Key Features

- **Connection Pooling**: Persistent connections eliminate TCP/TLS/auth handshakes (~7 round-trips)
- **Edge Setup**: Connection negotiation at edge, pooling near origin
- **Query Caching**: Auto-cache non-mutating queries (default 60s TTL)
- **Support**: PostgreSQL, MySQL + compatibles (CockroachDB, Timescale, PlanetScale, Neon, Supabase)

## Architecture

```
Worker → Edge (setup) → Pool (near DB) → Origin
         ↓ cached reads
         Cache
```

## Quick Start

```bash
# Create config
npx wrangler hyperdrive create my-db \
  --connection-string="postgres://user:pass@host:5432/db"

# wrangler.jsonc
{
  "compatibility_flags": ["nodejs_compat"],
  "hyperdrive": [{"binding": "HYPERDRIVE", "id": "<ID>"}]
}
```

```typescript
import { Client } from "pg";

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const client = new Client({
      connectionString: env.HYPERDRIVE.connectionString,
    });
    await client.connect();
    const result = await client.query("SELECT * FROM users WHERE id = $1", [123]);
    await client.end();
    return Response.json(result.rows);
  },
};
```

## When to Use

✅ Global access to single-region DBs, high read ratios, popular queries, connection-heavy loads
❌ Write-heavy, real-time data (<1s), single-region apps close to DB

**💡 Pair with Smart Placement** for Workers making multiple queries - executes near DB to minimize latency.

## Driver Choice

| Driver | Use When | Notes |
|--------|----------|-------|
| **pg** (recommended) | General use, TypeScript, ecosystem compatibility | Stable, widely used, works with most ORMs |
| **postgres.js** | Advanced features, template literals, streaming | Lighter than pg, `prepare: true` is default |
| **mysql2** | MySQL/MariaDB/PlanetScale | MySQL only, less mature support |

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## In This Reference
- [configuration.md](./configuration.md) - Setup, wrangler config, Smart Placement
- [api.md](./api.md) - Binding APIs, query patterns, driver usage
- [patterns.md](./patterns.md) - Use cases, ORMs, multi-query optimization
- [gotchas.md](./gotchas.md) - Limits, troubleshooting, connection management

## See Also
- [smart-placement](../smart-placement/) - Optimize multi-query Workers near databases
- [d1](../d1/) - Serverless SQLite alternative for edge-native apps
- [workers](../workers/) - Worker runtime with database bindings

## Connection lifetime and freshness

Create clients inside the request. Wrap query work in `try/finally` and close `pg` with `await client.end()`, postgres.js with `await sql.end()`, mysql2 with `await conn.end()`, or Kysely with `await db.destroy()`. Apply this to the abbreviated query fragments above, including error paths. Roll back failed explicit transactions before closing. Never reuse a connection created in another request.

Writes do not invalidate cached SELECT results. Route both writes and freshness-sensitive reads through a cache-disabled Hyperdrive configuration; use the cached binding only where staleness is acceptable. Local driver tests do not verify hosted Hyperdrive caching or pooling.
