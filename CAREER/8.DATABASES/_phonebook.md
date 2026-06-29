# Domain 8 — Databases

## Phonebook — Part 1 of 2 (Topics 8.001 – 8.430)

**1,000 topics across 34 groups.** Priority 1 = Critical → Priority 4 = Reference | `[ ]` = not generated | `[x]` = generated

---

## Group A — Relational Database Fundamentals (8.001–8.030)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.001|The Relational Model — Relations, Tuples, Attributes|1|[ ]|
|8.002|Keys — Primary, Foreign, Candidate, Surrogate, Natural|1|[ ]|
|8.003|Referential Integrity — Cascade Behaviors|1|[ ]|
|8.004|ACID — Atomicity|1|[ ]|
|8.005|ACID — Consistency|1|[ ]|
|8.006|ACID — Isolation|1|[ ]|
|8.007|ACID — Durability|1|[ ]|
|8.008|NULL — Three-Valued Logic and Implications|1|[ ]|
|8.009|Data Types — Choosing the Right Type|2|[ ]|
|8.010|Schema Design — Tables, Columns, Constraints|2|[ ]|
|8.011|CHECK Constraints — Enforcing Business Rules|2|[ ]|
|8.012|UNIQUE Constraints — Alternate Keys|2|[ ]|
|8.013|DEFAULT Values — Column-Level Defaults|3|[ ]|
|8.014|Entity-Relationship Modeling — Conceptual Design|2|[ ]|
|8.015|Cardinality — One-to-One, One-to-Many, Many-to-Many|1|[ ]|
|8.016|Relational Algebra — Select, Project, Join|2|[ ]|
|8.017|OLTP vs OLAP — Different Optimization Targets|1|[ ]|
|8.018|SQL Standards — ANSI SQL vs T-SQL vs PL/pgSQL|2|[ ]|
|8.019|Table Heap vs Clustered Table|1|[ ]|
|8.020|Row Storage vs Column Storage|2|[ ]|
|8.021|In-Memory Tables — OLTP Concepts|3|[ ]|
|8.022|Database Catalog — System Tables and Views|2|[ ]|
|8.023|Statistics — How the Optimizer Uses Them|1|[ ]|
|8.024|Database Engine Architecture — Parser, Optimizer, Executor|2|[ ]|
|8.025|Buffer Pool — Page Management|2|[ ]|
|8.026|Write-Ahead Logging — Durability Mechanism|1|[ ]|
|8.027|BASE — Basically Available, Soft State, Eventually Consistent|2|[ ]|
|8.028|Domain Integrity — Valid Value Constraints|3|[ ]|
|8.029|Entity Integrity — Primary Key Rules|2|[ ]|
|8.030|Relational Model vs Document Model — Decision|2|[ ]|

---

## Group B — Database Design & Normalization (8.031–8.065)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.031|First Normal Form (1NF) — Eliminating Repeating Groups|1|[ ]|
|8.032|Second Normal Form (2NF) — Eliminating Partial Dependencies|1|[ ]|
|8.033|Third Normal Form (3NF) — Eliminating Transitive Dependencies|1|[ ]|
|8.034|Boyce-Codd Normal Form (BCNF)|2|[ ]|
|8.035|Fourth Normal Form (4NF) — Multivalued Dependencies|3|[ ]|
|8.036|Fifth Normal Form (5NF) — Join Dependencies|4|[ ]|
|8.037|Denormalization — When and Why|1|[ ]|
|8.038|Star Schema — Fact and Dimension Tables|2|[ ]|
|8.039|Snowflake Schema — Normalized Dimensions|2|[ ]|
|8.040|Data Vault — Hub, Link, Satellite|3|[ ]|
|8.041|Wide Tables vs Narrow Tables — Tradeoffs|2|[ ]|
|8.042|Surrogate Keys vs Natural Keys — Decision|1|[ ]|
|8.043|UUID vs Sequential ID — Performance Implications|1|[ ]|
|8.044|ULID — Ordered UUID Alternative|2|[ ]|
|8.045|Composite Primary Keys — When to Use|2|[ ]|
|8.046|Relationship Tables — Many-to-Many Implementation|2|[ ]|
|8.047|Self-Referential Tables — Hierarchical Data|2|[ ]|
|8.048|Soft Delete — IsDeleted Pattern|2|[ ]|
|8.049|Audit Columns — CreatedAt, CreatedBy, ModifiedAt, ModifiedBy|2|[ ]|
|8.050|Multi-Tenancy Schema — Shared vs Separate|1|[ ]|
|8.051|Event Log Table Design — Append-Only|2|[ ]|
|8.052|Adjacency List — Hierarchical Data Pattern|2|[ ]|
|8.053|Nested Sets — Hierarchical Data Pattern|2|[ ]|
|8.054|Closure Table — Hierarchical Data Pattern|2|[ ]|
|8.055|Path Enumeration — Hierarchical Data Pattern|2|[ ]|
|8.056|EAV (Entity-Attribute-Value) — Anti-Pattern|2|[ ]|
|8.057|Polymorphic Associations — Design Patterns|2|[ ]|
|8.058|Versioning Data — Slowly Changing Dimensions|2|[ ]|
|8.059|Bitemporal Data Modeling — Valid Time and Transaction Time|2|[ ]|
|8.060|Sharding-Friendly Schema Design|2|[ ]|
|8.061|Index-Organized Tables — Concept|3|[ ]|
|8.062|Database Anti-Patterns — Common Design Mistakes|2|[ ]|
|8.063|Schema Migration Planning — Backward Compatibility|2|[ ]|
|8.064|Table Partitioning Design Decisions|2|[ ]|
|8.065|Database Design Review Checklist|2|[ ]|

---

## Group C — SQL Fundamentals (8.066–8.095)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.066|SELECT Statement — Column Selection and Aliasing|1|[x]|
|8.067|WHERE Clause — Predicate Logic and SARGability|1|[x]|
|8.068|ORDER BY — Deterministic Sorting|2|[x]|
|8.069|TOP / LIMIT / FETCH NEXT — Row Limiting|2|[x]|
|8.070|DISTINCT — Deduplication and Performance|2|[x]|
|8.071|INSERT — Single and Multi-Row Patterns|1|[x]|
|8.072|UPDATE — Safe Update Patterns|1|[x]|
|8.073|DELETE vs TRUNCATE vs DROP — Differences|1|[x]|
|8.074|MERGE — Upsert Operations|2|[x]|
|8.075|SELECT INTO — Table Creation from Query|2|[x]|
|8.076|Data Type Conversion — CAST and CONVERT|2|[x]|
|8.077|String Functions — LEN, SUBSTRING, CHARINDEX, PATINDEX|2|[x]|
|8.078|String Functions — STRING_AGG, STRING_SPLIT, STUFF, REPLACE|2|[x]|
|8.079|Date Functions — DATEADD, DATEDIFF, DATEPART, DATENAME|2|[x]|
|8.080|Date Functions — AT TIME ZONE, DATETIMEOFFSET, FORMAT|2|[x]|
|8.081|Math Functions — ROUND, FLOOR, CEILING, ABS, POWER, SQRT|2|[x]|
|8.082|Null Handling — ISNULL, COALESCE, NULLIF|1|[x]|
|8.083|Conditional Logic — CASE WHEN THEN ELSE|1|[x]|
|8.084|IIF — Inline Conditional|3|[x]|
|8.085|LIKE — Pattern Matching and Index Implications|1|[x]|
|8.086|IN and NOT IN — Set Membership and NULL Trap|1|[x]|
|8.087|BETWEEN — Range Queries|2|[x]|
|8.088|EXISTS vs IN — Performance Differences|1|[x]|
|8.089|Aliases — Table and Column Aliasing|2|[x]|
|8.090|SET Options — NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER|2|[x]|
|8.091|Variables — Declaring and Using in T-SQL|2|[x]|
|8.092|PRINT and RAISERROR — Debugging T-SQL|3|[x]|
|8.093|Implicit Conversion — The Silent Performance Killer|1|[x]|
|8.094|Function on Column — Non-SARGable Predicates|1|[x]|
|8.095|SQL Code Style — Naming Conventions and Readability|3|[x]|

---

## Group D — SQL Joins & Subqueries (8.096–8.120)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.096|INNER JOIN — Mechanics and Usage|1|[ ]|
|8.097|LEFT OUTER JOIN — Preserving Left Side Rows|1|[ ]|
|8.098|RIGHT OUTER JOIN — When to Avoid|2|[ ]|
|8.099|FULL OUTER JOIN — All Rows Both Sides|2|[ ]|
|8.100|CROSS JOIN — Cartesian Product Use Cases|2|[ ]|
|8.101|SELF JOIN — Same Table Relationships|2|[ ]|
|8.102|Multi-Table JOINs — Order and Performance|2|[ ]|
|8.103|JOIN on Multiple Columns — Composite Conditions|2|[ ]|
|8.104|Non-Equi JOIN — Range and Inequality Conditions|2|[ ]|
|8.105|JOIN vs Subquery — Decision Framework|1|[ ]|
|8.106|Correlated Subqueries — Per-Row Execution|2|[ ]|
|8.107|Scalar Subqueries — Single Value Return|2|[ ]|
|8.108|Derived Tables — Inline Views|2|[ ]|
|8.109|APPLY — CROSS APPLY and OUTER APPLY|2|[ ]|
|8.110|CROSS APPLY for Row-by-Row Processing|2|[ ]|
|8.111|OUTER APPLY — Optional Row-by-Row|2|[ ]|
|8.112|EXISTS vs JOIN — Choosing the Right Tool|1|[ ]|
|8.113|Lateral Join — PostgreSQL Equivalent of APPLY|2|[ ]|
|8.114|Hash Join vs Nested Loop vs Merge Join|1|[ ]|
|8.115|JOIN Elimination by Query Optimizer|2|[ ]|
|8.116|Filter Pushdown Through JOINs|2|[ ]|
|8.117|Star Join Optimization|3|[ ]|
|8.118|PIVOT — Row-to-Column Transformation|2|[ ]|
|8.119|UNPIVOT — Column-to-Row Transformation|2|[ ]|
|8.120|Dynamic PIVOT — Variable Number of Columns|3|[ ]|

---

## Group E — SQL Aggregations & Grouping (8.121–8.140)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.121|COUNT — Counting Rows and Non-NULL Values|1|[ ]|
|8.122|SUM, AVG, MIN, MAX — Aggregate Functions|1|[ ]|
|8.123|GROUP BY — Grouping Mechanics|1|[ ]|
|8.124|HAVING — Filtering Aggregated Groups|1|[ ]|
|8.125|GROUP BY vs WHERE — When Each Applies|1|[ ]|
|8.126|ROLLUP — Subtotals and Grand Totals|2|[ ]|
|8.127|CUBE — All Combinations of Aggregations|2|[ ]|
|8.128|GROUPING SETS — Custom Aggregation Groups|2|[ ]|
|8.129|GROUPING() Function — Identifying Rollup Rows|2|[ ]|
|8.130|DISTINCT in Aggregates — COUNT(DISTINCT col)|2|[ ]|
|8.131|Conditional Aggregation — SUM(CASE WHEN...)|1|[ ]|
|8.132|STRING_AGG — Aggregating Strings|2|[ ]|
|8.133|Statistical Aggregates — STDEV, VAR, STDEVP, VARP|3|[ ]|
|8.134|APPROX_COUNT_DISTINCT — Approximate Aggregation|3|[ ]|
|8.135|Aggregation Spills — Memory Grants and TempDB|2|[ ]|
|8.136|Aggregate Pushdown — Optimizer Optimization|2|[ ]|
|8.137|Hash Aggregate vs Stream Aggregate|2|[ ]|
|8.138|Aggregation with NULLs — Behavior|2|[ ]|
|8.139|Aggregation in EF Core — GroupBy Translation|2|[ ]|
|8.140|Aggregation Anti-Patterns — HAVING on Non-Aggregates|2|[ ]|

