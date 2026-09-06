---
title: MVCC Transactions and Concurrency
description: Transaction isolation levels, XID wraparound prevention, serialization errors, and long-transaction impact
tags: postgres, mvcc, transactions, isolation, xid-wraparound, concurrency, serialization
---

# MVCC Transactions and Concurrency

## Transaction Isolation Levels

- **READ UNCOMMITTED** — treated as READ COMMITTED in PostgreSQL; no dirty reads ever.
- **READ COMMITTED** (default): new snapshot per statement; can see different data within same tx.
- **REPEATABLE READ**: snapshot at first query; can cause serialization errors on write conflicts.
- **SERIALIZABLE**: strongest; transactions appear serial; requires retry logic in app code.

Ordinary MVCC reads and writes do not block one another for row visibility. Explicit row locks and DDL/table locks can block readers or writers. No lock escalation — row locks never degrade to table locks.

## XID Wraparound

Transaction IDs use a 32-bit space; modular ordering becomes unsafe around 2^31 transactions of age. VACUUM freezes old tuple XIDs, and PostgreSQL prevents new XID-assigning transactions before wraparound. Monitor age and anti-wraparound vacuum well before that limit. Warning/stop thresholds vary by release; follow the installed version's routine-vacuuming documentation rather than a fixed 1.4B threshold.

Keep autovacuum enabled. If protections trigger, investigate old snapshots, prepared transactions and replication slots, then use the documented recovery procedure; do not assume single-user mode is always required.

## XID Age Monitoring


```sql
SELECT datname, age(datfrozenxid),
  ROUND(100.0 * age(datfrozenxid) / 2147483648, 2) AS pct
FROM pg_database ORDER BY age(datfrozenxid) DESC;
```

## Long Transaction Impact

An old retained snapshot can hold back removal of tuples it may still see. The effect depends on isolation level, snapshot lifetime, prepared transactions and replication slots; an open transaction does not freeze all cleanup unconditionally. Causes table bloat, increased disk, slower queries, cache pollution. `idle_in_transaction` connections are the #1 operational MVCC issue. Set `idle_in_transaction_session_timeout` (30s–5min). Dead tuples waste I/O on seq scans and cause useless heap lookups from indexes.

## Serialization Errors

Apps **must** handle "could not serialize access" with retry logic. More common in REPEATABLE READ and SERIALIZABLE. Smaller, faster transactions reduce conflict frequency.
