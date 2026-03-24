# SQL Server Columnstore Indexes

> A columnstore index stores data column-by-column instead of row-by-row, enabling highly compressed storage and vectorized batch processing that makes analytical queries orders of magnitude faster than row-based indexes.

---

## When To Use It
Use columnstore indexes on large tables that are queried analytically — aggregations, range scans, and GROUP BY across millions of rows. They're the primary tool for making OLAP workloads fast on SQL Server without a separate data warehouse. Non-clustered columnstore indexes on OLTP tables can speed up reporting queries without changing the primary storage structure. Avoid columnstore as the primary index on tables with frequent single-row lookups, point updates, or heavy single-row INSERT/UPDATE/DELETE patterns — row-based indexes handle these better.

---

## Core Concept
A standard rowstore index stores each row contiguously — all columns of row 1, then all columns of row 2. A columnstore stores each column contiguously — all values of column 1, then all values of column 2. When a query touches three columns out of thirty, a columnstore reads only those three columns off disk instead of loading all thirty. Columns also compress dramatically — similar values stored together achieve 5–10x compression ratios. The query engine processes columnstore data in batches of ~900 rows using SIMD CPU instructions (batch mode execution) instead of row-by-row, which reduces CPU overhead by another order of magnitude. The tradeoff: row-level modifications are expensive because they must be translated from row format to column format via a delta store.

---

## The Code

**Create a clustered columnstore index (replaces the rowstore heap/clustered index)**
```sql
-- Full table stored in columnstore format
-- Best for pure analytics tables with no frequent point lookups
CREATE CLUSTERED COLUMNSTORE INDEX cci_sales
ON sales_fact;

-- With order hint (SQL Server 2022+) — improves segment elimination
CREATE CLUSTERED COLUMNSTORE INDEX cci_sales
ON sales_fact
ORDER (sale_date, region_id);
-- Rows sorted by these columns before compression — drastically improves
-- skip-segment performance for date/region range filters
```

**Create a non-clustered columnstore index (keeps the rowstore, adds columnstore)**
```sql
-- Rowstore clustered index remains — point lookups still work
-- Columnstore added for analytical queries
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_orders_analytics
ON orders (order_date, customer_id, product_id, total_amount, status);

-- Analytical query now uses the columnstore
SELECT
    customer_id,
    YEAR(order_date)    AS year,
    SUM(total_amount)   AS revenue,
    COUNT(*)            AS order_count
FROM orders
WHERE status = 'completed'
GROUP BY customer_id, YEAR(order_date);
```

**Check columnstore index metadata**
```sql
-- Row groups: the unit of columnstore storage (~1M rows each)
SELECT
    OBJECT_NAME(i.object_id)        AS table_name,
    i.name                          AS index_name,
    rg.row_group_id,
    rg.state_desc,                  -- COMPRESSED, OPEN, CLOSED, TOMBSTONE
    rg.total_rows,
    rg.deleted_rows,
    rg.size_in_bytes / 1024 / 1024  AS size_mb,
    rg.created_time
FROM sys.column_store_row_groups rg
JOIN sys.indexes i ON i.object_id = rg.object_id
    AND i.index_id = rg.index_id
WHERE OBJECT_NAME(i.object_id) = 'sales_fact'
ORDER BY rg.row_group_id;
```

**Check delta store — buffered uncompressed rows**
```sql
-- Delta store holds recent inserts before they're compressed into row groups
-- Large delta stores mean recent data isn't benefiting from columnstore compression
SELECT
    OBJECT_NAME(object_id)          AS table_name,
    index_id,
    delta_store_hobt_id,
    state_desc,                     -- OPEN = accepting inserts
    total_rows,
    deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE OBJECT_NAME(object_id) = 'sales_fact'
  AND state_desc = 'OPEN';
```

**Force delta store compression (reorganize)**
```sql
-- Moves CLOSED delta store rows into compressed row groups
ALTER INDEX cci_sales ON sales_fact REORGANIZE
WITH (COMPRESS_ALL_ROW_GROUPS = ON);

-- Full rebuild — recompresses all row groups, removes deleted rows
ALTER INDEX cci_sales ON sales_fact REBUILD;
-- REBUILD is offline by default — use ONLINE = ON for live tables
ALTER INDEX cci_sales ON sales_fact REBUILD WITH (ONLINE = ON);
```

**Verify batch mode execution in a query plan**
```sql
-- Check execution mode for analytical query
SET STATISTICS IO ON;

EXPLAIN -- or view actual execution plan in SSMS
SELECT
    region_id,
    SUM(sale_amount) AS total,
    COUNT(*)         AS transactions
FROM sales_fact
WHERE sale_date >= '2024-01-01'
GROUP BY region_id;

-- In SSMS execution plan: look for "Actual Execution Mode = Batch"
-- Batch mode = columnstore optimized
-- Row mode = not using batch processing
```