---

## Group F — SQL Window Functions & Analytics (8.141–8.175)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.141|Window Functions — Concept and OVER Clause|1|[ ]|
|8.142|PARTITION BY — Defining Window Partitions|1|[ ]|
|8.143|ORDER BY Within OVER — Frame Ordering|1|[ ]|
|8.144|ROW_NUMBER() — Unique Sequential Numbering|1|[ ]|
|8.145|RANK() — Ranking with Gaps|2|[ ]|
|8.146|DENSE_RANK() — Ranking without Gaps|2|[ ]|
|8.147|NTILE() — Dividing Rows into Buckets|2|[ ]|
|8.148|PERCENT_RANK() — Relative Ranking (0 to 1)|2|[ ]|
|8.149|CUME_DIST() — Cumulative Distribution|3|[ ]|
|8.150|LAG() — Accessing Previous Row Values|1|[ ]|
|8.151|LEAD() — Accessing Next Row Values|1|[ ]|
|8.152|FIRST_VALUE() — First Value in Partition|2|[ ]|
|8.153|LAST_VALUE() — Last Value in Partition|2|[ ]|
|8.154|NTH_VALUE() — Nth Value in Partition|3|[ ]|
|8.155|SUM() OVER() — Running Totals|1|[ ]|
|8.156|AVG() OVER() — Moving Averages|2|[ ]|
|8.157|COUNT() OVER() — Running Count per Partition|2|[ ]|
|8.158|MIN() OVER() and MAX() OVER() — Running Extremes|2|[ ]|
|8.159|Frame Specification — ROWS vs RANGE|2|[ ]|
|8.160|UNBOUNDED PRECEDING and FOLLOWING|2|[ ]|
|8.161|Window Function vs GROUP BY — Key Differences|1|[ ]|
|8.162|Window Function Performance — Sort Operations|2|[ ]|
|8.163|Deduplication with ROW_NUMBER()|1|[ ]|
|8.164|Gaps and Islands — Classic Window Problem|2|[ ]|
|8.165|Running Totals vs Period Totals|2|[ ]|
|8.166|Year-over-Year Comparison with LAG|2|[ ]|
|8.167|Sessionization — Finding Sessions with Gaps|2|[ ]|
|8.168|Top-N per Group — ROW_NUMBER vs Subquery|1|[ ]|
|8.169|Median Calculation — PERCENTILE_CONT|2|[ ]|
|8.170|PERCENTILE_CONT and PERCENTILE_DISC|2|[ ]|
|8.171|Mode Calculation in SQL|3|[ ]|
|8.172|Window Functions in EF Core — Raw SQL Required|2|[ ]|
|8.173|Window Functions in Dapper — Result Mapping|2|[ ]|
|8.174|Window Function Optimization — Avoiding Redundant Sorts|2|[ ]|
|8.175|Window Functions — PostgreSQL-Specific Extensions|3|[ ]|

---

## Group G — SQL CTEs & Recursive Queries (8.176–8.200)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.176|Common Table Expressions — Fundamentals|1|[ ]|
|8.177|Multiple CTEs — Chaining and Dependencies|2|[ ]|
|8.178|CTE vs Subquery — Readability and Performance|1|[ ]|
|8.179|CTE vs Temp Table — When to Use Each|1|[ ]|
|8.180|Recursive CTEs — Anchor and Recursive Members|1|[ ]|
|8.181|Recursive CTE — Traversing Hierarchies|2|[ ]|
|8.182|Recursive CTE — Generating Number Series|2|[ ]|
|8.183|Recursive CTE — Date Series Generation|2|[ ]|
|8.184|Recursive CTE — Graph Traversal|2|[ ]|
|8.185|Recursive CTE — MAXRECURSION Option|2|[ ]|
|8.186|CTE for Code Readability — Naming Intermediate Results|2|[ ]|
|8.187|Inline Table-Valued Functions vs CTEs|2|[ ]|
|8.188|CTE Materialization — Inline vs Spooled|2|[ ]|
|8.189|CTE in UPDATE and DELETE Statements|2|[ ]|
|8.190|CTE in MERGE Statements|2|[ ]|
|8.191|CTE with Window Functions — Common Pattern|2|[ ]|
|8.192|EXCEPT — Set Difference|2|[ ]|
|8.193|INTERSECT — Set Intersection|2|[ ]|
|8.194|UNION vs UNION ALL — Differences and Performance|1|[ ]|
|8.195|Set Operations vs JOIN — Decision|2|[ ]|
|8.196|Recursive BOM — Bill of Materials Explosion|2|[ ]|
|8.197|Recursive Org Chart Queries|2|[ ]|
|8.198|CTE Performance — Plan Inlining vs Spooling|2|[ ]|
|8.199|CTE Best Practices and Naming Conventions|3|[ ]|
|8.200|PostgreSQL — WITH RECURSIVE Syntax Differences|2|[ ]|

---

## Group H — SQL JSON, XML & Semi-Structured Data (8.201–8.225)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.201|JSON Support in SQL Server — FOR JSON PATH|2|[ ]|
|8.202|FOR JSON AUTO — Automatic Nesting|2|[ ]|
|8.203|OPENJSON — Parsing JSON in T-SQL|2|[ ]|
|8.204|JSON_VALUE — Extracting Scalar Values|2|[ ]|
|8.205|JSON_QUERY — Extracting JSON Fragments|2|[ ]|
|8.206|JSON_MODIFY — Updating JSON Fields|2|[ ]|
|8.207|ISJSON — Validating JSON|3|[ ]|
|8.208|Indexing JSON Columns — Computed Column Pattern|2|[ ]|
|8.209|JSON Columns vs Relational Columns — Decision|2|[ ]|
|8.210|JSON in EF Core — Value Conversion and JSON Columns|2|[ ]|
|8.211|OPENJSON with Schema — Typed Results|2|[ ]|
|8.212|JSON Arrays — Expanding with OPENJSON|2|[ ]|
|8.213|JSON Path Expressions — Dollar Notation|2|[ ]|
|8.214|Nested JSON — Parsing Multi-Level|2|[ ]|
|8.215|JSON Performance — Storage and Query Cost|2|[ ]|
|8.216|XML Data Type — Methods and Queries|3|[ ]|
|8.217|FOR XML — Producing XML Output|3|[ ]|
|8.218|XML Indexes — Primary and Secondary|3|[ ]|
|8.219|XPath in SQL Server — Querying XML|3|[ ]|
|8.220|PostgreSQL JSONB — Operators and Indexes|2|[ ]|
|8.221|PostgreSQL JSON vs JSONB — Comparison|2|[ ]|
|8.222|PostgreSQL JSONB GIN Index|2|[ ]|
|8.223|Semi-Structured Data — Design Decisions|2|[ ]|
|8.224|JSON vs Relational Columns — When to Mix|2|[ ]|
|8.225|JSON Aggregation — FOR JSON in Subqueries|2|[ ]|

---

## Group I — SQL Temporal Tables & Point-in-Time (8.226–8.245)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.226|Temporal Tables — System-Versioned Concept|2|[ ]|
|8.227|Creating System-Versioned Tables|2|[ ]|
|8.228|Querying History — FOR SYSTEM_TIME Clause|2|[ ]|
|8.229|AS OF — Point-in-Time Query|2|[ ]|
|8.230|FROM…TO — Range Query|2|[ ]|
|8.231|BETWEEN…AND — Inclusive Range|2|[ ]|
|8.232|CONTAINED IN — Fully Contained Periods|3|[ ]|
|8.233|ALL — All Versions Including Current|2|[ ]|
|8.234|Temporal Table Indexes — History Table Optimization|2|[ ]|
|8.235|Adding Temporal to Existing Tables|2|[ ]|
|8.236|Temporal Table — Removing System Versioning|2|[ ]|
|8.237|Temporal Data — Auditing Use Case|2|[ ]|
|8.238|Temporal Data — Slowly Changing Dimensions|2|[ ]|
|8.239|Temporal Data — Regulatory Compliance|2|[ ]|
|8.240|Application-Time Period Tables — Bitemporal|3|[ ]|
|8.241|Temporal Tables in EF Core — HasTemporalTable|2|[ ]|
|8.242|History Table Partitioning — Managing Growth|2|[ ]|
|8.243|Temporal Tables — Performance Implications|2|[ ]|
|8.244|PostgreSQL Temporal — tsrange Type|2|[ ]|
|8.245|Temporal Tables — Limitations and Gotchas|2|[ ]|

---

## Group J — SQL Full-Text & Spatial Search (8.246–8.265)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.246|Full-Text Search — SQL Server Architecture|2|[ ]|
|8.247|Full-Text Indexes — Creating and Populating|2|[ ]|
|8.248|CONTAINS — Searching for Words and Phrases|2|[ ]|
|8.249|FREETEXT — Language-Based Semantic Search|2|[ ]|
|8.250|CONTAINSTABLE — Ranked Full-Text Results|2|[ ]|
|8.251|FREETEXTTABLE — Semantic Ranked Results|3|[ ]|
|8.252|NEAR — Proximity Search|3|[ ]|
|8.253|Full-Text Thesaurus — Synonym Expansion|3|[ ]|
|8.254|Full-Text Stopwords — Noise Word Removal|3|[ ]|
|8.255|Full-Text Change Tracking — Automatic vs Manual|2|[ ]|
|8.256|Full-Text vs LIKE — Performance Comparison|2|[ ]|
|8.257|Spatial Data — Geography vs Geometry Types|2|[ ]|
|8.258|Spatial Indexes — Understanding Index Types|2|[ ]|
|8.259|STDistance — Proximity Queries|2|[ ]|
|8.260|STIntersects — Spatial Overlap|2|[ ]|
|8.261|STContains — Containment Check|2|[ ]|
|8.262|Bounding Box Queries — Performance Optimization|2|[ ]|
|8.263|Spatial Data in .NET — NetTopologySuite|2|[ ]|
|8.264|Full-Text vs Elasticsearch — Decision Framework|2|[ ]|
|8.265|PostgreSQL Full-Text Search — tsvector and tsquery|2|[ ]|

---

