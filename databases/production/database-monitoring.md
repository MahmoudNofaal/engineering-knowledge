# Database Monitoring

> The set of metrics, queries, and alerting rules that tell you whether your database is healthy, where it's slow, and what's about to break before it actually does.

---

## When To Use It

Set up database monitoring before your first production deployment — not after the first incident. The metrics here cover the signals that matter: query performance, lock contention, connection pool saturation, replication lag, and disk growth. Monitoring without alerting is a dashboard you look at after something breaks. Alerting without clear thresholds produces noise that trains you to ignore alerts. Both are failure modes.

---

## Core Concept

Database monitoring has three layers: infrastructure (disk, CPU, memory, network), database internals (connections, locks, cache hit rate, replication lag), and query performance (slow queries, missing indexes, sequential scans). Infrastructure metrics come from your host or cloud provider. Database internals come from system catalog views built into the database. Query performance comes from the slow query log or `pg_stat_statements`. Each layer catches different failure modes — an infrastructure alert tells you the disk is full; a query alert tells you a deployment introduced a missing index before users notice.

---

## The Code

**Postgres — key system views**
```sql
-- Active connections and their state
SELECT pid,
       usename,
       application_name,
       state,                          -- active, idle, idle in transaction
       wait_event_type,
       wait_event,
       now() - query_start AS duration,
       left(query, 100)    AS query
FROM   pg_stat_activity
WHERE  state != 'idle'
ORDER  BY duration DESC;

-- Connections by state — quick health check
SELECT state, COUNT(*)
FROM   pg_stat_activity
GROUP  BY state;

-- Total connections vs max_connections
SELECT COUNT(*)                        AS total_connections,
       max_conn.setting::int           AS max_connections,
       ROUND(COUNT(*) * 100.0 /
             max_conn.setting::int, 1) AS pct_used
FROM   pg_stat_activity,
       (SELECT setting FROM pg_settings WHERE name = 'max_connections') max_conn
GROUP  BY max_conn.setting;
```

**Postgres — slow queries with pg_stat_statements**
```sql
-- Must be enabled: shared_preload_libraries = 'pg_stat_statements'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 slowest queries by total time
SELECT LEFT(query, 80)                             AS query,
       calls,
       ROUND(total_exec_time::numeric, 2)          AS total_ms,
       ROUND(mean_exec_time::numeric, 2)           AS avg_ms,
       ROUND(stddev_exec_time::numeric, 2)         AS stddev_ms,
       rows
FROM   pg_stat_statements
ORDER  BY total_exec_time DESC
LIMIT  10;

-- Queries with high variance — inconsistent performance
SELECT LEFT(query, 80)                      AS query,
       calls,
       ROUND(mean_exec_time::numeric, 2)    AS avg_ms,
       ROUND(stddev_exec_time::numeric, 2)  AS stddev_ms,
       ROUND(stddev_exec_time /
             NULLIF(mean_exec_time, 0), 2)  AS cv   -- coefficient of variation
FROM   pg_stat_statements
WHERE  calls > 100
ORDER  BY cv DESC
LIMIT  10;

-- Reset stats (do after deploying fixes)
SELECT pg_stat_statements_reset();
```

**Postgres — lock monitoring**
```sql
-- Blocked queries and what's blocking them
SELECT blocked.pid                    AS blocked_pid,
       blocked.query                  AS blocked_query,
       blocking.pid                   AS blocking_pid,
       blocking.query                 AS blocking_query,
       now() - blocked.query_start    AS blocked_duration
FROM   pg_stat_activity blocked
JOIN   pg_stat_activity blocking
       ON  blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE  cardinality(pg_blocking_pids(blocked.pid)) > 0;

-- Long-running transactions (common source of lock buildup)
SELECT pid,
       usename,
       now() - xact_start AS txn_duration,
       state,
       LEFT(query, 100)   AS query
FROM   pg_stat_activity
WHERE  xact_start IS NOT NULL
  AND  now() - xact_start > INTERVAL '1 minute'
ORDER  BY txn_duration DESC;

-- Kill a stuck query (use carefully)
SELECT pg_cancel_backend(pid);   -- sends SIGINT — query cancels gracefully
SELECT pg_terminate_backend(pid); -- sends SIGTERM — connection drops
```

