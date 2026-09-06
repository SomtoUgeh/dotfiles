---
title: Replication
description: Streaming replication, replication slots, synchronous commit levels, failover, and standby management
tags: postgres, replication, streaming, slots, synchronous, failover, standby, operations
---

# Replication

## Streaming Replication for followers

Use physical (byte-for-byte) replication via WAL stream from primary to standbys. Standbys are read-only (hot standby); same major PG version and architecture required (same minor recommended). The primary may recycle WAL before a standby receives it. A configured WAL archive can supply missing segments; rebuild via `pg_basebackup` when required WAL is unavailable from every source. Replication slots reserve WAL for specific standbys, subject to configured retention limits and invalidation rules; they do not guarantee unlimited recovery history.

## Replication Slots

Postgres supports Physical slots (streaming) and logical slots (logical replication). Slots prevent WAL deletion even if standby is offline — can exhaust `pg_wal/` disk. `max_slot_wal_keep_size` limits slot-retained WAL at checkpoint time; it is not an instantaneous disk-use cap. Exceeding it can invalidate a slot (`wal_removed`), requiring the consumer to be rebuilt or otherwise recovered. `idle_replication_slot_timeout` (PG 18+) invalidates idle slots at a checkpoint, so expiry can lag until the next checkpoint. It excludes slots that do not reserve WAL and slots synchronized onto a standby. `wal_keep_size` is a simpler alternative to slots for WAL retention. Investigate inactive slots and confirm the consumer is retired before dropping one; inactivity alone is not evidence it is unnecessary.

Slot lag (MB behind): `SELECT slot_name, pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)/1024/1024 AS mb_behind FROM pg_replication_slots;`

Drop inactive slot: `SELECT pg_drop_replication_slot('slot_name');`

Drop a slot only after confirming its consumer no longer needs it and that deletion is within the user-authorized scope. Existing authorization for disposable test resources includes their cleanup; do not apply that assumption to production slots.

## Synchronous Commit Levels

| Level | Behavior | Use Case |
|-------|----------|----------|
| `off` | Returns immediately, no wait | Non-critical writes; risks losing ~600ms of commits on crash (no inconsistency) |
| `local` | Waits for local WAL fsync only | Local durability only; no standby wait |
| `remote_write` | Waits for standby OS buffer | Data loss on standby OS crash |
| `on` | Waits for standby WAL to disk when `synchronous_standby_names` is set; otherwise same as `local` | **Default. This level or higher recommended for HA** |
| `remote_apply` | Waits for standby to apply WAL | Strongest; read-your-writes |

Configure with `synchronous_standby_names`. Use `ANY N` for quorum or `FIRST N` for priority-based sync.

## Quorum and Failure

`FIRST 2 (s1, s2, s3)` is priority-based: waits for the 2 highest-priority connected standbys (s1+s2; s3 takes over only if one disconnects). `ANY 2 (s1, s2, s3)` is quorum-based: waits for any 2. With either, if only 1 is healthy, commits hang. Provision at least N+1 standbys: need 2 confirmations → provision 3. With synchronous commit enabled, success waits for the required confirmations. A client timeout/cancel does not prove rollback: the transaction may already be locally committed. Resolve ambiguous outcomes with idempotency and a read-back before retrying.

## Failover

`pg_ctl promote` or `SELECT pg_promote()` (SQL function, PG 12+) converts standby to primary. A promoted server needs an explicit rejoin procedure; `pg_rewind` may avoid a full rebuild when its prerequisites and required WAL are available. `pg_rewind` can resync old primary to new primary (requires `wal_log_hints=on` or data checksums) — faster than full rebuild. After promotion: update connection strings, rebuild old primary as standby, reconfigure other standbys. Recheck recovery configuration copied by `pg_rewind`, especially `primary_conninfo` and `primary_slot_name`. A physical slot from the old primary does not automatically exist on the promoted server: create the intended slot there or configure another supported retention strategy before starting the rejoined standby. Verify a new write made after rejoin reaches it; matching data immediately after rewind alone does not prove streaming works.

## Monitoring

On the primary, query `pg_stat_replication` for each connected standby's `state` (`streaming` = healthy, `catchup` = behind), `sync_state` (`sync`/`async`), and LSN positions (`sent_lsn`, `write_lsn`, `flush_lsn`, `replay_lsn`) to compute lag. On standbys, `pg_stat_wal_receiver` shows the receiver process status and `flushed_lsn`; compare `pg_last_wal_receive_lsn()` vs `pg_last_wal_replay_lsn()` for local replay lag.

Replication lag (MB): `SELECT application_name, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)/1024/1024 AS lag_mb FROM pg_stat_replication;`

Enable `wal_compression` (`pglz`, `lz4`, or `zstd`) to compress full page images in WAL (not all WAL data) — reduces WAL size for bandwidth-limited replication.