## Group K — SQL Server Architecture & Storage Engine (8.266–8.305)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.266|SQL Server Architecture — Services and Components|2|[x]|
|8.267|Database Engine — SQL OS Layer|3|[x]|
|8.268|Memory Architecture — Buffer Pool and Plan Cache|2|[x]|
|8.269|SQLOS Scheduler — Non-Preemptive Scheduling|3|[x]|
|8.270|Worker Threads — Thread Pool Management|2|[x]|
|8.271|Page Structure — 8KB Pages|2|[x]|
|8.272|Extent Structure — Mixed and Uniform Extents|2|[x]|
|8.273|GAM, SGAM, PFS — Space Management Pages|2|[x]|
|8.274|Data Pages — Row Structure|2|[x]|
|8.275|Row Overflow — Large Row Handling|2|[x]|
|8.276|LOB Storage — Large Object Pages|2|[x]|
|8.277|Allocation Units — IN_ROW, ROW_OVERFLOW, LOB|2|[x]|
|8.278|Table Heap — Structure Without Clustered Index|2|[x]|
|8.279|Clustered Index — Physical Table Organization|1|[x]|
|8.280|B-Tree Structure — Root, Intermediate, Leaf Pages|1|[x]|
|8.281|IAM Pages — Index Allocation Map|2|[x]|
|8.282|Database Files — MDF, NDF, LDF Roles|2|[x]|
|8.283|TempDB — Architecture and Contention|2|[x]|
|8.284|TempDB Contention — Metadata and Allocation|2|[x]|
|8.285|Transaction Log — Structure and VLFs|2|[x]|
|8.286|Log File Growth — Auto-Growth Anti-Pattern|2|[x]|
|8.287|VLF Fragmentation — Detection and Fix|2|[x]|
|8.288|Checkpoint Process — Dirty Page Flushing|2|[x]|
|8.289|Lazy Writer — Memory Management|2|[x]|
|8.290|Read-Ahead — Prefetching Pages|2|[x]|
|8.291|SQL Server Memory — Max Server Memory|2|[x]|
|8.292|NUMA Architecture — Memory and CPU Affinity|3|[x]|
|8.293|Columnstore Index Architecture — Delta Store and Compressed|2|[x]|
|8.294|In-Memory OLTP — Hekaton Architecture|3|[x]|
|8.295|In-Memory OLTP — Memory-Optimized Tables|3|[x]|
|8.296|In-Memory OLTP — Natively Compiled Procedures|3|[x]|
|8.297|Transparent Data Encryption (TDE) — Architecture|2|[x]|
|8.298|Always Encrypted — Client-Side Encryption|2|[x]|
|8.299|Row-Level Security — Architecture and Predicates|2|[x]|
|8.300|Dynamic Data Masking — Architecture|2|[x]|
|8.301|SQL Server on Linux — Architecture Differences|3|[x]|
|8.302|SQL Server in Containers — Limitations|2|[x]|
|8.303|SQL Server Versions — Edition and Feature Comparison|2|[x]|
|8.304|SQL Server Compatibility Level — Impact on Behavior|2|[x]|
|8.305|Database Collation — Choosing and Changing|2|[x]|

---

## Group L — SQL Server Administration & Management (8.306–8.335)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.306|SQL Server Installation — Best Practices|3|[x]|
|8.307|Instance Configuration — sp_configure Options|2|[x]|
|8.308|Database Creation — File Sizing and Placement|2|[x]|
|8.309|SQL Server Agent — Jobs and Schedules|2|[x]|
|8.310|SQL Server Agent — Alerts and Operators|2|[x]|
|8.311|Extended Events — Lightweight Tracing Architecture|1|[x]|
|8.312|Extended Events — Session Creation and Usage|2|[x]|
|8.313|SQL Server Profiler — Legacy Tracing|3|[x]|
|8.314|Dynamic Management Views — DMV Catalog Overview|1|[x]|
|8.315|sys.dm_exec_requests — Active Sessions|2|[x]|
|8.316|sys.dm_exec_query_stats — Query Performance History|2|[x]|
|8.317|sys.dm_os_wait_stats — Wait Statistics Analysis|1|[x]|
|8.318|sys.dm_os_performance_counters — Server Health|2|[x]|
|8.319|DBCC CHECKDB — Database Integrity|2|[x]|
|8.320|DBCC Commands — CHECKALLOC, CHECKTABLE, UPDATEUSAGE|2|[x]|
|8.321|Index Maintenance — Ola Hallengren Solution|2|[x]|
|8.322|Statistics Maintenance — Update Threshold Strategy|2|[x]|
|8.323|Database Shrink — Why to Avoid|2|[x]|
|8.324|Log File Management — VLF and Shrinking|2|[x]|
|8.325|File Group Management — Data Placement Strategy|2|[x]|
|8.326|SQL Server Permissions — Logins vs Users|2|[x]|
|8.327|Schema Permissions — GRANT, DENY, REVOKE|2|[x]|
|8.328|Fixed Server Roles vs Database Roles|2|[x]|
|8.329|Resource Governor — Workload Management|2|[x]|
|8.330|Query Store — Configuration and Sizing|1|[x]|
|8.331|Query Store — Regressed Queries Detection|1|[x]|
|8.332|Query Store — Plan Forcing|2|[x]|
|8.333|SQL Server Audit — Server and Database Audits|2|[x]|
|8.334|Database Snapshots — Read-Only Point-in-Time|2|[x]|
|8.335|Linked Servers — Remote Query Execution|2|[x]|

---

## Group M — SQL Server Performance & Tuning (8.336–8.375)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.336|Query Execution Pipeline — Parse, Bind, Optimize, Execute|1|[x]|
|8.337|Query Optimizer — Statistics-Based Decisions|1|[x]|
|8.338|Statistics Objects — Creation and Maintenance|1|[x]|
|8.339|Statistics — Automatic Update Threshold|2|[x]|
|8.340|Statistics — Trace Flag 2371 and Dynamic Threshold|2|[x]|
|8.341|Cardinality Estimation — CE70 vs CE120 vs CE150|2|[x]|
|8.342|New Cardinality Estimator — Key Differences|2|[x]|
|8.343|Execution Plans — Reading Graphical Plans|1|[x]|
|8.344|Execution Plans — Estimated vs Actual|1|[x]|
|8.345|Execution Plans — XML Plan Analysis|2|[x]|
|8.346|Plan Cache — How SQL Server Reuses Plans|2|[x]|
|8.347|Ad Hoc Workloads — Plan Cache Bloat|2|[x]|
|8.348|Parameterization — Forced vs Simple|2|[x]|
|8.349|Parameter Sniffing — The Problem|1|[x]|
|8.350|Parameter Sniffing — Solutions|1|[x]|
|8.351|OPTIMIZE FOR — Hinting Parameter Values|2|[x]|
|8.352|OPTION (RECOMPILE) — Per-Execution Plans|2|[x]|
|8.353|Plan Guides — Forcing Execution Plans|3|[x]|
|8.354|Index Seek vs Index Scan — When Each Occurs|1|[x]|
|8.355|Key Lookup — Identification and Elimination|1|[x]|
|8.356|RID Lookup — Heap Table Access|2|[x]|
|8.357|Nested Loops Join — When and Why|2|[x]|
|8.358|Hash Match Join — Memory Grants and Spills|2|[x]|
|8.359|Merge Join — Requirements and Performance|2|[x]|
|8.360|Adaptive Join — Runtime Algorithm Selection|2|[x]|
|8.361|Parallelism — MAXDOP and Cost Threshold|2|[x]|
|8.362|Parallelism — Skewed Distribution Issues|2|[x]|
|8.363|Memory Grants — Diagnosing Insufficient Grants|2|[x]|
|8.364|TempDB Spills — Sort and Hash Spills|2|[x]|
|8.365|Implicit Conversions in Execution Plans|1|[x]|
|8.366|SET STATISTICS IO — Reading Logical Reads|1|[x]|
|8.367|SET STATISTICS TIME — Parse and Execute Time|2|[x]|
|8.368|sys.dm_exec_query_profiles — Live Query Statistics|2|[x]|
|8.369|Adaptive Query Processing — Batch Mode|2|[x]|
|8.370|Intelligent Query Processing — SQL Server 2019+|2|[x]|
|8.371|Batch Mode on Rowstore — IQP Feature|3|[x]|
|8.372|Memory Grant Feedback — Adaptive Memory|2|[x]|
|8.373|Degree of Parallelism Feedback|3|[x]|
|8.374|Approximate Query Processing — APPROX_COUNT_DISTINCT|3|[x]|
|8.375|FORCESEEK, FORCESCAN, NOLOCK — Query Hints|2|[x]|

---

## Group N — SQL Server High Availability & DR (8.376–8.405)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.376|Always On Availability Groups — Architecture|1|[ ]|
|8.377|Always On AG — Synchronous vs Asynchronous Commit|2|[ ]|
|8.378|Always On AG — Automatic Failover|2|[ ]|
|8.379|Always On AG — Readable Secondary Replicas|2|[ ]|
|8.380|Always On AG — Setup and Configuration|2|[ ]|
|8.381|Always On AG — Monitoring and Health|2|[ ]|
|8.382|Always On AG — Listener — Virtual Network Name|2|[ ]|
|8.383|Distributed Availability Groups — Multi-AG|3|[ ]|
|8.384|Failover Cluster Instance — Shared Storage|2|[ ]|
|8.385|Windows Server Failover Clustering — WSFC|2|[ ]|
|8.386|Log Shipping — Architecture and Use Case|2|[ ]|
|8.387|Log Shipping — Setup and Monitoring|2|[ ]|
|8.388|SQL Server Replication — Snapshot|2|[ ]|
|8.389|SQL Server Replication — Transactional|2|[ ]|
|8.390|SQL Server Replication — Merge|3|[ ]|
|8.391|SQL Server Replication — Peer-to-Peer Transactional|3|[ ]|
|8.392|Recovery Models — Simple, Full, Bulk-Logged|1|[ ]|
|8.393|Tail-Log Backup — Preventing Data Loss Before Restore|2|[ ]|
|8.394|Point-in-Time Restore — Log Backup Chain|2|[ ]|
|8.395|Azure SQL — Active Geo-Replication|2|[ ]|
|8.396|Azure SQL — Auto-Failover Groups|2|[ ]|
|8.397|Azure SQL Managed Instance — HA Model|2|[ ]|
|8.398|Azure SQL — Business Critical Tier HA|2|[ ]|
|8.399|RPO and RTO in SQL Server Context|2|[ ]|
|8.400|Disaster Recovery Testing — Validation|2|[ ]|
|8.401|Restore Sequence — Database Restoration Order|2|[ ]|
|8.402|Database Recovery — Page-Level Restore|2|[ ]|
|8.403|Piecemeal Restore — Partial Database Access|3|[ ]|
|8.404|HADR Endpoint — Database Mirroring Endpoint|3|[ ]|
|8.405|Always On — Quorum Configuration|2|[ ]|

---

## Group O — SQL Server Security (8.406–8.430)

