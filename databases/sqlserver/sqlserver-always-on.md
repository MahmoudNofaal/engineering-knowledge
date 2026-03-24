# SQL Server Always On Availability Groups

> Always On Availability Groups is SQL Server's high-availability and disaster-recovery feature — it replicates one or more databases to secondary replicas that can take over if the primary fails.

---

## When To Use It
Use Always On when you need high availability (automatic failover with near-zero downtime), disaster recovery (a replica in a separate datacenter), or read scale-out (offloading read workloads to secondaries). It's the primary HA solution for SQL Server 2012 and later, replacing the older Database Mirroring feature which is deprecated. Don't use it as a backup strategy — it replicates logical changes including accidental deletes and corruption. You still need independent backups.

---

## Core Concept
An Availability Group (AG) is a named container for one or more user databases that fail over together as a unit. One replica is the primary — it handles all writes. Up to eight secondary replicas receive transaction log records from the primary and apply them. Synchronous replicas acknowledge a transaction only after it's hardened to their log — guaranteeing zero data loss on failover at the cost of write latency. Asynchronous replicas acknowledge immediately — lower latency but potential data loss on failover. The Availability Group Listener is a virtual network name and IP address clients connect to — it routes to the current primary automatically, so applications don't need to know which node is primary.

---

## The Code

**Check current AG status**
```sql
-- Overview of all availability groups on this instance
SELECT
    ag.name                         AS ag_name,
    ar.replica_server_name,
    ar.availability_mode_desc,      -- SYNCHRONOUS_COMMIT or ASYNCHRONOUS_COMMIT
    ar.failover_mode_desc,          -- AUTOMATIC or MANUAL
    ars.role_desc,                  -- PRIMARY or SECONDARY
    ars.operational_state_desc,
    ars.connected_state_desc,
    ars.synchronization_health_desc
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ar.group_id = ag.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ars.replica_id = ar.replica_id
ORDER BY ag.name, ars.role_desc;
```

**Check database synchronization state**
```sql
-- Per-database sync health across all replicas
SELECT
    ag.name                         AS ag_name,
    adc.database_name,
    ar.replica_server_name,
    drs.synchronization_state_desc, -- SYNCHRONIZED, SYNCHRONIZING, NOT SYNCHRONIZING
    drs.synchronization_health_desc,
    drs.log_send_queue_size,        -- KB of log waiting to be sent to this replica
    drs.log_send_rate,              -- KB/sec current send rate
    drs.redo_queue_size,            -- KB of log waiting to be redone on secondary
    drs.redo_rate,                  -- KB/sec current redo rate
    drs.last_commit_time            -- last transaction committed on this replica
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id
JOIN sys.availability_groups ag ON ag.group_id = ar.group_id
JOIN sys.availability_databases_cluster adc ON adc.group_id = ag.group_id
    AND adc.group_database_id = drs.group_database_id
ORDER BY ag.name, adc.database_name, ar.replica_server_name;
```

**Measure replication lag**
```sql
-- Estimated lag between primary and each secondary
SELECT
    ar.replica_server_name,
    drs.log_send_queue_size         AS unsent_log_kb,
    drs.redo_queue_size             AS unapplied_log_kb,
    -- Estimated seconds of data loss if secondary were to fail over now
    CASE WHEN drs.redo_rate > 0
        THEN drs.redo_queue_size / drs.redo_rate
        ELSE NULL
    END                             AS estimated_lag_sec,
    DATEDIFF(SECOND, drs.last_commit_time, primary_drs.last_commit_time)
                                    AS commit_lag_sec
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id
JOIN sys.dm_hadr_database_replica_states primary_drs
    ON primary_drs.group_database_id = drs.group_database_id
    AND primary_drs.is_primary_replica = 1
WHERE drs.is_primary_replica = 0
ORDER BY commit_lag_sec DESC;
```

**Check the listener**
```sql
-- Listener name, IP, and port
SELECT
    ag.name                 AS ag_name,
    agl.dns_name            AS listener_name,
    aglip.ip_address,
    aglip.ip_subnet_mask,
    agl.port
FROM sys.availability_group_listeners agl
JOIN sys.availability_groups ag ON ag.group_id = agl.group_id
JOIN sys.availability_group_listener_ip_addresses aglip
    ON aglip.listener_id = agl.listener_id;
```

**Read-only routing — send reads to secondary**
```sql
-- Configure a replica to accept read-intent connections
ALTER AVAILABILITY GROUP [AG_Production]
MODIFY REPLICA ON 'SQL-Secondary-01'
WITH (SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY));

-- Configure read-only routing list on the primary
ALTER AVAILABILITY GROUP [AG_Production]
MODIFY REPLICA ON 'SQL-Primary-01'
WITH (PRIMARY_ROLE (READ_ONLY_ROUTING_LIST = ('SQL-Secondary-01')));

-- Client connection string must include ApplicationIntent=ReadOnly
-- and connect via the listener name for routing to work
-- ConnectionString: Server=AG_Listener;Database=MyDB;ApplicationIntent=ReadOnly
```

