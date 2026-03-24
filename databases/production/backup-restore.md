# Database Backup and Restore

> The strategy, tooling, and verification process for creating recoverable copies of database state — and actually getting your data back when something goes wrong.

---

## When To Use It

Every production database needs a backup strategy before the first user writes data. Use this when designing RTO (Recovery Time Objective — how long recovery takes) and RPO (Recovery Point Objective — how much data loss is acceptable) for your system. The backup strategy that fits a blog is not the same as one that fits a payment system. The restore procedure matters as much as the backup — a backup you've never tested restoring is not a backup.

---

## Core Concept

There are three backup types: full (complete snapshot of everything), incremental (only changes since the last backup), and WAL/binlog-based continuous archiving (stream every write as it happens). Full backups are simple but slow and large. Incremental backups are fast but require the full backup plus every incremental in sequence to restore. Continuous archiving gives you point-in-time recovery (PITR) — restore to any moment, not just the last backup. Production systems almost always need continuous archiving on top of periodic full backups. The other axis is logical vs physical: logical backups dump SQL statements that recreate the data (portable, slow to restore at scale); physical backups copy the raw data files (fast to restore, same DB version required).

---

## The Code

**Postgres — logical backup with pg_dump**
```bash
# Single database — logical backup (SQL format)
pg_dump -h localhost -U postgres -d mydb -f mydb_backup.sql

# Custom format — smaller, parallelizable restore, preferred for large DBs
pg_dump -h localhost -U postgres -d mydb -Fc -f mydb_backup.dump

# Parallel dump — 4 jobs, directory format (fastest for large DBs)
pg_dump -h localhost -U postgres -d mydb -Fd -j 4 -f mydb_backup_dir/

# All databases
pg_dumpall -h localhost -U postgres -f all_databases.sql

# Restore from custom format
pg_restore -h localhost -U postgres -d mydb -Fc mydb_backup.dump

# Parallel restore — dramatically faster on large dumps
pg_restore -h localhost -U postgres -d mydb -Fc -j 4 mydb_backup.dump

# Restore specific table only
pg_restore -h localhost -U postgres -d mydb -t orders mydb_backup.dump
```

**Postgres — continuous archiving (WAL) for PITR**
```bash
# postgresql.conf settings for WAL archiving
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /backups/wal/%f'
# (in production: use pgBackRest or WAL-G instead of cp)

# pgBackRest — production WAL archiving tool
# /etc/pgbackrest.conf
# [global]
# repo1-path=/var/lib/pgbackrest
# repo1-retention-full=2
#
# [mydb]
# pg1-path=/var/lib/postgresql/data

# Full backup
pgbackrest --stanza=mydb backup --type=full

# Incremental backup (default)
pgbackrest --stanza=mydb backup

# Point-in-time restore — restore to exact timestamp
pgbackrest --stanza=mydb restore \
    --target="2026-03-24 14:30:00" \
    --target-action=promote

# Show backup info
pgbackrest --stanza=mydb info
```

**WAL-G — cloud-native WAL archiving**
```bash
# Environment variables for S3
export WALG_S3_PREFIX=s3://my-backups/postgres
export AWS_REGION=us-east-1

# Full backup to S3
wal-g backup-push /var/lib/postgresql/data

# List available backups
wal-g backup-list

# Restore latest backup
wal-g backup-fetch /var/lib/postgresql/data LATEST

# Restore specific backup
wal-g backup-fetch /var/lib/postgresql/data base_000000010000000000000005

# WAL archiving — add to postgresql.conf
# archive_command = 'wal-g wal-push %p'
# restore_command = 'wal-g wal-fetch %f %p'
```

**MySQL/MariaDB — mysqldump and binlog**
```bash
# Logical backup
mysqldump -h localhost -u root -p mydb > mydb_backup.sql

# All databases with routines and events
mysqldump -h localhost -u root -p \
    --all-databases \
    --routines \
    --events \
    --single-transaction \   # consistent snapshot without locking (InnoDB)
    > full_backup.sql

# Restore
mysql -h localhost -u root -p mydb < mydb_backup.sql

# Physical backup with XtraBackup (hot backup, no lock)
xtrabackup --backup --target-dir=/backups/mysql/full

# Prepare backup for restore
xtrabackup --prepare --target-dir=/backups/mysql/full

# Point-in-time restore using binlogs
mysqlbinlog \
    --start-datetime="2026-03-24 12:00:00" \
    --stop-datetime="2026-03-24 14:30:00" \
    /var/lib/mysql/binlog.000001 | mysql -u root -p
```