| ID    | Topic                                                | Priority | Generated |
| ----- | ---------------------------------------------------- | -------- | --------- |
| 8.406 | SQL Server Authentication — Windows vs SQL           | 2        | [ ]       |
| 8.407 | Login Types — Windows, SQL, Certificate, Asymmetric  | 2        | [ ]       |
| 8.408 | SQL Server Users — Mapping and Contained Databases   | 2        | [ ]       |
| 8.409 | Schema Ownership — dbo and Custom Schemas            | 2        | [ ]       |
| 8.410 | Principle of Least Privilege in SQL Server           | 1        | [ ]       |
| 8.411 | Ownership Chaining — Permission Propagation          | 2        | [ ]       |
| 8.412 | EXECUTE AS — Impersonation                           | 2        | [ ]       |
| 8.413 | SQL Injection — T-SQL Context and Prevention         | 1        | [ ]       |
| 8.414 | Parameterized Queries — Complete Prevention          | 1        | [ ]       |
| 8.415 | Stored Procedures as Security Boundary               | 2        | [ ]       |
| 8.416 | Row-Level Security — Predicate Functions             | 2        | [ ]       |
| 8.417 | Column-Level Security — Column Permissions           | 2        | [ ]       |
| 8.418 | Dynamic Data Masking — Mask Types                    | 2        | [ ]       |
| 8.419 | Always Encrypted — Key Management                    | 2        | [ ]       |
| 8.420 | Always Encrypted — EF Core Integration               | 2        | [ ]       |
| 8.421 | Transparent Data Encryption — Certificate Management | 2        | [ ]       |
| 8.422 | Auditing — SQL Server Audit Objects                  | 2        | [ ]       |
| 8.423 | SQL Server Audit — Server and Database Audit Specs   | 2        | [ ]       |
| 8.424 | Vulnerability Assessment — SQL Server                | 2        | [ ]       |
| 8.425 | Data Classification — Sensitivity Labels             | 2        | [ ]       |
| 8.426 | Service Accounts — Managed Service Identity          | 2        | [ ]       |
| 8.427 | Connection String Security — Avoiding Plain Text     | 1        | [ ]       |
| 8.428 | PII in Databases — Identification and Protection     | 2        | [ ]       |
| 8.429 | Cell-Level Encryption — ENCRYPTBYKEY                 | 3        | [ ]       |
| 8.430 | Azure SQL Security — Advanced Threat Protection      | 2        | [ ]       |
# Domain 8 — Databases

## Phonebook — Part 2 of 2 (Topics 8.431 – 8.1000)

---

## Group P — PostgreSQL (8.431–8.470)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.431|PostgreSQL Architecture — Process Model|2|[ ]|
|8.432|PostgreSQL — Shared Buffers and Memory|2|[ ]|
|8.433|PostgreSQL — WAL Architecture|2|[ ]|
|8.434|PostgreSQL — MVCC Implementation|1|[ ]|
|8.435|PostgreSQL — Autovacuum — Dead Tuple Removal|2|[ ]|
|8.436|PostgreSQL — VACUUM and ANALYZE|2|[ ]|
|8.437|PostgreSQL — Table Bloat — Causes and Solutions|2|[ ]|
|8.438|PostgreSQL — pg_stat_activity — Active Queries|2|[ ]|
|8.439|PostgreSQL — pg_stat_statements — Query Stats|2|[ ]|
|8.440|PostgreSQL — EXPLAIN and EXPLAIN ANALYZE|1|[ ]|
|8.441|PostgreSQL — Planner Statistics — pg_statistic|2|[ ]|
|8.442|PostgreSQL — Index Types — B-Tree, Hash, GiST, GIN, BRIN|1|[ ]|
|8.443|PostgreSQL — GIN Indexes for JSONB and Full-Text|2|[ ]|
|8.444|PostgreSQL — BRIN Indexes for Sequential Data|2|[ ]|
|8.445|PostgreSQL — Partial Indexes|2|[ ]|
|8.446|PostgreSQL — Expression Indexes|2|[ ]|
|8.447|PostgreSQL — Covering Indexes — INCLUDE Clause|2|[ ]|
|8.448|PostgreSQL — Table Partitioning — Declarative|2|[ ]|
|8.449|PostgreSQL — Partition Pruning|2|[ ]|
|8.450|PostgreSQL — Logical Replication|2|[ ]|
|8.451|PostgreSQL — Streaming Replication|2|[ ]|
|8.452|PostgreSQL — Replication Slots|2|[ ]|
|8.453|PostgreSQL — Hot Standby|2|[ ]|
|8.454|PostgreSQL — pg_basebackup|2|[ ]|
|8.455|PostgreSQL — Extensions — uuid-ossp, pgcrypto, PostGIS|2|[ ]|
|8.456|PostgreSQL — pgvector — Vector Similarity Search|2|[ ]|
|8.457|PostgreSQL — JSONB Operators and Indexing|2|[ ]|
|8.458|PostgreSQL — Array Data Type and Operators|2|[ ]|
|8.459|PostgreSQL — Range Types — daterange, tsrange|2|[ ]|
|8.460|PostgreSQL — hstore — Key-Value in SQL|3|[ ]|
|8.461|PostgreSQL — PL/pgSQL — Stored Procedures|2|[ ]|
|8.462|PostgreSQL — Connection Pooling — PgBouncer|2|[ ]|
|8.463|PostgreSQL — pg_dump and pg_restore|2|[ ]|
|8.464|PostgreSQL — Patroni — High Availability|2|[ ]|
|8.465|PostgreSQL — Citus — Distributed PostgreSQL|3|[ ]|
|8.466|PostgreSQL — Tablespaces|3|[ ]|
|8.467|PostgreSQL — Table Inheritance|3|[ ]|
|8.468|PostgreSQL — Serializable Snapshot Isolation (SSI)|2|[ ]|
|8.469|PostgreSQL in .NET — Npgsql Driver|2|[ ]|
|8.470|PostgreSQL vs SQL Server — Decision Matrix|1|[ ]|

---

## Group Q — MySQL & MariaDB (8.471–8.495)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.471|MySQL Architecture — Storage Engines Overview|2|[ ]|
|8.472|InnoDB — Architecture and ACID Guarantees|2|[ ]|
|8.473|InnoDB — Buffer Pool|2|[ ]|
|8.474|InnoDB — Redo Log and Undo Log|2|[ ]|
|8.475|InnoDB — Row Formats — COMPACT, DYNAMIC|3|[ ]|
|8.476|InnoDB — Clustered Index Behavior|2|[ ]|
|8.477|MySQL — Query Optimizer — EXPLAIN|2|[ ]|
|8.478|MySQL — Index Types — B-Tree, Hash, Full-Text|2|[ ]|
|8.479|MySQL — Covering Indexes|2|[ ]|
|8.480|MySQL — Replication — Binlog Formats|2|[ ]|
|8.481|MySQL — GTID Replication|2|[ ]|
|8.482|MySQL — Group Replication|2|[ ]|
|8.483|MySQL — InnoDB Cluster|2|[ ]|
|8.484|MySQL — ProxySQL — Connection Router|3|[ ]|
|8.485|MySQL — Partitioning Types|2|[ ]|
|8.486|MySQL — Generated Columns|2|[ ]|
|8.487|MySQL — JSON Data Type|2|[ ]|
|8.488|MySQL — Common Table Expressions|2|[ ]|
|8.489|MySQL — Window Functions|2|[ ]|
|8.490|MariaDB — Key Differences from MySQL|2|[ ]|
|8.491|MySQL — Performance Schema|2|[ ]|
|8.492|MySQL — slow_query_log — Configuration|2|[ ]|
|8.493|MySQL in .NET — MySqlConnector Driver|2|[ ]|
|8.494|MySQL vs PostgreSQL — Decision Matrix|2|[ ]|
|8.495|MySQL — innodb_buffer_pool_size Tuning|2|[ ]|

---

## Group R — Indexing Fundamentals (8.496–8.525)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.496|Index Fundamentals — Why Indexes Exist|1|[ ]|
|8.497|B-Tree Index — Structure and Navigation|1|[ ]|
|8.498|B+ Tree — Leaf Level and Row Pointers|1|[ ]|
|8.499|Index Seek — Point Lookup and Range Scan|1|[ ]|
|8.500|Index Scan — When Scans Beat Seeks|2|[ ]|
|8.501|Clustered Index — Physical Row Order|1|[ ]|
|8.502|Non-Clustered Index — Separate Structure|1|[ ]|
|8.503|Clustered vs Non-Clustered — Key Differences|1|[ ]|
|8.504|Composite Index — Column Order Rules|1|[ ]|
|8.505|Index Selectivity — High vs Low Selectivity|1|[ ]|
|8.506|Index Statistics — Density and Histograms|2|[ ]|
|8.507|Statistics Histogram — Steps, Range, and EQ Rows|2|[ ]|
|8.508|Cardinality Estimation from Statistics|2|[ ]|
|8.509|Statistics Update — Threshold and Frequency|2|[ ]|
|8.510|Auto Create Statistics — Performance Impact|2|[ ]|
|8.511|Index Fill Factor — Page Split Prevention|2|[ ]|
|8.512|Page Splits — Detection and Prevention|2|[ ]|
|8.513|Index Fragmentation — Internal vs External|2|[ ]|
|8.514|Fragmentation — REBUILD vs REORGANIZE|2|[ ]|
|8.515|Online Index Operations — Minimal Locking|2|[ ]|
|8.516|Index Maintenance — Threshold-Based Strategy|2|[ ]|
|8.517|Index Write Overhead — Impact on DML|1|[ ]|
|8.518|Index on Computed Columns|2|[ ]|
|8.519|Filtered Index — Partial Index|2|[ ]|
|8.520|Filtered Index — Sparse Data Pattern|2|[ ]|
|8.521|Covering Index — INCLUDE Clause|1|[ ]|
|8.522|Key Lookup Elimination — Covering Strategy|1|[ ]|
|8.523|Index Usage — sys.dm_db_index_usage_stats|2|[ ]|
|8.524|Missing Index DMVs — Identifying Opportunities|2|[ ]|
|8.525|Unused Indexes — Finding and Removing|2|[ ]|

---

