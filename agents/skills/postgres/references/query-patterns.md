---
title: SQL Query Patterns
description: Common SQL anti-patterns and optimized alternatives
tags: postgres, sql, query-optimization, n-plus-one, pagination
---

# SQL Query Patterns

## Query Structure

**SELECT specific columns** — avoids fetching unnecessary data and enables covering indexes:
```sql
-- Bad:
SELECT * FROM user_account WHERE status = 'active';
-- Good:
SELECT id, name, email FROM user_account WHERE status = 'active';
```

**Compare subqueries and JOINs with the actual plan** — a correlated aggregate can repeat work; a pre-aggregation or JOIN can help, while an index probe can also be efficient:
```sql
-- Bad
SELECT id, (SELECT COUNT(*) FROM purchase_order WHERE purchase_order.user_id = user_account.id) FROM user_account;
-- Good
SELECT u.id, COUNT(o.id) FROM user_account u LEFT JOIN purchase_order o ON o.user_id = u.id GROUP BY u.id;
```

**Always LIMIT unbounded queries** — prevent runaway result sets:
```sql
SELECT id, message FROM log WHERE level = 'error' ORDER BY created_at DESC LIMIT 100;
```

**Avoid functions on indexed columns (SARGable)** — functions prevent index usage unless a functional index exists:
```sql
-- Bad: Full table scan
SELECT * FROM user_account WHERE date_trunc('day', created_at) = '2023-01-01';
-- Good: Index scan
SELECT * FROM user_account WHERE created_at >= '2023-01-01' AND created_at < '2023-01-02';
```

## N+1 Detection

**Queries inside loops → batch with ANY/IN:**
```python
# Bad
for uid in user_ids:
    cursor.execute("SELECT name FROM user_account WHERE id = %s", (uid,))
# Good (Postgres specific)
cursor.execute("SELECT id, name FROM user_account WHERE id = ANY(%s)", (list(user_ids),))
# ANY with an array also handles an empty user_ids list; placeholder
# behavior is driver-specific (this example uses psycopg).
```

**ORM lazy loading → eager loading:**
```python
# Bad: N+1 — each iteration fires a query
for user in User.query.all():
    print(user.posts)
# Good
users = User.query.options(joinedload(User.posts)).all()
```

## Query Rewrites

**UNION → UNION ALL** — skip deduplication when duplicates are impossible or acceptable.

**Use EXISTS for existence checks** — the optimizer may generate the same semi-join plan as IN; it is not universally faster:
```sql
SELECT id, name FROM user_account u
WHERE EXISTS (SELECT 1 FROM purchase_order o WHERE o.user_id = u.id AND o.total > 100);
```

**OFFSET → cursor pagination** — OFFSET scans and discards rows, degrading at depth:
```sql
-- Bad: OFFSET 10000 scans 10020 rows
SELECT id, title FROM article ORDER BY created_at DESC LIMIT 20 OFFSET 10000;
-- Good: cursor-based (requires index on (created_at DESC, id DESC))
SELECT id, title FROM article
WHERE (created_at, id) < ('2025-06-15T12:00:00Z', 987654)
ORDER BY created_at DESC, id DESC LIMIT 20;
```
