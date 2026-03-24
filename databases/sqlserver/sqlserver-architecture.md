# SQL Server Architecture

> SQL Server is Microsoft's relational database engine — understanding its architecture means knowing how it moves data between disk, memory, and the query processor to execute a statement.

---

## When To Use It
Understanding SQL Server's architecture matters when diagnosing performance problems, configuring a new instance, or explaining why a query behaves differently under load than in isolation. It's the foundation beneath every tuning decision — buffer pool size, tempdb configuration, wait statistics, and execution plan choices all make more sense once you know how the engine is structured. It's also a common interview topic for senior SQL Server roles and any position involving DBA responsibilities on a Windows or Azure stack.

---

## Core Concept
SQL Server is split into two main engines: the relational engine (query processor) and the storage engine. The relational engine parses, compiles, and optimizes queries — producing an execution plan. The storage engine executes that plan by reading and writing data through the buffer pool, which is SQL Server's in-memory page cache. Data lives on disk in data files (.mdf, .ndf) organized into 8KB pages. Logs live in transaction log files (.ldf) written sequentially. Every write goes to the log first (write-ahead logging) before the data page is modified in the buffer pool — durability is guaranteed by the log, not by immediately flushing data pages to disk. TempDB is a shared system database used for intermediate results, sort spills, row versioning, and temporary tables — it's one of the most common performance bottlenecks on a busy instance.

---

## The Code

**Inspect SQL Server version and edition**
```sql
SELECT 
    @@VERSION                           AS full_version,
    SERVERPROPERTY('Edition')           AS edition,
    SERVERPROPERTY('ProductVersion')    AS version,
    SERVERPROPERTY('ProductLevel')      AS patch_level,
    SERVERPROPERTY('EngineEdition')     AS engine_edition;
-- EngineEdition 5 = Azure SQL Database
-- EngineEdition 8 = Azure SQL Managed Instance
```

**Buffer pool — how much memory SQL Server is using**
```sql
-- Total buffer pool usage by database
SELECT
    DB_NAME(database_id)        AS database_name,
    COUNT(*) * 8 / 1024         AS size_mb,
    COUNT(*)                    AS page_count
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY size_mb DESC;

-- Max server memory setting
SELECT name, value_in_use
FROM sys.configurations
WHERE name = 'max server memory (MB)';
```

**Page and extent structure**
```sql
-- SQL Server stores data in 8KB pages, grouped into 64KB extents (8 pages)
-- Uniform extents: owned by one object
-- Mixed extents: shared across multiple small objects

-- View page-level info for a table (requires DBCC)
DBCC IND('YourDatabase', 'dbo.orders', -1);
-- Shows page types: data pages (1), index pages (2), IAM pages (10)

-- Inspect a specific page (advanced — for diagnostics only)
DBCC PAGE('YourDatabase', 1, 312, 3) WITH TABLERESULTS;
-- Args: database, file_id, page_id, output_style
```

**Transaction log — write-ahead logging**
```sql
-- View log file usage
DBCC SQLPERF(LOGSPACE);

-- More detailed log info per database
SELECT
    name                    AS database_name,
    log_size_mb             = size * 8.0 / 1024,
    log_used_mb             = FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024,
    recovery_model_desc
FROM sys.databases
ORDER BY log_size_mb DESC;

-- View active virtual log files (VLFs)
-- High VLF count (>1000) degrades log performance
DBCC LOGINFO;
```

**TempDB — shared workspace**
```sql
-- TempDB usage by session
SELECT
    s.session_id,
    s.login_name,
    t.user_object_reserved_page_count * 8   AS user_obj_kb,
    t.internal_object_reserved_page_count * 8 AS internal_obj_kb,
    t.version_store_reserved_page_count * 8   AS version_store_kb
FROM sys.dm_db_session_space_usage t
JOIN sys.dm_exec_sessions s ON s.session_id = t.session_id
WHERE t.user_object_reserved_page_count + t.internal_object_reserved_page_count > 0
ORDER BY (t.user_object_reserved_page_count + t.internal_object_reserved_page_count) DESC;

-- TempDB file layout — should have one file per logical CPU (up to 8)
SELECT name, physical_name, size * 8 / 1024 AS size_mb
FROM tempdb.sys.database_files;
```

**Wait statistics — what SQL Server is waiting for**
```sql
-- Top wait types since last restart (or since stats were cleared)
SELECT TOP 15
    wait_type,
    waiting_tasks_count,
    wait_time_ms / 1000.0               AS wait_time_sec,
    max_wait_time_ms / 1000.0           AS max_wait_sec,
    signal_wait_time_ms / 1000.0        AS signal_wait_sec,
    -- Signal wait = time waiting for CPU after lock released
    -- High signal waits = CPU pressure
    (wait_time_ms - signal_wait_time_ms) / 1000.0 AS resource_wait_sec
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (  -- exclude benign background waits
    'SLEEP_TASK', 'BROKER_TO_FLUSH', 'BROKER_TASK_STOP',
    'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
    'FT_IFTS_SCHEDULER_IDLE_WAIT', 'HADR_WORK_QUEUE',
    'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'XE_DISPATCHER_WAIT',
    'XE_TIMER_EVENT', 'SLEEP_DBSTARTUP', 'SLEEP_DBRECOVER'
)
ORDER BY wait_time_ms DESC;
```