## Group S — Indexing Advanced & Specialized (8.526–8.560)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.526|Columnstore Indexes — Architecture Overview|2|[ ]|
|8.527|Clustered Columnstore Index|2|[ ]|
|8.528|Non-Clustered Columnstore Index|2|[ ]|
|8.529|Columnstore — Delta Store and Tuple Mover|2|[ ]|
|8.530|Columnstore — Segment Elimination|2|[ ]|
|8.531|Columnstore — Row Group Compression|2|[ ]|
|8.532|Columnstore — Batch Mode Execution|2|[ ]|
|8.533|Columnstore — Updating Data — Impact|2|[ ]|
|8.534|Hash Indexes — In-Memory OLTP|3|[ ]|
|8.535|Range Indexes — In-Memory OLTP|3|[ ]|
|8.536|Full-Text Indexes — Inverted Index Structure|2|[ ]|
|8.537|Spatial Indexes — Grid Hierarchy|2|[ ]|
|8.538|Index Intersection — Multiple Index Access|2|[ ]|
|8.539|Index Union — Optimizer Decision|2|[ ]|
|8.540|Indexed Views — Requirements|2|[ ]|
|8.541|Indexed Views — Query Matching Conditions|2|[ ]|
|8.542|Indexed Views — Maintenance Overhead|2|[ ]|
|8.543|Index Compression — ROW and PAGE|2|[ ]|
|8.544|Data Compression — Storage and Performance|2|[ ]|
|8.545|Resumable Index Operations — SQL Server 2019+|2|[ ]|
|8.546|Online Index Build — Concurrent Writes|2|[ ]|
|8.547|Index with SORT_IN_TEMPDB|2|[ ]|
|8.548|Multi-Column Index vs Multiple Single Indexes|1|[ ]|
|8.549|Index Design Methodology — Systematic Approach|2|[ ]|
|8.550|Index Monitoring — Usage and Wait Stats|2|[ ]|
|8.551|PostgreSQL — GiST Indexes — Spatial and Custom|2|[ ]|
|8.552|PostgreSQL — GIN Indexes — Arrays and JSONB|2|[ ]|
|8.553|PostgreSQL — BRIN Indexes — Block Range|2|[ ]|
|8.554|PostgreSQL — Hash Indexes|2|[ ]|
|8.555|PostgreSQL — Concurrent Index Builds|2|[ ]|
|8.556|Backward Index Scan — Descending Order|2|[ ]|
|8.557|Index Skip Scan — Optimizer Optimization|2|[ ]|
|8.558|Non-SARGable Predicates — Complete Reference|1|[ ]|
|8.559|SARGable Rewrites — Converting Non-SARGable|1|[ ]|
|8.560|Index Advisor Tools — Built-In and Third-Party|2|[ ]|

---

## Group T — Query Optimization & Execution Plans (8.561–8.600)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.561|Query Optimizer — Cost-Based Optimization|1|[ ]|
|8.562|Parsing — Syntax Tree Generation|2|[ ]|
|8.563|Binding — Name Resolution and Type Checking|2|[ ]|
|8.564|Algebrizer — Logical Query Tree|2|[ ]|
|8.565|Optimization Phases — Trivial Plan, Full Optimization|2|[ ]|
|8.566|Transformation Rules — Logical Equivalences|2|[ ]|
|8.567|Join Reordering — Optimizer Freedom|2|[ ]|
|8.568|Subquery Unnesting — Flattening to Join|2|[ ]|
|8.569|Predicate Pushdown — Filter Early|2|[ ]|
|8.570|Constant Folding — Compile-Time Evaluation|2|[ ]|
|8.571|Execution Plan Operators — Complete Reference|2|[ ]|
|8.572|Table Scan — Sequential Read|2|[ ]|
|8.573|Index Seek — Specific Row Access|1|[ ]|
|8.574|Index Scan — Full Index Read|2|[ ]|
|8.575|Clustered Index Scan vs Table Scan|2|[ ]|
|8.576|Key Lookup — Bookmark Lookup Operator|1|[ ]|
|8.577|Nested Loops Join — Small Outer, Large Inner|1|[ ]|
|8.578|Hash Match Join — Large Unsorted Inputs|1|[ ]|
|8.579|Merge Join — Pre-Sorted Inputs Requirement|2|[ ]|
|8.580|Adaptive Join — Runtime Algorithm Selection|2|[ ]|
|8.581|Batch Mode Hash Join — Columnar Optimization|2|[ ]|
|8.582|Sort Operator — Memory and Disk Spill|2|[ ]|
|8.583|Top N Sort — Optimization|2|[ ]|
|8.584|Parallelism Operators — Repartition, Broadcast, Gather|2|[ ]|
|8.585|Filter Operator — Predicate Evaluation|2|[ ]|
|8.586|Compute Scalar — Expression Evaluation|2|[ ]|
|8.587|Stream Aggregate — Group and Aggregate|2|[ ]|
|8.588|Hash Aggregate — Memory-Based Aggregation|2|[ ]|
|8.589|Spool Operators — Eager and Lazy|2|[ ]|
|8.590|Estimated vs Actual Rows — Row Count Errors|1|[ ]|
|8.591|Memory Grant Feedback — Adaptive Memory|2|[ ]|
|8.592|Degree of Parallelism — DOP Selection|2|[ ]|
|8.593|USE PLAN — Forcing Specific Plans|3|[ ]|
|8.594|FORCESEEK and FORCESCAN Hints|2|[ ]|
|8.595|Query Hints vs Index Hints — When to Use|2|[ ]|
|8.596|Reading XML Execution Plans — Key Attributes|2|[ ]|
|8.597|Execution Plan Comparison — Before and After Tuning|2|[ ]|
|8.598|PostgreSQL EXPLAIN ANALYZE — Reading Output|2|[ ]|
|8.599|PostgreSQL — Planner Method Configuration|2|[ ]|
|8.600|Query Tuning Methodology — Step-by-Step|1|[ ]|

---

## Group U — Transactions & Concurrency (8.601–8.630)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.601|Transaction Fundamentals — BEGIN, COMMIT, ROLLBACK|1|[ ]|
|8.602|Explicit vs Implicit vs Autocommit Transactions|1|[ ]|
|8.603|Nested Transactions — Savepoints|2|[ ]|
|8.604|SAVE TRANSACTION — Partial Rollback|2|[ ]|
|8.605|Long-Running Transactions — Problems and Detection|1|[ ]|
|8.606|Transaction Log Impact — Active Transaction Bloat|2|[ ]|
|8.607|Distributed Transactions — MSDTC|2|[ ]|
|8.608|Distributed Transactions — Problems and Alternatives|2|[ ]|
|8.609|Optimistic vs Pessimistic Concurrency|1|[ ]|
|8.610|Concurrency Anomalies — Dirty Read|1|[ ]|
|8.611|Concurrency Anomalies — Non-Repeatable Read|1|[ ]|
|8.612|Concurrency Anomalies — Phantom Read|1|[ ]|
|8.613|Concurrency Anomalies — Lost Update|1|[ ]|
|8.614|Concurrency Anomalies — Write Skew|2|[ ]|
|8.615|SELECT FOR UPDATE — Pessimistic Locking|2|[ ]|
|8.616|Optimistic Concurrency — Timestamp and RowVersion|1|[ ]|
|8.617|rowversion — SQL Server Implementation|2|[ ]|
|8.618|Optimistic Concurrency in EF Core — ConcurrencyToken|2|[ ]|
|8.619|Idempotent Write Patterns — Database Level|2|[ ]|
|8.620|Conditional Updates — UPDATE with Version Check|2|[ ]|
|8.621|Two-Phase Locking — Theory|2|[ ]|
|8.622|Strict Two-Phase Locking|2|[ ]|
|8.623|Multi-Version Concurrency — Core Concept|1|[ ]|
|8.624|MVCC in PostgreSQL — Version Chain|2|[ ]|
|8.625|MVCC in SQL Server — Version Store in TempDB|2|[ ]|
|8.626|Transaction in EF Core — UseTransaction and BeginTransaction|2|[ ]|
|8.627|Transaction in Dapper — IDbTransaction|2|[ ]|
|8.628|Retry Logic for Serialization Failures|2|[ ]|
|8.629|Concurrency Testing — Simulating Race Conditions|2|[ ]|
|8.630|Transaction Anti-Patterns — Common Mistakes|2|[ ]|

---

## Group V — Isolation Levels, MVCC & Snapshot Isolation (8.631–8.660)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.631|Read Uncommitted — Dirty Reads Allowed|2|[ ]|
|8.632|Read Committed — Default SQL Server Isolation|1|[ ]|
|8.633|Repeatable Read — No Non-Repeatable Reads|2|[ ]|
|8.634|Serializable — Strictest Isolation|2|[ ]|
|8.635|Snapshot Isolation — Optimistic Reader|1|[ ]|
|8.636|Read Committed Snapshot Isolation (RCSI)|1|[ ]|
|8.637|RCSI vs Snapshot Isolation — Key Differences|1|[ ]|
|8.638|Enabling RCSI — ALTER DATABASE|2|[ ]|
|8.639|RCSI — Version Store Sizing and TempDB Impact|2|[ ]|
|8.640|Read Skew under RCSI|2|[ ]|
|8.641|Write-Write Conflicts under Snapshot|2|[ ]|
|8.642|Serialization Anomalies — Snapshot vs Serializable|2|[ ]|
|8.643|PostgreSQL MVCC — Heap Tuples and Visibility|2|[ ]|
|8.644|PostgreSQL MVCC — xmin and xmax|2|[ ]|
|8.645|PostgreSQL MVCC — Snapshot at Transaction Start|2|[ ]|
|8.646|PostgreSQL Isolation Levels — Mapping to SQL Standard|2|[ ]|
|8.647|PostgreSQL Serializable Snapshot Isolation (SSI)|2|[ ]|
|8.648|MySQL InnoDB MVCC — Undo Log Chain|2|[ ]|
|8.649|Isolation Level Selection — Decision Framework|1|[ ]|
|8.650|Isolation Level in EF Core — UseIsolationLevel|2|[ ]|
|8.651|Isolation Level in Dapper — Transaction Parameter|2|[ ]|
|8.652|Testing Isolation — Concurrent Session Simulation|2|[ ]|
|8.653|Isolation Level Monitoring — Lock and Version Stats|2|[ ]|
|8.654|Long-Running Snapshot Transactions — Version Store Bloat|2|[ ]|
|8.655|Version Store Cleanup — Automatic Process|2|[ ]|
|8.656|Version Store Monitoring — sys.dm_tran_version_store|2|[ ]|
|8.657|Isolation Anti-Patterns — Wrong Level for Workload|2|[ ]|
|8.658|SET TRANSACTION ISOLATION LEVEL — Scope|2|[ ]|
|8.659|Isolation Level in Connection String — Default|2|[ ]|
|8.660|Documenting Isolation Level Choices — ADR|3|[ ]|

---

## Group W — Locking, Blocking & Deadlocks (8.661–8.690)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.661|Lock Types — Shared, Exclusive, Update, Intent|1|[ ]|
|8.662|Lock Granularity — Row, Page, Table, Database|1|[ ]|
|8.663|Lock Compatibility Matrix|2|[ ]|
|8.664|Lock Escalation — Row to Page to Table|2|[ ]|
|8.665|Lock Escalation — Disabling and Impact|2|[ ]|
|8.666|Intent Locks — IX, IS, SIX|2|[ ]|
|8.667|Key-Range Locks — Serializable Protection|2|[ ]|
|8.668|Schema Locks — SCH-M and SCH-S|2|[ ]|
|8.669|Application Locks — sp_getapplock|2|[ ]|
|8.670|Blocking — Detection with DMVs|1|[ ]|
|8.671|Blocking — sys.dm_exec_requests and wait_type|2|[ ]|
|8.672|Blocking Chains — Root Blocker Identification|2|[ ]|
|8.673|Blocking — Head Blocker Investigation and Kill|2|[ ]|
|8.674|NOLOCK Hint — Risks and When to Use|2|[ ]|
|8.675|ROWLOCK, PAGLOCK, TABLOCK — Locking Hints|2|[ ]|
|8.676|UPDLOCK — Preventing Lost Updates|2|[ ]|
|8.677|HOLDLOCK — SERIALIZABLE Hint|2|[ ]|
|8.678|READPAST — Skip Locked Rows Pattern|2|[ ]|
|8.679|Deadlock — Detection Algorithm|1|[ ]|
|8.680|Deadlock — Victim Selection|2|[ ]|
|8.681|Deadlock — Graph Analysis in Extended Events|1|[ ]|
|8.682|Deadlock — Trace Flag 1222 and 1204|2|[ ]|
|8.683|Deadlock Prevention — Consistent Lock Order|1|[ ]|
|8.684|Deadlock — Retry Logic in .NET|2|[ ]|
|8.685|Deadlock in EF Core — Handling and Retry|2|[ ]|
|8.686|Latch vs Lock — Internal Synchronization|2|[ ]|
|8.687|Wait Statistics — Lock and Latch Waits|2|[ ]|
|8.688|sys.dm_os_wait_stats — Top Wait Types|2|[ ]|
|8.689|PostgreSQL — Advisory Locks|2|[ ]|
|8.690|PostgreSQL — pg_locks — Lock Monitoring|2|[ ]|

