# D1 Gotchas & Troubleshooting

## Common Errors

### "SQL Injection Vulnerability"

**Cause:** Using string interpolation instead of prepared statements with bind()
**Solution:** ALWAYS use prepared statements: `env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).all()` instead of string interpolation which allows attackers to inject malicious SQL

### "no such table"

**Cause:** Table doesn't exist because migrations haven't been run, or using wrong database binding
**Solution:** Run migrations using `wrangler d1 migrations apply <db-name> --remote` and verify binding name in wrangler.jsonc matches code

### "UNIQUE constraint failed"

**Cause:** Attempting to insert duplicate value in column with UNIQUE constraint
**Solution:** Catch error and return 409 Conflict status code

### "Query Timeout (30s exceeded)"

**Cause:** Query execution exceeds 30 second timeout limit
**Solution:** Break into smaller queries, add indexes to speed up queries, or reduce dataset size

### "N+1 Query Problem"

**Cause:** Making multiple individual queries in a loop instead of single optimized query
**Solution:** Use JOIN to fetch related data in single query or use `batch()` method for multiple queries

### "Missing Indexes"

**Cause:** Queries performing full table scans without indexes
**Solution:** Use `EXPLAIN QUERY PLAN` to check if index is used, then create index with `CREATE INDEX idx_users_email ON users(email)`

### "Boolean Type Issues"

**Cause:** SQLite uses INTEGER (0/1) not native boolean type
**Solution:** Bind 1 or 0 instead of true/false when working with boolean values

### "Date/Time Type Issues"

**Cause:** SQLite doesn't have native DATE/TIME types
**Solution:** Use TEXT (ISO 8601 format) or INTEGER (unix timestamp) for date/time values

## Platform limits

Read [current D1 limits](https://developers.cloudflare.com/d1/platform/limits/) for database/row sizes, bind parameters, query duration, and Worker invocation query limits. Sessions do not increase any timeout.

## Production Gotchas

### Batches and sessions

Keep batches bounded by the current statement, bind-parameter, and invocation limits. `batch()` executes its statements atomically; multiple batches are separate transactions. Sessions provide sequential consistency and use `getBookmark()`; there is no `session.close()` or timeout option.

### "Migration applied to local but not remote"

**Cause:** Forgot `--remote` flag when applying migrations
**Solution:** Always run `wrangler d1 migrations apply <db-name> --remote` for production

### "Foreign key constraint failed"

**Cause:** Inserting row with FK to non-existent parent, or deleting parent before children
**Solution:** D1 enforces foreign keys. Insert parents first and choose cascade behavior deliberately. Use `PRAGMA defer_foreign_keys = ON` inside supported migrations when temporary deferral is needed; do not assume foreign_keys can be disabled.

### Export validation

Restore a representative export into a disposable database and compare schema, row counts, and binary values before trusting it as a backup.

### "Database size approaching limit"

**Cause:** Storing too much data in single database
**Solution:** Horizontal scale-out: create per-tenant/per-user databases, archive old data, or upgrade to paid plan

### "Local dev vs production behavior differs"

**Cause:** Local uses SQLite file, production uses distributed D1 - different performance/limits
**Solution:** Test locally, then against an explicitly selected disposable/staging remote database before production rollout. `--remote` is not itself a staging selector.

Binding source: [D1 database and sessions API](https://developers.cloudflare.com/d1/worker-api/d1-database/). SQL result generics describe expected rows and do not validate them at runtime.
