---
title: Backup and Recovery
description: Logical/physical backups, PITR, WAL archiving, backup tools, and recovery strategies
tags: postgres, backup, recovery, pitr, pg_dump, pg_basebackup, wal-archiving, operations
---

# Backup and Recovery

**FUNDAMENTAL RULE: Backups are useless until you've successfully tested recovery.**

## Logical Backups (pg_dump)
Exports as SQL or custom format; portable across PG versions and architectures. Formats: `-Fp` (plain SQL), `-Fc` (custom compressed, selective restore), `-Fd` (directory, parallel with `-j`), `-Ft` (tar, avoid). Use `-Fd -j 4` for large DBs. Restore: `pg_restore -d dbname file.dump`; add `-j` for parallel restore. Selective table restore: `pg_restore -t tablename`. Slow for large DBs; RPO = backup frequency (typically 24h).

## Physical Backups (pg_basebackup)
Copies raw PGDATA; requires compatible PostgreSQL major version, architecture, build options and storage layout; matching endianness alone does not establish portability. Use logical dumps for cross-platform migration unless physical compatibility is explicitly documented and tested. Faster for large clusters; includes all databases. Flags: `-Ft -z -P` for compressed tar with progress. Prefer `pg_basebackup` over a manual file copy. If a manual backup is required, follow the complete [low-level base backup procedure](https://www.postgresql.org/docs/18/continuous-archiving.html#BACKUP-LOWLEVEL-BASE-BACKUP), including session continuity, tablespace copying, the returned `backup_label` and nonempty `tablespace_map`, and all required WAL.

## PITR (Point-in-Time Recovery)
Requires base backup + continuous WAL archiving. Restores to any timestamp, transaction, or named restore point. Without PITR: restore only to backup time (potentially lose hours). With PITR, RPO depends on WAL shipping and archive delay; measure it rather than assuming minutes. `archive_command` must return 0 ONLY when file is safely stored—premature 0 = data loss risk. `wal_level` must be `replica` or `logical` (not `minimal`).

## WAL Archiving
The illustrative Unix setup is `archive_mode=on`, `archive_command='test ! -f /archive/%f && cp %p /archive/%f'`. This refuses an existing destination and demonstrates copying; it is not a complete production archive implementation. A production archiver must report success only after durable storage, accept an identical already-durable file on retry, and reject conflicting contents. Prefer a maintained archive tool for those guarantees. **Test the command as the actual PostgreSQL service account**, since permissions are part of its behavior. Monitor `pg_stat_archiver` for `failed_count`, `last_archived_time`. Archive failures prevent WAL recycling → disk fills.

## Tool Comparison
| Tool | Use case |
|------|----------|
| pg_dump | Small DBs, migrations, selective restore |
| pg_basebackup | Basic PITR, built-in |
| pgBackRest | Production—parallel, incremental, S3/GCS/Azure, retention |
| Barman | Enterprise PITR, retention policies |
| WAL-G | Cloud-native, S3/GCS/Azure |

## RPO/RTO
For logical backups, the backup interval bounds how much recent data may be missing. PITR reduces that window according to archive delay. Recovery time depends on backup size, replay volume, storage and the recovery procedure; it is not a fixed number of hours. Synchronous replication can avoid loss of acknowledged commits within its configured failure model; it is not a backup against accidental deletion/corruption. Measure RPO/RTO with actual restore and failover tests.

## Operational Rules
- Verify integrity with `pg_verifybackup` (PG 13+)
- Test recovery / PITR regularly
- Take backups from standby to avoid impacting primary
- Retention: 7 daily, 4 weekly, 12 monthly
- Monitor archive growth and backup age
- **Never assume backups work without testing**