---

## Group X — Database Replication & Synchronization (8.691–8.715)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.691|Replication Fundamentals — Publisher, Distributor, Subscriber|2|[ ]|
|8.692|Transactional Replication — Log Reading Mechanism|2|[ ]|
|8.693|Transactional Replication — Latency and Monitoring|2|[ ]|
|8.694|Transactional Replication — Peer-to-Peer|2|[ ]|
|8.695|Snapshot Replication — Full Refresh|2|[ ]|
|8.696|Merge Replication — Conflict Resolution|3|[ ]|
|8.697|Replication Agents — Roles and Monitoring|2|[ ]|
|8.698|Replication Latency — Measurement and Tuning|2|[ ]|
|8.699|CDC — Change Data Capture in SQL Server|2|[ ]|
|8.700|CDC — Enabling and Querying|2|[ ]|
|8.701|CDC — Integration with ETL and Event Streaming|2|[ ]|
|8.702|CT — Change Tracking — Lightweight Alternative|2|[ ]|
|8.703|CT — CHANGETABLE Function|2|[ ]|
|8.704|CT vs CDC — Decision Framework|2|[ ]|
|8.705|Azure SQL — Data Sync Service|2|[ ]|
|8.706|Azure SQL — Active Geo-Replication Configuration|2|[ ]|
|8.707|PostgreSQL — Logical Replication Setup|2|[ ]|
|8.708|PostgreSQL — Publication and Subscription|2|[ ]|
|8.709|PostgreSQL — Replication Slot Management|2|[ ]|
|8.710|MySQL — Replication Binlog Formats|2|[ ]|
|8.711|Replication Monitoring — Lag and Health DMVs|2|[ ]|
|8.712|Replication Security — Encryption in Transit|2|[ ]|
|8.713|Replication vs CQRS — Architectural Comparison|2|[ ]|
|8.714|Debezium — CDC via Log Mining|2|[ ]|
|8.715|Read Replicas in .NET — Routing Reads to Secondary|2|[ ]|

---

## Group Y — Database Partitioning (8.716–8.740)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.716|Table Partitioning — Concept and Benefits|2|[ ]|
|8.717|Partition Function — Range Left and Right|2|[ ]|
|8.718|Partition Scheme — File Group Mapping|2|[ ]|
|8.719|Creating and Managing Partitioned Tables|2|[ ]|
|8.720|Partition Switching — Fast Data Movement|2|[ ]|
|8.721|Partition Elimination — Query Optimizer|2|[ ]|
|8.722|Aligned Indexes — Partition Alignment|2|[ ]|
|8.723|Partitioning Strategy — Range by Date|2|[ ]|
|8.724|Partitioning Strategy — Range by ID|2|[ ]|
|8.725|Partitioning Strategy — List Partitioning|2|[ ]|
|8.726|Partitioning Strategy — Hash Partitioning|2|[ ]|
|8.727|Partition Statistics — Per-Partition Stats|2|[ ]|
|8.728|Sliding Window Pattern — Archiving Old Data|2|[ ]|
|8.729|Partitioning Monitoring — sys.partitions|2|[ ]|
|8.730|Partitioning in Azure SQL|2|[ ]|
|8.731|PostgreSQL — Declarative Partitioning|2|[ ]|
|8.732|PostgreSQL — Partition Pruning|2|[ ]|
|8.733|PostgreSQL — Sub-Partitioning|3|[ ]|
|8.734|MySQL — Partitioning Types|2|[ ]|
|8.735|Horizontal Sharding vs Table Partitioning|2|[ ]|
|8.736|Application-Level Sharding — .NET Implementation|2|[ ]|
|8.737|Consistent Hashing for Database Sharding|2|[ ]|
|8.738|Cross-Shard Query Patterns — Challenges|2|[ ]|
|8.739|Partition Maintenance — Adding New Partitions|2|[ ]|
|8.740|Non-Aligned Index — Considerations|3|[ ]|

---

## Group Z — Stored Procedures, Functions, Triggers & Views (8.741–8.775)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.741|Stored Procedures — Benefits and Limitations|2|[ ]|
|8.742|Stored Procedure Compilation and Plan Caching|2|[ ]|
|8.743|Stored Procedure — Parameter Sniffing|2|[ ]|
|8.744|Stored Procedure — WITH RECOMPILE|2|[ ]|
|8.745|Scalar Functions — Performance Penalty|2|[ ]|
|8.746|Scalar Functions — Inlining SQL Server 2019+|2|[ ]|
|8.747|Table-Valued Functions — Inline vs Multi-Statement|2|[ ]|
|8.748|Inline Table-Valued Functions — Zero Performance Penalty|2|[ ]|
|8.749|Multi-Statement TVF — Performance Comparison|2|[ ]|
|8.750|CLR Integration — When to Use|3|[ ]|
|8.751|DML Triggers — AFTER and INSTEAD OF|2|[ ]|
|8.752|DDL Triggers — Schema Change Auditing|2|[ ]|
|8.753|Logon Triggers — Connection Auditing|3|[ ]|
|8.754|Trigger — Inserted and Deleted Tables|2|[ ]|
|8.755|Trigger Performance — Impact on DML|2|[ ]|
|8.756|Recursive Triggers — Enabling and Risks|3|[ ]|
|8.757|Nested Triggers — Behavior|3|[ ]|
|8.758|Views — Simple Views|2|[ ]|
|8.759|Views — Updateable Views|2|[ ]|
|8.760|Views — WITH CHECK OPTION|2|[ ]|
|8.761|Views — SCHEMABINDING|2|[ ]|
|8.762|Views — Security Boundary Pattern|2|[ ]|
|8.763|Indexed Views — Clustered Index on View|2|[ ]|
|8.764|Indexed Views — Query Matching|2|[ ]|
|8.765|Indexed Views — Maintenance Overhead|2|[ ]|
|8.766|Materialized Views — PostgreSQL|2|[ ]|
|8.767|Materialized Views — Refresh Strategies|2|[ ]|
|8.768|Synonyms — Abstraction Layer|3|[ ]|
|8.769|Sequences — Auto-Increment Alternative|2|[ ]|
|8.770|Computed Columns — Persisted vs Non-Persisted|2|[ ]|
|8.771|Persisted Computed Columns — Index Support|2|[ ]|
|8.772|Database Procedures vs Application Logic — Decision|2|[ ]|
|8.773|PL/pgSQL — Writing Functions in PostgreSQL|2|[ ]|
|8.774|Error Handling in T-SQL — TRY CATCH THROW|2|[ ]|
|8.775|Dynamic SQL — sp_executesql Best Practices|2|[ ]|

---

## Group AA — Database Security & Compliance (8.776–8.800)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.776|Defense in Depth for Databases|2|[ ]|
|8.777|Database Threat Model — Attack Vectors|2|[ ]|
|8.778|SQL Injection — Prevention Complete Guide|1|[ ]|
|8.779|Parameterized Queries — All .NET Approaches|1|[ ]|
|8.780|Least Privilege — Application User Permissions|1|[ ]|
|8.781|Application User vs DBO — Security Separation|2|[ ]|
|8.782|Service Accounts — Managed Identity for Azure SQL|2|[ ]|
|8.783|Connection String Security — Secrets Management|2|[ ]|
|8.784|Auditing — What to Log|2|[ ]|
|8.785|Azure SQL Auditing — Log Analytics Integration|2|[ ]|
|8.786|Row-Level Security — Implementation Patterns|2|[ ]|
|8.787|Column-Level Encryption — Key Rotation|2|[ ]|
|8.788|Always Encrypted — Query Limitations|2|[ ]|
|8.789|PII Data — Identification and Protection|2|[ ]|
|8.790|GDPR — Right to Erasure in Databases|2|[ ]|
|8.791|Data Masking — Development and Test Environments|2|[ ]|
|8.792|Database Firewall — IP Restrictions|2|[ ]|
|8.793|TDE — Key Rotation Procedures|2|[ ]|
|8.794|Certificate Management — SQL Server Certificates|2|[ ]|
|8.795|HIPAA — Database Technical Requirements|2|[ ]|
|8.796|PCI DSS — Database Controls|2|[ ]|
|8.797|SOC 2 — Database Security Controls|3|[ ]|
|8.798|Penetration Testing — SQL Server|3|[ ]|
|8.799|Vulnerability Assessment — Azure SQL|2|[ ]|
|8.800|Security Monitoring — Anomaly Detection|2|[ ]|

---

## Group AB — Backup, Recovery & Point-in-Time Restore (8.801–8.825)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.801|Backup Types — Full, Differential, Log|1|[ ]|
|8.802|Full Backup — Strategy and Scheduling|2|[ ]|
|8.803|Differential Backup — Change Tracking|2|[ ]|
|8.804|Transaction Log Backup — Chain Maintenance|2|[ ]|
|8.805|Log Backup Frequency and RPO|2|[ ]|
|8.806|Copy-Only Backup — Out-of-Band|2|[ ]|
|8.807|Backup Compression — Storage and CPU|2|[ ]|
|8.808|Backup Encryption — Certificate-Based|2|[ ]|
|8.809|Backup to URL — Azure Blob Storage|2|[ ]|
|8.810|RESTORE VERIFYONLY — Validating Backups|2|[ ]|
|8.811|RESTORE with RECOVERY vs NORECOVERY|2|[ ]|
|8.812|RESTORE HEADERONLY and FILELISTONLY|2|[ ]|
|8.813|Point-in-Time Restore — STOPAT|2|[ ]|
|8.814|Tail-Log Backup — Before Restore|2|[ ]|
|8.815|Recovery Time Estimation — Log Application Speed|2|[ ]|
|8.816|Backup Testing — Regular Restore Validation|2|[ ]|
|8.817|Azure SQL Automated Backups — Configuration|2|[ ]|
|8.818|Azure SQL PITR — Time Range|2|[ ]|
|8.819|Azure SQL LTR — Long-Term Retention|2|[ ]|
|8.820|Backup Monitoring — msdb Tables|2|[ ]|
|8.821|Page-Level Restore — Targeted Recovery|2|[ ]|
|8.822|Piecemeal Restore — Partial Database Access|3|[ ]|
|8.823|PostgreSQL — pg_dump and pg_restore|2|[ ]|
|8.824|PostgreSQL — Continuous Archiving and PITR|2|[ ]|
|8.825|Disaster Recovery Runbook — SQL Server|2|[ ]|