**Automated backup script with retention**
```bash
#!/bin/bash
set -euo pipefail

DB_NAME="mydb"
BACKUP_DIR="/backups/postgres"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

# Create backup
pg_dump -h localhost -U postgres -d "$DB_NAME" -Fc -f "$BACKUP_FILE"

# Verify backup is non-zero size
if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file is empty" >&2
    exit 1
fi

# Upload to S3 (redundant copy)
aws s3 cp "$BACKUP_FILE" "s3://my-backups/postgres/${DB_NAME}_${TIMESTAMP}.dump"

# Delete local backups older than retention period
find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -mtime +${RETENTION_DAYS} -delete

echo "Backup complete: $BACKUP_FILE"
```

**Restore verification — the step most teams skip**
```bash
#!/bin/bash
# Run this after every backup — not just before a disaster

BACKUP_FILE=$1
TEST_DB="restore_verify_$(date +%s)"

echo "Creating test database: $TEST_DB"
createdb -U postgres "$TEST_DB"

echo "Restoring backup..."
pg_restore -U postgres -d "$TEST_DB" -Fc "$BACKUP_FILE"

echo "Running sanity checks..."
psql -U postgres -d "$TEST_DB" -c "
    SELECT
        schemaname,
        tablename,
        n_live_tup AS row_count
    FROM pg_stat_user_tables
    ORDER BY n_live_tup DESC
    LIMIT 10;
"

# Check row counts match production expectations
USERS=$(psql -U postgres -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM users;")
echo "Users table row count: $USERS"

# Clean up
dropdb -U postgres "$TEST_DB"
echo "Verification complete"
```

**MongoDB backup**
```bash
# mongodump — logical backup
mongodump \
    --uri="mongodb://localhost:27017" \
    --db=mydb \
    --out=/backups/mongo/

# Restore
mongorestore \
    --uri="mongodb://localhost:27017" \
    --db=mydb \
    /backups/mongo/mydb/

# Point-in-time restore requires MongoDB Atlas or oplog replay
# Replay oplog from a specific timestamp
mongorestore \
    --oplogReplay \
    --oplogLimit="1711285200:1" \   # timestamp:ordinal
    /backups/mongo/
```

---

## Gotchas

- **A backup you have never restored is not a backup.** Run restore verification in a staging environment on a schedule — weekly at minimum. The most common disaster scenario is discovering your restore process is broken during the actual disaster.
- **`pg_dump` without `--single-transaction` on a live database produces an inconsistent snapshot.** Tables dumped at different times will have different states. Always use `--single-transaction` for InnoDB (MySQL) or rely on pg_dump's default MVCC snapshot for Postgres.
- **WAL archiving gaps break PITR.** If even one WAL segment fails to archive, you can't recover past that gap. Monitor `archive_command` success rate and set up alerts on archiving lag — not just on backup completion.
- **Logical restores at scale are slow.** Restoring a 500GB `pg_dump` SQL file can take 10+ hours because it replays every INSERT. For large databases, physical backups (pgBackRest, WAL-G) restore in minutes by copying data files directly. RTO requirements should drive which you use.
- **Backup encryption is not optional for production.** S3 server-side encryption is a minimum. Backups contain everything — credentials in config tables, PII, payment data. Encrypt before upload and manage keys separately from the backup storage.

---

## Interview Angle

**What they're really testing:** Whether you understand RTO/RPO tradeoffs and can design a recovery strategy — not just whether you know the backup commands.

**Common question form:** *"How would you design a backup strategy for a database that can't lose more than 1 hour of data?"* or *"Walk me through how you'd recover from accidental deletion of a production table."*

**The depth signal:** A junior says "take daily backups and store them on S3." A senior defines RTO and RPO first, then maps them to tooling: RPO of 1 hour requires WAL archiving or binlog streaming (not just nightly dumps); RTO of 30 minutes requires physical backups (pg_dump restores are too slow at scale). They describe the full recovery runbook: stop the application, restore the base backup, replay WAL to the target timestamp, verify row counts, bring the application back. They also flag the gap most teams miss: backup verification on a schedule, because a corrupted or incomplete backup discovered during a disaster doubles the incident.

---

## Related Topics

- [[databases/database-monitoring.md]] — Monitoring WAL archiving lag and backup job success/failure is part of the backup strategy.
- [[databases/migrations-strategy.md]] — Schema migrations that go wrong are a common reason to trigger a restore.
- [[devops/deployment-strategies.md]] — Database restore procedures need to coordinate with application deployment rollback.
- [[databases/postgres-vs-sqlserver.md]] — WAL-based PITR is Postgres-native; SQL Server uses a different log shipping and backup chain model.

---

## Source

[PostgreSQL documentation — backup and restore](https://www.postgresql.org/docs/current/backup.html)

---
*Last updated: 2026-03-24*