**Manual failover (planned — no data loss)**
```sql
-- Run on the target secondary you want to promote
ALTER AVAILABILITY GROUP [AG_Production] FAILOVER;

-- Verify new primary
SELECT
    ar.replica_server_name,
    ars.role_desc
FROM sys.availability_replicas ar
JOIN sys.dm_hadr_availability_replica_states ars ON ars.replica_id = ar.replica_id
WHERE ar.group_id = (
    SELECT group_id FROM sys.availability_groups WHERE name = 'AG_Production'
);
```

**Forced failover (unplanned — potential data loss)**
```sql
-- Use only when primary is unavailable and data loss is acceptable
-- Run on the target secondary
ALTER AVAILABILITY GROUP [AG_Production] FORCE_FAILOVER_ALLOW_DATA_LOSS;

-- After forcing, rejoin the old primary when it comes back
-- (it will come up as a secondary in a SUSPENDED state)
ALTER DATABASE YourDatabase SET HADR RESUME;
```

**Monitoring AG health with Extended Events or alerts**
```sql
-- Check for recent AG health events in the SQL Server error log
EXEC xp_readerrorlog 0, 1, 'availability', NULL, NULL, NULL, 'DESC';

-- AG-specific error numbers to alert on:
-- 35264: AG data movement suspended
-- 35265: AG data movement resumed
-- 1480:  Role change (primary/secondary transition)
-- 19406: Replica state change
```

---

## Gotchas

- **Synchronous commit adds write latency proportional to network RTT** — every transaction on the primary waits for acknowledgement from all synchronous secondaries before committing. A secondary 50ms away adds at minimum 50ms to every write. Measure your network latency before choosing synchronous mode for a geographically distant DR replica — the write latency impact on the primary can be severe.
- **The listener requires Windows Server Failover Clustering (WSFC) for automatic failover** — without a WSFC cluster, you can have an AG but failover must be manual. In Azure, use an Internal Load Balancer (ILB) in place of the traditional WSFC listener. Forgetting the ILB configuration is the most common reason Azure AG listeners don't work.
- **Readable secondaries use row versioning, which bloats TempDB on the primary** — when a secondary is configured for read access, the primary must maintain row versions in TempDB to provide read-consistent snapshots to the secondary's queries. High read workloads on the secondary generate heavy version store activity on the primary's TempDB. Monitor `version_store_reserved_page_count` in `sys.dm_db_session_space_usage`.
- **Forced failover leaves the AG in a split-brain-ready state** — after `FORCE_FAILOVER_ALLOW_DATA_LOSS`, the old primary comes back as a secondary with diverged transaction log. You must manually rejoin it and accept that its unconfirmed transactions are gone. Skipping the rejoin step leaves the AG in a partially broken state that looks healthy in monitoring but isn't.
- **Backup jobs must account for replica role** — if you run backups on the secondary to offload the primary, your backup job must check the current role and skip execution when it's running on the primary (or vice versa). A common mistake is deploying the same backup job to all replicas without role-awareness, resulting in no backups when the replica that runs the job becomes primary after a failover.

---

## Interview Angle
**What they're really testing:** Whether you understand the tradeoffs between synchronous and asynchronous replication, and whether you've operated an AG under real failure conditions — not just set one up in a lab.

**Common question form:** "What's the difference between synchronous and asynchronous commit in Always On?" or "Walk me through what happens during an automatic failover."

**The depth signal:** A junior knows Always On provides HA and that there are primary and secondary replicas. A senior explains that synchronous commit is zero data loss but adds network RTT to write latency, knows that the listener routes clients transparently but requires WSFC or ILB in Azure, understands that readable secondaries generate version store pressure on TempDB of the primary, and knows that forced failover leaves diverged log that must be manually reconciled. They also know that backup jobs need role-awareness and that replication lag is measurable via `redo_queue_size` and `last_commit_time` delta.

---

## Related Topics
- [[databases/sqlserver-architecture.md]] — TempDB version store pressure from readable secondaries connects directly to engine internals
- [[databases/sql-transactions.md]] — synchronous commit waits for log hardening on secondaries; understanding WAL explains why
- [[databases/sql-locking-blocking.md]] — failover clears all active connections and in-flight transactions; understanding lock behavior at failover matters
- [[databases/sql-execution-plans.md]] — execution plans cached on the primary are not transferred to the secondary after failover; plan cache is cold on the new primary

---

## Source
https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/overview-of-always-on-availability-groups-sql-server

---
*Last updated: 2026-03-24*