---

## Group AC — Database Migration & Schema Evolution (8.826–8.850)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.826|Schema Migration Strategies — Overview|1|[ ]|
|8.827|Expand-Contract Pattern — Backward-Compatible Changes|1|[ ]|
|8.828|Zero-Downtime Column Addition|2|[ ]|
|8.829|Zero-Downtime Column Removal|2|[ ]|
|8.830|Zero-Downtime Index Creation — ONLINE Option|2|[ ]|
|8.831|Zero-Downtime Constraint Addition|2|[ ]|
|8.832|Table Rename — Rolling Strategy|2|[ ]|
|8.833|Data Type Change — Migration Procedure|2|[ ]|
|8.834|Large Table Migration — Batched Updates|2|[ ]|
|8.835|Schema Versioning — Tracking Applied Migrations|2|[ ]|
|8.836|EF Core Migrations — How They Work|2|[ ]|
|8.837|EF Core Migrations — Customizing Generated SQL|2|[ ]|
|8.838|EF Core Migrations — Squashing Migrations|2|[ ]|
|8.839|EF Core Migrations — Idempotent Scripts|2|[ ]|
|8.840|EF Core Migrations — Applying in Production|2|[ ]|
|8.841|Flyway — Database Migration Tool|2|[ ]|
|8.842|Liquibase — Database Migration Tool|2|[ ]|
|8.843|DbUp — .NET Migration Tool|2|[ ]|
|8.844|Migration Testing — Validation Approach|2|[ ]|
|8.845|Rollback Strategy — Forward-Only vs Reversible|2|[ ]|
|8.846|Blue-Green Database Migration|2|[ ]|
|8.847|Data Seeding — Initial and Reference Data|2|[ ]|
|8.848|Migration in CI/CD — Automated Deployment|2|[ ]|
|8.849|Breaking vs Non-Breaking Schema Changes|1|[ ]|
|8.850|Migration Anti-Patterns — Common Mistakes|2|[ ]|

---

## Group AD — Dapper in .NET (8.851–8.880)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.851|Dapper — What It Is and When to Use|1|[ ]|
|8.852|Dapper vs EF Core — Decision Framework|1|[ ]|
|8.853|Dapper — Query<T> — Basic Querying|2|[ ]|
|8.854|Dapper — QueryFirstOrDefault<T> and QuerySingle<T>|2|[ ]|
|8.855|Dapper — QueryAsync — Async Patterns|2|[ ]|
|8.856|Dapper — Multi-Mapping — QueryMultiple|2|[ ]|
|8.857|Dapper — Multi-Mapping — One-to-Many Results|2|[ ]|
|8.858|Dapper — Execute — INSERT, UPDATE, DELETE|2|[ ]|
|8.859|Dapper — ExecuteScalar — Single Value Return|2|[ ]|
|8.860|Dapper — Stored Procedure Calling|2|[ ]|
|8.861|Dapper — DynamicParameters — Dynamic SQL|2|[ ]|
|8.862|Dapper — Output Parameters|2|[ ]|
|8.863|Dapper — Table-Valued Parameters|2|[ ]|
|8.864|Dapper — Transactions — IDbTransaction|2|[ ]|
|8.865|Dapper — Buffered vs Unbuffered Queries|2|[ ]|
|8.866|Dapper — Custom Type Handlers — SqlMapper.TypeHandler|2|[ ]|
|8.867|Dapper — Column Mapping — Custom Conventions|2|[ ]|
|8.868|Dapper — Grid Reader — Multiple Result Sets|2|[ ]|
|8.869|Dapper — Bulk Operations — BulkExtensions|2|[ ]|
|8.870|Dapper — Connection Factory Pattern|2|[ ]|
|8.871|Dapper — Repository Pattern Implementation|2|[ ]|
|8.872|Dapper — Unit Testing — Mock IDbConnection|2|[ ]|
|8.873|Dapper — Performance — IL Emit Internals|2|[ ]|
|8.874|Dapper — Contrib — CRUD Extensions|2|[ ]|
|8.875|Dapper — Integration with Polly — Retry|2|[ ]|
|8.876|Dapper — Connection Management — Open and Close|2|[ ]|
|8.877|Dapper — CommandDefinition — CancellationToken|2|[ ]|
|8.878|Dapper — SqlMapper.AddTypeMap — Type Mapping|2|[ ]|
|8.879|Dapper — Anti-Patterns and Gotchas|2|[ ]|
|8.880|Dapper — vs ADO.NET Raw — When to Go Lower|2|[ ]|

---

## Group AE — Database Patterns in .NET (8.881–8.915)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.881|Repository Pattern — Interface and Implementation|2|[ ]|
|8.882|Repository Pattern — Generic vs Specific|2|[ ]|
|8.883|Unit of Work Pattern — Transaction Boundary|2|[ ]|
|8.884|Unit of Work — EF Core vs Custom Implementation|2|[ ]|
|8.885|CQRS at Database Level — Read and Write Models|2|[ ]|
|8.886|Outbox Pattern — Database Implementation|2|[ ]|
|8.887|Outbox Pattern — Polling Publisher in .NET|2|[ ]|
|8.888|Inbox Pattern — Deduplication Table|2|[ ]|
|8.889|Soft Delete — Global Query Filter in EF Core|2|[ ]|
|8.890|Multi-Tenancy — Shared Schema with TenantId|2|[ ]|
|8.891|Multi-Tenancy — Separate Schema Pattern|2|[ ]|
|8.892|Multi-Tenancy — Separate Database Pattern|2|[ ]|
|8.893|Audit Trail — EF Core SaveChanges Interceptor|2|[ ]|
|8.894|Audit Trail — Shadow Properties|2|[ ]|
|8.895|Optimistic Concurrency — RowVersion in EF Core|2|[ ]|
|8.896|Pessimistic Locking — FromSqlRaw with UPDLOCK|2|[ ]|
|8.897|Bulk Insert — SqlBulkCopy|2|[ ]|
|8.898|Bulk Insert — EF Core Bulk Extensions|2|[ ]|
|8.899|Batch Updates — ExecuteUpdateAsync EF Core 7+|2|[ ]|
|8.900|Batch Deletes — ExecuteDeleteAsync EF Core 7+|2|[ ]|
|8.901|Raw SQL in EF Core — FromSqlRaw vs FromSqlInterpolated|2|[ ]|
|8.902|Stored Procedure Mapping in EF Core|2|[ ]|
|8.903|Table-Valued Function Mapping in EF Core|2|[ ]|
|8.904|Database View Mapping in EF Core|2|[ ]|
|8.905|Keyless Entity Types — Projections in EF Core|2|[ ]|
|8.906|Compiled Queries — EF.CompileQuery|2|[ ]|
|8.907|Query Splitting — AsSplitQuery()|2|[ ]|
|8.908|No-Tracking Queries — AsNoTracking()|2|[ ]|
|8.909|Connection Resiliency — EnableRetryOnFailure|2|[ ]|
|8.910|Database Health Checks — .NET Integration|2|[ ]|
|8.911|Shadow Properties — Audit Without Domain Change|2|[ ]|
|8.912|Owned Entities — Value Objects in EF Core|2|[ ]|
|8.913|Many-to-Many in EF Core — Join Table Configuration|2|[ ]|
|8.914|Global Query Filters — EF Core|2|[ ]|
|8.915|IQueryable vs IEnumerable — Database Execution|1|[ ]|

---

## Group AF — Database Monitoring & Observability (8.916–8.940)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.916|SQL Server Monitoring — Key Metrics|2|[ ]|
|8.917|Wait Statistics — Top Waits Analysis|1|[ ]|
|8.918|Wait Categories — CPU, IO, Lock, Memory|2|[ ]|
|8.919|CXPACKET and CXCONSUMER — Parallelism Waits|2|[ ]|
|8.920|PAGEIOLATCH — IO Wait Analysis|2|[ ]|
|8.921|LCK_ Waits — Lock Wait Analysis|2|[ ]|
|8.922|SOS_SCHEDULER_YIELD — CPU Pressure|2|[ ]|
|8.923|RESOURCE_SEMAPHORE — Memory Grant Wait|2|[ ]|
|8.924|Baseline Capture — DMV Snapshot Strategy|2|[ ]|
|8.925|Extended Events — Capturing Slow Queries|2|[ ]|
|8.926|Query Store — Monitoring and Regressed Queries|2|[ ]|
|8.927|Azure SQL Intelligent Insights|2|[ ]|
|8.928|SQL Server Dashboards — Grafana Setup|2|[ ]|
|8.929|SQL Server — Prometheus Exporter|2|[ ]|
|8.930|Application Insights — SQL Dependency Tracking|2|[ ]|
|8.931|EF Core Logging — SQL Output Configuration|2|[ ]|
|8.932|Dapper Logging — MiniProfiler Integration|2|[ ]|
|8.933|MiniProfiler — ASP.NET Core Integration|2|[ ]|
|8.934|pg_stat_statements — PostgreSQL Query Stats|2|[ ]|
|8.935|auto_explain — PostgreSQL Slow Query Plans|2|[ ]|
|8.936|Database Alerts — Threshold Configuration|2|[ ]|
|8.937|Capacity Planning — Growth Monitoring|2|[ ]|
|8.938|Index Fragmentation — Scheduled Monitoring|2|[ ]|
|8.939|Database Space Monitoring — File Growth Alerts|2|[ ]|
|8.940|Connection Pool Monitoring — Pool Exhaustion|2|[ ]|

---

## Group AG — Database Testing (8.941–8.960)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.941|Database Testing — Strategy Overview|2|[ ]|
|8.942|Unit Testing — Repository Mocks|2|[ ]|
|8.943|Integration Testing — Real Database|1|[ ]|
|8.944|TestContainers — SQL Server in Docker|2|[ ]|
|8.945|TestContainers — PostgreSQL in Docker|2|[ ]|
|8.946|Respawn — Database Reset Between Tests|2|[ ]|
|8.947|SQLite In-Memory — EF Core Testing|2|[ ]|
|8.948|SQLite Limitations vs Real SQL Server|2|[ ]|
|8.949|Test Data Builders — Fluent Object Creation|2|[ ]|
|8.950|Database Fixtures — xUnit IClassFixture|2|[ ]|
|8.951|Seeding Test Data — Deterministic Setup|2|[ ]|
|8.952|Testing Migrations — Validation Approach|2|[ ]|
|8.953|Testing Stored Procedures — Integration Tests|2|[ ]|
|8.954|Testing Transactions — Rollback After Test|2|[ ]|
|8.955|Performance Testing — Load Tests on Database|2|[ ]|
|8.956|Testing Concurrency — Race Condition Simulation|2|[ ]|
|8.957|Test Database Isolation — Per-Test vs Per-Suite|2|[ ]|
|8.958|Schema Snapshot Testing|3|[ ]|
|8.959|Database Contract Testing — Schema Compatibility|3|[ ]|
|8.960|Database Testing Anti-Patterns|2|[ ]|