**Postgres — index and table health**
```sql
-- Tables with sequential scans — missing index candidates
SELECT schemaname,
       relname                          AS table,
       seq_scan,
       seq_tup_read,
       idx_scan,
       ROUND(seq_scan * 100.0 /
             NULLIF(seq_scan + idx_scan, 0), 1) AS seq_scan_pct
FROM   pg_stat_user_tables
WHERE  seq_scan > 0
ORDER  BY seq_tup_read DESC
LIMIT  20;

-- Unused indexes — wasting write overhead and storage
SELECT schemaname,
       relname    AS table,
       indexrelname AS index,
       idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM   pg_stat_user_indexes
WHERE  idx_scan = 0
  AND  indexrelid NOT IN (
       SELECT conindid FROM pg_constraint   -- exclude PK/FK constraints
  )
ORDER  BY pg_relation_size(indexrelid) DESC;

-- Cache hit rate — should be > 99% in production
SELECT SUM(heap_blks_hit) * 100.0 /
       NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0) AS cache_hit_pct
FROM   pg_statio_user_tables;

-- Table bloat — dead tuple accumulation (VACUUM health)
SELECT relname               AS table,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup * 100.0 /
             NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum,
       last_autoanalyze
FROM   pg_stat_user_tables
ORDER  BY n_dead_tup DESC
LIMIT  20;

-- Table and index sizes
SELECT relname                              AS name,
       pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
       pg_size_pretty(pg_relation_size(oid))       AS table_size,
       pg_size_pretty(pg_indexes_size(oid))        AS index_size
FROM   pg_class
WHERE  relkind = 'r'
  AND  relnamespace = 'public'::regnamespace
ORDER  BY pg_total_relation_size(oid) DESC
LIMIT  20;
```

**Postgres — replication lag**
```sql
-- On primary: replication status and lag per replica
SELECT client_addr,
       state,
       sent_lsn,
       write_lsn,
       flush_lsn,
       replay_lsn,
       write_lag,
       flush_lag,
       replay_lag                          -- how far behind the replica is
FROM   pg_stat_replication
ORDER  BY replay_lag DESC NULLS LAST;

-- On replica: how far behind am I?
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;
```

**Alerting thresholds — what to page on**
```python
# These are reasonable starting thresholds — tune to your workload

ALERT_RULES = {
    # Connections
    "connection_usage_pct":   {"warn": 70, "critical": 90},

    # Replication
    "replication_lag_seconds": {"warn": 30, "critical": 120},

    # Query performance
    "slow_query_pct_above_1s": {"warn": 5,  "critical": 20},  # % of queries > 1s

    # Locks
    "blocked_queries":         {"warn": 1,  "critical": 5},
    "lock_wait_seconds":       {"warn": 10, "critical": 30},

    # Storage
    "disk_usage_pct":          {"warn": 75, "critical": 90},

    # Cache
    "cache_hit_pct_below":     {"warn": 98, "critical": 95},  # alert if it drops below

    # Bloat
    "dead_tuple_pct":          {"warn": 10, "critical": 25},
}
```

**Prometheus + postgres_exporter setup**
```yaml
# docker-compose.yml
services:
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://monitor_user:pass@postgres:5432/mydb?sslmode=disable"
    ports:
      - "9187:9187"

# prometheus.yml scrape config
scrape_configs:
  - job_name: "postgres"
    static_configs:
      - targets: ["postgres-exporter:9187"]

# Key metrics exposed by postgres_exporter:
# pg_stat_activity_count{state="active"}          — active connections
# pg_stat_activity_count{state="idle in transaction"} — dangerous idle txns
# pg_stat_replication_pg_wal_lsn_diff            — replication lag in bytes
# pg_stat_user_tables_seq_scan                   — sequential scan count
# pg_stat_bgwriter_buffers_clean                 — background writer activity
# pg_database_size_bytes                         — database size
```

