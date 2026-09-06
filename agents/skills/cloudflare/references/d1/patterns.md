# D1 Patterns & Best Practices

## Pagination

```typescript
interface User { id: number; name: string; email: string; created_at: string }
async function getUsers({ page, pageSize }: { page: number; pageSize: number }, env: { DB: D1Database }) {
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new RangeError("Invalid page or pageSize");
  }
  const offset = (page - 1) * pageSize;
  const session = env.DB.withSession();
  const total = await session.prepare('SELECT COUNT(*) AS total FROM users').first<number>('total') ?? 0;
  const data = await session.prepare('SELECT * FROM users ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?')
    .bind(pageSize, offset).all<User>();
  return { data: data.results, total, page, pageSize, totalPages: Math.ceil(total / pageSize) };
}
// Sequential consistency is not snapshot isolation; concurrent writes can change the count between queries.
```

## Conditional Queries

```typescript
async function searchUsers(filters: { name?: string; email?: string; active?: boolean }, env: Env) {
  const conditions: string[] = [], params: (string | number | null)[] = [];
  if (filters.name) { conditions.push('name LIKE ?'); params.push(`%${filters.name}%`); }
  if (filters.email) { conditions.push('email = ?'); params.push(filters.email); }
  if (filters.active !== undefined) { conditions.push('active = ?'); params.push(filters.active ? 1 : 0); }
  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  return await env.DB.prepare(`SELECT * FROM users ${whereClause}`).bind(...params).all();
}
```

## Bulk Insert

```typescript
async function bulkInsertUsers(users: Array<{ name: string; email: string }>, env: Env) {
  const stmt = env.DB.prepare('INSERT INTO users (name, email) VALUES (?, ?)');
  if (users.length === 0) return [];
  const batch = users.map(user => stmt.bind(user.name, user.email));
  return await env.DB.batch(batch);
}
```

## Caching with KV

```typescript
async function getCachedUser(userId: number, env: { DB: D1Database; CACHE: KVNamespace }) {
  const cacheKey = `user:${userId}`;
  const cached = await env.CACHE?.get(cacheKey, 'json');
  if (cached) return cached;
  const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
  if (user) await env.CACHE?.put(cacheKey, JSON.stringify(user), { expirationTtl: 300 });
  return user;
}
```

## Query Optimization

```typescript
// ✅ Use indexes in WHERE clauses
const users = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).all();

// ✅ Limit result sets
const recentPosts = await env.DB.prepare('SELECT * FROM posts ORDER BY created_at DESC LIMIT 100').all();

// ✅ Use batch() for multiple independent queries
const [user, posts, comments] = await env.DB.batch([
  env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId),
  env.DB.prepare('SELECT * FROM posts WHERE user_id = ?').bind(userId),
  env.DB.prepare('SELECT * FROM comments WHERE user_id = ?').bind(userId)
]);

// ❌ Avoid N+1 queries
for (const post of posts.results) {
  const author = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(post.user_id).first(); // Bad: multiple round trips
}

// ✅ Use JOINs instead
const postsWithAuthors = await env.DB.prepare(`
  SELECT posts.*, users.name as author_name
  FROM posts
  JOIN users ON posts.user_id = users.id
`).all();
```

## Multi-Tenant SaaS

Resolve the tenant database from authenticated identity and server-owned configuration before querying. Never choose `env[TENANT_...]` directly from an `X-Tenant-ID` header. With a shared database, include the authorized tenant ID in every query and enforce it for writes as well as reads.

## Session Storage

```typescript
async function createSession(userId: number, token: string, env: Env) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  return await env.DB.prepare('INSERT INTO sessions (user_id, token, expires_at) VALUES (?, ?, ?)').bind(userId, token, expiresAt).run();
}

async function validateSession(token: string, env: Env) {
  return await env.DB.prepare('SELECT s.*, u.email FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = ? AND s.expires_at > ?').bind(token, new Date().toISOString()).first();
}
```

## Analytics/Events

```typescript
async function logEvent(event: { type: string; userId?: number; metadata: object }, env: Env) {
  return await env.DB.prepare('INSERT INTO events (type, user_id, metadata) VALUES (?, ?, ?)').bind(event.type, event.userId ?? null, JSON.stringify(event.metadata)).run();
}

async function getEventStats(startDate: string, endDate: string, env: Env) {
  return await env.DB.prepare('SELECT type, COUNT(*) as count FROM events WHERE timestamp BETWEEN ? AND ? GROUP BY type ORDER BY count DESC').bind(startDate, endDate).all();
}
```

## Sessions and read replication

D1 sessions provide sequential consistency across queries; they do not extend query timeouts or reserve a 15-minute connection. A session has no `close()` method.

```typescript
const session = env.DB.withSession("first-primary");
await session.prepare("UPDATE users SET last_login = ? WHERE id = ?")
  .bind(Date.now(), userId).run();
const user = await session.prepare("SELECT * FROM users WHERE id = ?")
  .bind(userId).first();
const bookmark = session.getBookmark();
```

Use `first-unconstrained` (the default) for an initial read from any eligible replica, `first-primary` when the first query must use the primary, or a previous bookmark to resume from at least that database version. Subsequent queries in that session preserve sequential consistency. Enabling read replication and using `withSession` controls replica routing; adding a second binding with the same database ID does not create a replica.

[Read replication documentation](https://developers.cloudflare.com/d1/best-practices/read-replication/).

## Time Travel & Backups

```bash
wrangler d1 time-travel restore <db-name> --timestamp="2024-01-15T14:30:00Z"  # Point-in-time
wrangler d1 time-travel info <db-name>  # List restore points (7 days free, 30 days paid)
wrangler d1 export <db-name> --remote --output=./backup.sql  # Full export
wrangler d1 export <db-name> --remote --no-schema --output=./data.sql  # Data only
wrangler d1 execute <db-name> --remote --file=./backup.sql  # Import
```

Binding source: [D1 database and sessions API](https://developers.cloudflare.com/d1/worker-api/d1-database/). SQL result generics describe expected rows and do not validate them at runtime.