**Updateable clustered columnstore (SQL Server 2014+)**
```sql
-- Clustered columnstore indexes are fully updateable
INSERT INTO sales_fact (sale_date, region_id, sale_amount)
VALUES ('2024-03-24', 5, 149.99);
-- Row goes to delta store (OPEN row group), not directly into compressed segment

UPDATE sales_fact SET sale_amount = 159.99
WHERE sale_id = 12345;
-- Marks original row as deleted in compressed segment
-- Inserts updated row into delta store

DELETE FROM sales_fact WHERE sale_date < '2020-01-01';
-- Marks rows as logically deleted — physical space reclaimed on next REBUILD
```

**Segment elimination — the performance multiplier**
```sql
-- Columnstore stores min/max metadata per segment per column
-- Queries with range filters skip segments entirely without reading them

-- This filter can eliminate most segments if sale_date values are ordered
SELECT SUM(sale_amount) FROM sales_fact
WHERE sale_date BETWEEN '2024-01-01' AND '2024-03-31';

-- Check how many segments were eliminated
SELECT
    OBJECT_NAME(object_id)  AS table_name,
    index_id,
    segments_scanned,
    segments_eliminated     -- higher = more segments skipped = faster
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
-- Or observe in SSMS plan: "Segment Groups Eliminated" in CCI scan operator
```

---

## Gotchas

- **Delta store rows are not compressed and don't benefit from batch mode** — recent inserts sit in the delta store until a background tuple mover compresses them (threshold: ~1M rows or after a while). Queries against very recent data hit the delta store in row mode, not batch mode. For time-sensitive analytics on fresh data, run `REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON)` as part of your ETL.
- **Deleted rows waste space until REBUILD** — DELETE and UPDATE mark rows as deleted but don't reclaim space immediately. A table with 30% deleted rows is still reading those segments from disk and filtering them out. `ALTER INDEX REBUILD` physically removes them. Monitor `deleted_rows` in `sys.column_store_row_groups` and schedule periodic rebuilds for heavily modified tables.
- **Non-clustered columnstore indexes conflict with some DML on SQL Server 2012–2014** — older versions required the table to be read-only to have a non-clustered columnstore index. SQL Server 2016+ removed this restriction. On legacy versions, the pattern was to drop the columnstore, do the bulk load, and recreate it.
- **Segment elimination only works when data is naturally ordered** — min/max metadata per segment is only useful for skipping segments if the values within each segment are tightly bounded. A columnstore built on randomly inserted rows has wide min/max ranges per segment — elimination rarely fires. The `ORDER` clause on clustered columnstore (SQL Server 2022) or sorting data before bulk load fixes this.
- **Batch mode requires a columnstore index to be present — even on rowstore tables** — SQL Server 2019 introduced batch mode on rowstore, but prior versions only use batch mode when a columnstore index (even a non-clustered one) exists on the table. Adding a dummy non-clustered columnstore index on a rowstore table solely to enable batch mode for complex analytical queries is a documented and legitimate technique.

---

## Interview Angle
**What they're really testing:** Whether you understand why columnstore is fast — column storage, compression, and batch mode — not just that it exists and is used for analytics.

**Common question form:** "How would you speed up a slow reporting query on a large SQL Server table?" or "What's the difference between a rowstore and a columnstore index?"

**The depth signal:** A junior says columnstore is faster for analytics and good for data warehouses. A senior explains column projection (only reading touched columns), compression ratios from homogeneous column data, batch mode execution using SIMD, and segment elimination via min/max metadata. They know the delta store exists for recent inserts and that it bypasses batch mode until compressed, know that deleted rows aren't physically removed until REBUILD, and understand that segment elimination is only effective when data is loaded in order — leading to the ORDER clause or pre-sorted bulk load technique. Knowing that a dummy non-clustered columnstore index enables batch mode on rowstore tables in pre-2019 versions is a strong senior differentiator.

---

## Related Topics
- [[databases/sql-indexing.md]] — columnstore is an index type; understanding B-tree rowstore indexes provides the contrast
- [[databases/sql-execution-plans.md]] — batch mode vs row mode is visible in execution plans; reading plans is how you confirm columnstore is being used
- [[databases/sqlserver-architecture.md]] — buffer pool, TempDB spills, and memory grant behavior all interact with columnstore query execution
- [[databases/sql-query-optimization.md]] — columnstore is one of the most impactful optimizations for analytical queries; fits into the broader optimization workflow

---

## Source
https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview

---
*Last updated: 2026-03-24*