**Grafana dashboard — key panels**
```
Panels to build (in order of importance):

1. Active connections / max_connections (%)
2. Replication lag (seconds) per replica
3. Query throughput (queries/sec from pg_stat_statements)
4. p50 / p95 / p99 query latency
5. Cache hit rate (%)
6. Top 10 slow queries (table from pg_stat_statements)
7. Locks — blocked query count
8. Dead tuple % per table (top 10)
9. Database size growth over time
10. Disk I/O — read vs write bytes/sec
```

---

## Gotchas

- **`pg_stat_statements` is off by default and requires a server restart to enable.** Add `shared_preload_libraries = 'pg_stat_statements'` to `postgresql.conf` and restart. Without it, you have no query-level performance visibility. Enable it before you go to production, not after your first incident.
- **`idle in transaction` connections are more dangerous than active ones.** A connection in `idle in transaction` holds locks and blocks VACUUM from cleaning dead tuples. Alert on count > 0 for transactions idle longer than 30 seconds. The root cause is almost always application code that starts a transaction and then does external I/O before committing.
- **Unused index detection resets on server restart.** `pg_stat_user_indexes.idx_scan` resets to 0 on restart. Don't drop an index just because `idx_scan = 0` after a recent restart — wait for a full traffic cycle (at least one week of normal load) before concluding an index is unused.
- **Replication lag in bytes (`pg_stat_replication`) and in time (`pg_last_xact_replay_timestamp`) measure different things.** Byte lag tells you how much WAL hasn't been replayed. Time lag tells you how stale the replica's data is. A replica can have high byte lag but low time lag (burst of writes that replayed quickly) or low byte lag but high time lag (replica is stuck and not replaying). Monitor both.
- **Autovacuum can be silently blocked by long-running transactions.** If a transaction has been open for hours, autovacuum can't reclaim dead tuples older than that transaction's snapshot. The `n_dead_tup` count climbs, table bloat grows, and queries slow down — all tracing back to one idle-in-transaction session. This is why long transaction alerting is critical, not optional.

---

## Interview Angle

**What they're really testing:** Whether you proactively think about observability and can diagnose performance problems from first principles rather than guessing.

**Common question form:** *"Your database is slow — how do you find the cause?"* or *"How would you set up monitoring for a new Postgres database?"* or *"What metrics matter most for database health?"*

**The depth signal:** A junior says "look at CPU usage and slow query log." A senior has a structured investigation: check `pg_stat_activity` for blocked queries and idle-in-transaction sessions first (the most common cause of sudden slowdowns), then `pg_stat_statements` for queries that regressed (sorted by mean time, not total time, to catch newly introduced bad queries), then `pg_stat_user_tables` for sequential scans on tables that should be using indexes. They also know the feedback loops: a missing index causes seq scans which cause high I/O which causes cache eviction which makes everything slower — and that the fix (adding the index) requires `CONCURRENTLY` to avoid making the incident worse.

---

## Related Topics

- [[databases/connection-pooling.md]] — Pool checkout wait time and connection count are the first metrics to check under load.
- [[databases/migrations-strategy.md]] — Migrations are a common source of lock contention and replication lag spikes; monitor during deployments.
- [[databases/postgres-full-text-search.md]] — Sequential scans on text columns are often the signal that FTS indexes are missing or misconfigured.
- [[databases/indexing-strategies.md]] — Sequential scan alerts in monitoring lead directly to index analysis.

---

## Source

[PostgreSQL documentation — monitoring database activity](https://www.postgresql.org/docs/current/monitoring-stats.html)

---
*Last updated: 2026-03-24*