---

## Group AH — Redis Deep Dive (8.961–8.1000)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|8.961|Redis — Data Structures Overview|1|[ ]|
|8.962|Redis — Strings — INCR, INCRBY, GETSET, SETNX|2|[ ]|
|8.963|Redis — Strings — MSET, MGET, MSETNX|2|[ ]|
|8.964|Redis — Strings — APPEND, STRLEN, GETRANGE, SETRANGE|2|[ ]|
|8.965|Redis — Strings — Bit Operations — BITCOUNT, BITPOS, BITOP|2|[ ]|
|8.966|Redis — Hashes — HSET, HGET, HMSET, HMGET|2|[ ]|
|8.967|Redis — Hashes — HINCRBY, HGETALL, HKEYS, HVALS, HDEL|2|[ ]|
|8.968|Redis — Hashes — Use Case — User Profile Storage|2|[ ]|
|8.969|Redis — Lists — LPUSH, RPUSH, LPOP, RPOP|2|[ ]|
|8.970|Redis — Lists — LRANGE, LINDEX, LLEN, LSET|2|[ ]|
|8.971|Redis — Lists — BLPOP, BRPOP — Blocking Pop|2|[ ]|
|8.972|Redis — Lists — Queue Pattern|2|[ ]|
|8.973|Redis — Lists — Stack Pattern|2|[ ]|
|8.974|Redis — Sets — SADD, SREM, SMEMBERS, SCARD|2|[ ]|
|8.975|Redis — Sets — SUNION, SINTER, SDIFF — Set Operations|2|[ ]|
|8.976|Redis — Sets — Use Case — Unique Visitors Tracking|2|[ ]|
|8.977|Redis — Sorted Sets — ZADD, ZREM, ZSCORE, ZCARD|2|[ ]|
|8.978|Redis — Sorted Sets — ZRANGE, ZREVRANGE, ZRANGEBYSCORE|2|[ ]|
|8.979|Redis — Sorted Sets — ZRANK, ZREVRANK, ZINCRBY|2|[ ]|
|8.980|Redis — Sorted Sets — Leaderboard Pattern|2|[ ]|
|8.981|Redis — Sorted Sets — Rate Limiting Pattern|2|[ ]|
|8.982|Redis — Streams — XADD, XREAD, XRANGE|2|[ ]|
|8.983|Redis — Streams — Consumer Groups — XREADGROUP|2|[ ]|
|8.984|Redis — Streams — XACK, XPENDING, XCLAIM|2|[ ]|
|8.985|Redis — Streams — vs Kafka Decision|2|[ ]|
|8.986|Redis — HyperLogLog — PFADD, PFCOUNT, PFMERGE|2|[ ]|
|8.987|Redis — Pub/Sub — SUBSCRIBE, PUBLISH, PSUBSCRIBE|2|[ ]|
|8.988|Redis — Pub/Sub vs Streams — Decision|2|[ ]|
|8.989|Redis — Key Expiry — TTL, PTTL, EXPIRE, PERSIST|2|[ ]|
|8.990|Redis — Eviction Policies — allkeys-lru, volatile-lru, LFU|2|[ ]|
|8.991|Redis — Persistence — RDB Snapshots|2|[ ]|
|8.992|Redis — Persistence — AOF Append-Only File|2|[ ]|
|8.993|Redis — Persistence — RDB + AOF Combined|2|[ ]|
|8.994|Redis — Transactions — MULTI/EXEC, DISCARD|2|[ ]|
|8.995|Redis — WATCH — Optimistic Locking|2|[ ]|
|8.996|Redis — Lua Scripting — EVAL and EVALSHA|2|[ ]|
|8.997|Redis — Cluster Mode — Hash Slots and Sharding|2|[ ]|
|8.998|Redis — Sentinel — High Availability|2|[ ]|
|8.999|Redis — Sentinel vs Cluster — Decision|1|[ ]|
|8.1000|Redis — StackExchange.Redis — .NET Full Reference|2|[ ]|

---

## Generation Order by Priority — Tier 1 Critical

|#|ID|Topic|
|---|---|---|
|1|8.001|The Relational Model|
|2|8.002|Keys — Primary, Foreign, Candidate|
|3|8.003|Referential Integrity|
|4|8.004|ACID — Atomicity|
|5|8.005|ACID — Consistency|
|6|8.006|ACID — Isolation|
|7|8.007|ACID — Durability|
|8|8.008|NULL — Three-Valued Logic|
|9|8.015|Cardinality|
|10|8.017|OLTP vs OLAP|
|11|8.019|Table Heap vs Clustered Table|
|12|8.023|Statistics — Optimizer Usage|
|13|8.026|Write-Ahead Logging|
|14|8.031|First Normal Form|
|15|8.032|Second Normal Form|
|16|8.033|Third Normal Form|
|17|8.037|Denormalization|
|18|8.042|Surrogate vs Natural Keys|
|19|8.043|UUID vs Sequential ID|
|20|8.050|Multi-Tenancy Schema|
|21|8.067|WHERE Clause — SARGability|
|22|8.071|INSERT Patterns|
|23|8.072|UPDATE Safe Patterns|
|24|8.073|DELETE vs TRUNCATE vs DROP|
|25|8.082|NULL Handling — COALESCE|
|26|8.083|CASE WHEN|
|27|8.085|LIKE — Index Implications|
|28|8.086|IN and NOT IN — NULL Trap|
|29|8.088|EXISTS vs IN|
|30|8.093|Implicit Conversion — Performance Killer|
|31|8.094|Function on Column — Non-SARGable|
|32|8.096|INNER JOIN|
|33|8.097|LEFT OUTER JOIN|
|34|8.105|JOIN vs Subquery|
|35|8.112|EXISTS vs JOIN|
|36|8.114|Hash Join vs Nested Loop vs Merge Join|
|37|8.121|COUNT|
|38|8.122|SUM, AVG, MIN, MAX|
|39|8.123|GROUP BY|
|40|8.124|HAVING|
|41|8.125|GROUP BY vs WHERE|
|42|8.131|Conditional Aggregation|
|43|8.141|Window Functions — Concept|
|44|8.142|PARTITION BY|
|45|8.143|ORDER BY Within OVER|
|46|8.144|ROW_NUMBER()|
|47|8.150|LAG()|
|48|8.151|LEAD()|
|49|8.155|SUM() OVER() — Running Totals|
|50|8.161|Window Function vs GROUP BY|
|51|8.163|Deduplication with ROW_NUMBER|
|52|8.168|Top-N per Group|
|53|8.176|CTEs — Fundamentals|
|54|8.178|CTE vs Subquery|
|55|8.179|CTE vs Temp Table|
|56|8.180|Recursive CTEs|
|57|8.194|UNION vs UNION ALL|
|58|8.279|Clustered Index — Physical Organization|
|59|8.280|B-Tree Structure|
|60|8.311|Extended Events|
|61|8.314|DMV Catalog Overview|
|62|8.317|sys.dm_os_wait_stats|
|63|8.330|Query Store — Configuration|
|64|8.331|Query Store — Regressed Queries|
|65|8.336|Query Execution Pipeline|
|66|8.337|Query Optimizer|
|67|8.338|Statistics Objects|
|68|8.343|Execution Plans — Reading Graphical|
|69|8.344|Execution Plans — Estimated vs Actual|
|70|8.349|Parameter Sniffing — Problem|
|71|8.350|Parameter Sniffing — Solutions|
|72|8.354|Index Seek vs Index Scan|
|73|8.355|Key Lookup — Elimination|
|74|8.366|SET STATISTICS IO|
|75|8.376|Always On AG — Architecture|
|76|8.392|Recovery Models|
|77|8.410|Least Privilege|
|78|8.413|SQL Injection Prevention|
|79|8.414|Parameterized Queries|
|80|8.434|PostgreSQL MVCC|
|81|8.440|PostgreSQL EXPLAIN ANALYZE|
|82|8.442|PostgreSQL Index Types|
|83|8.470|PostgreSQL vs SQL Server Decision|
|84|8.496|Index Fundamentals|
|85|8.497|B-Tree Index Structure|
|86|8.498|B+ Tree — Leaf Level|
|87|8.499|Index Seek|
|88|8.501|Clustered Index|
|89|8.502|Non-Clustered Index|
|90|8.503|Clustered vs Non-Clustered|
|91|8.504|Composite Index — Column Order|
|92|8.505|Index Selectivity|
|93|8.517|Index Write Overhead|
|94|8.521|Covering Index — INCLUDE|
|95|8.522|Key Lookup Elimination|
|96|8.548|Multi-Column vs Multiple Single Indexes|
|97|8.558|Non-SARGable Predicates — Reference|
|98|8.559|SARGable Rewrites|
|99|8.561|Query Optimizer — Cost-Based|
|100|8.573|Index Seek Operator|
|101|8.576|Key Lookup Operator|
|102|8.577|Nested Loops Join|
|103|8.578|Hash Match Join|
|104|8.590|Estimated vs Actual Rows|
|105|8.600|Query Tuning Methodology|
|106|8.601|Transaction Fundamentals|
|107|8.602|Explicit vs Implicit Transactions|
|108|8.605|Long-Running Transactions|
|109|8.609|Optimistic vs Pessimistic Concurrency|
|110|8.610|Dirty Read|
|111|8.611|Non-Repeatable Read|
|112|8.612|Phantom Read|
|113|8.613|Lost Update|
|114|8.616|Optimistic Concurrency — RowVersion|
|115|8.623|MVCC — Core Concept|
|116|8.632|Read Committed|
|117|8.635|Snapshot Isolation|
|118|8.636|RCSI|
|119|8.637|RCSI vs Snapshot Isolation|
|120|8.649|Isolation Level Selection|
|121|8.661|Lock Types|
|122|8.662|Lock Granularity|
|123|8.670|Blocking — Detection|
|124|8.679|Deadlock — Detection|
|125|8.681|Deadlock — Graph Analysis|
|126|8.683|Deadlock Prevention|
|127|8.801|Backup Types|
|128|8.826|Schema Migration Strategies|
|129|8.827|Expand-Contract Pattern|
|130|8.849|Breaking vs Non-Breaking Changes|
|131|8.851|Dapper — What and When|
|132|8.852|Dapper vs EF Core Decision|
|133|8.778|SQL Injection — Complete Guide|
|134|8.779|Parameterized Queries — All .NET|
|135|8.780|Least Privilege — Application User|
|136|8.915|IQueryable vs IEnumerable|
|137|8.943|Integration Testing — Real Database|
|138|8.961|Redis — Data Structures Overview|
|139|8.999|Redis — Sentinel vs Cluster|
|140|8.917|Wait Statistics Analysis|

---

_Domain 8 — Databases | 1,000 topics | 34 groups_ _Tags: #engineering #knowledge-base #databases #sql #sql-server #postgresql #redis #dotnet_