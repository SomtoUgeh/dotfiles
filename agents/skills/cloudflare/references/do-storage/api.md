# DO Storage API Reference

## SQL API

```typescript
type User = { id: number; name: string; email: string };
// Cursors are single-use: create a fresh query for each alternative below.
const query = () => this.sql.exec<User>(
  'SELECT id, name, email FROM users WHERE email = ?', email
);
for (const row of query()) {} // Objects: { id, name, email }
const rows = query().toArray();
const user = query().one(); // Throws unless exactly one row is returned.
for (const row of query().raw()) {} // Arrays: [1, "Alice", "..."]

// Manual iteration and metrics for this cursor.
const cursor = query();
const iter = cursor[Symbol.iterator]();
const first = iter.next(); // { value: {...}, done: false }
cursor.columnNames; // ["id", "name", "email"]
cursor.rowsRead; cursor.rowsWritten;

const byId = this.sql.exec<User>(
  'SELECT id, name, email FROM users WHERE id = ?', userId
).one();
```

## Sync KV API (SQLite only)

```typescript
this.ctx.storage.kv.get("counter"); // undefined if missing
this.ctx.storage.kv.put("counter", 42);
this.ctx.storage.kv.put("user", { name: "Alice", age: 30 });
this.ctx.storage.kv.delete("counter"); // true if existed

for (let [key, value] of this.ctx.storage.kv.list()) {}

// List options: start, prefix, reverse, limit
this.ctx.storage.kv.list({ start: "user:", prefix: "user:", reverse: true, limit: 100 });
```

## Async KV API (Both backends)

```typescript
await this.ctx.storage.get("key"); // Single
await this.ctx.storage.get(["key1", "key2"]); // Multiple (max 128)
await this.ctx.storage.put("key", value); // Single
await this.ctx.storage.put({ "key1": "v1", "key2": { nested: true } }); // Multiple (max 128)
await this.ctx.storage.delete("key");
await this.ctx.storage.delete(["key1", "key2"]);
await this.ctx.storage.list({ prefix: "user:", limit: 100 });

// Options: allowConcurrency, noCache, allowUnconfirmed
await this.ctx.storage.get("key", { allowConcurrency: true, noCache: true });
await this.ctx.storage.put("key", value, { allowUnconfirmed: true, noCache: true });
```

### Storage Options

| Option | Methods | Effect | Use Case |
|--------|---------|--------|----------|
| `allowConcurrency` | get, list | Skip input gate; allow concurrent requests during read | Read-heavy metrics that don't need strict consistency |
| `noCache` | get, put, list | Skip in-memory cache; always read from disk | Rarely-accessed data or testing storage directly |
| `allowUnconfirmed` | put, delete | Allow outgoing messages before write confirmation (opts out of output-gate protection) | Non-critical writes where latency matters more than confirmation |

## Transactions

```typescript
// Sync (SQL/sync KV only)
this.ctx.storage.transactionSync(() => {
  this.sql.exec('UPDATE accounts SET balance = balance - ? WHERE id = ?', 100, 1);
  this.sql.exec('UPDATE accounts SET balance = balance + ? WHERE id = ?', 100, 2);
  return "result";
});

// Async
await this.ctx.storage.transaction(async (txn) => {
  const value = (await txn.get<number>("counter")) ?? 0;
  await txn.put("counter", value + 1);
  if (value > 100) txn.rollback(); // Explicit rollback
});
```

## Point-in-Time Recovery

These are separate API operations. Save the returned bookmark before passing it
to the restore operation. A time lookup requires retained history for that
timestamp; a newly created object cannot restore to two days before it existed.
`abort()` interrupts the current call; verify the restored state in a new call.

```typescript
await this.ctx.storage.getCurrentBookmark();
await this.ctx.storage.getBookmarkForTime(Date.now() - 2 * 24 * 60 * 60 * 1000);
await this.ctx.storage.onNextSessionRestoreBookmark(bookmark);
this.ctx.abort(); // Restart to apply; bookmarks lexically comparable (earlier < later)
```

## Alarms

```typescript
await this.ctx.storage.setAlarm(Date.now() + 60000); // Timestamp or Date
await this.ctx.storage.getAlarm();
await this.ctx.storage.deleteAlarm();

async alarm() { await this.doScheduledWork(); }
```

## Misc

```typescript
await this.ctx.storage.deleteAll(); // Atomic for SQLite; includes alarm since compatibility_date 2026-02-24
this.ctx.storage.sql.databaseSize; // Bytes
```

For an earlier compatibility date, call `deleteAlarm()` before `deleteAll()`, or enable `delete_all_deletes_alarm`. See the [2026-02-24 behavior change](https://developers.cloudflare.com/changelog/post/2026-02-24-deleteall-deletes-alarms/).