**Plan cache — reused execution plans**
```sql
-- Most executed plans in cache
SELECT TOP 10
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count  AS avg_logical_reads,
    qs.total_elapsed_time / qs.execution_count   AS avg_elapsed_us,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset END
        - qs.statement_start_offset)/2)+1)       AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.execution_count DESC;

-- Plan cache size
SELECT
    COUNT(*)                AS cached_plans,
    SUM(size_in_bytes)/1024/1024 AS cache_size_mb
FROM sys.dm_exec_cached_plans;
```

**Memory-optimized tables (In-Memory OLTP)**
```sql
-- Requires a MEMORY_OPTIMIZED_DATA filegroup
ALTER DATABASE YourDatabase
ADD FILEGROUP mem_fg CONTAINS MEMORY_OPTIMIZED_DATA;

ALTER DATABASE YourDatabase
ADD FILE (NAME='mem_data', FILENAME='C:\data\mem_data')
TO FILEGROUP mem_fg;

-- Create a memory-optimized table
CREATE TABLE hot_sessions (
    session_id  INT NOT NULL PRIMARY KEY NONCLUSTERED,
    user_id     INT NOT NULL,
    data        NVARCHAR(1000),
    created_at  DATETIME2 NOT NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
-- SCHEMA_ONLY: survives restart without data (cache use case)
-- SCHEMA_AND_DATA: fully durable
```

---

## Gotchas

- **TempDB contention is the most common overlooked bottleneck** — every sort spill, hash join spill, temp table, table variable, row version, and cursor uses TempDB. On a busy instance with one TempDB data file, allocation bitmap contention (PAGELATCH_UP wait on pages 2, 3) causes serialization. The fix is multiple TempDB data files — one per logical CPU up to 8. SQL Server 2016+ does this automatically during setup if you choose the right option.
- **Max server memory default is unlimited — set it explicitly** — out of the box, SQL Server will consume all available RAM, leaving the OS starved. Always set `max server memory` to leave 10–20% of RAM for the OS and other processes. Forgetting this causes Windows to page SQL Server out, which looks like random severe slowdowns.
- **VLF fragmentation degrades log performance** — if a transaction log grows in many small auto-growth increments, it accumulates hundreds or thousands of Virtual Log Files (VLFs). High VLF counts slow log backups, database restores, and crash recovery. Pre-size the log file appropriately and grow it in large increments to keep VLF count low. Check with `DBCC LOGINFO`.
- **Plan cache bloat from ad-hoc queries** — unparameterized queries each produce a separate cached plan. On a high-traffic system this bloats the plan cache, triggers frequent cache evictions, and wastes memory. Enable `Optimize for Ad Hoc Workloads` to store only a plan stub on first execution — full plan only cached after second execution.
- **Signal wait time reveals CPU pressure, not lock pressure** — a high `signal_wait_time_ms` in `sys.dm_os_wait_stats` means threads are waiting for CPU time after their resource wait is satisfied. This is CPU pressure, not a blocking or locking problem. Tuning indexes won't fix it — the server needs more CPU or fewer concurrent queries.

---

## Interview Angle
**What they're really testing:** Whether you can reason about SQL Server performance at the engine level — buffer pool, TempDB, wait statistics, and write-ahead logging — not just whether you can write T-SQL.

**Common question form:** "Walk me through what happens when SQL Server executes a SELECT query" or "How would you diagnose a SQL Server performance problem you've never seen before?"

**The depth signal:** A junior describes tables, indexes, and execution plans. A senior traces the full path: parser → algebrizer → optimizer → plan cache check → storage engine → buffer pool → disk (if page not in cache) → write-ahead log for any modifications. They start performance diagnosis with wait statistics (`sys.dm_os_wait_stats`), not with slow query reports, because wait stats reveal the bottleneck category before drilling into specific queries. They know TempDB contention by the PAGELATCH_UP wait type, know that max server memory must be set manually, and understand that signal wait time means CPU pressure — not lock contention.

---

## Related Topics
- [[databases/sql-execution-plans.md]] — the query optimizer produces execution plans; understanding the engine explains why plans change
- [[databases/sql-locking-blocking.md]] — SQL Server's lock manager sits inside the storage engine; wait stats surface blocking directly
- [[databases/sql-transactions.md]] — write-ahead logging and recovery model determine how transactions are durable
- [[databases/sql-indexing.md]] — indexes are B-tree structures stored in the same 8KB page format as data; understanding pages explains index internals

---

## Source
https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-architecture

---
*Last updated: 2026-03-24*