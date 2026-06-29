# Domain 8 — Databases

## Note Generation Prompt

**Purpose:** Generation spec for all Domain 8 notes. Read this file first, then produce the complete note directly. No narration. No reasoning overhead.

---

## Domain Identity

- **Domain Number:** 8
- **Domain Name:** Databases
- **Scope:** Relational theory, SQL mastery (T-SQL and ANSI), SQL Server internals and administration, PostgreSQL, MySQL, indexing deep dive, query optimization, execution plans, transactions, concurrency, isolation levels, locking and deadlocks, replication, partitioning, stored procedures, views, database security, backup and recovery, schema migration, Dapper in .NET, database patterns in .NET, monitoring, testing, Redis deep dive
- **Audience:** Senior-level interview preparation and production .NET engineering reference
- **Quality Bar:** Every SQL example must be executable. Every performance claim must reference logical reads or execution time. Every .NET example must show both EF Core and Dapper where applicable. No hand-waving on execution plans.

---

## File Naming Convention

```
8_XXX_Topic_Name_With_Underscores.md
8_001_The_Relational_Model.md
8_496_Index_Fundamentals.md
8_961_Redis_Data_Structures_Overview.md
```

---

## YAML Frontmatter

```yaml
---
id: "8.XXX"
title: "Topic Name"
domain: "Databases"
domain_id: 8
group: "Group Name"
tags: [databases, sql, sql-server, dotnet, performance]
priority: X
prerequisites:
  - "[[8.XXX — Topic Name]]"
related:
  - "[[8.XXX — Topic Name]]"
  - "[[3.XXX — EF Core Topic]]"
  - "[[7.XXX — System Design Topic]]"
created: YYYY-MM-DD
---
```

**Valid group values:** `Relational Fundamentals` | `Database Design` | `SQL Fundamentals` | `SQL Joins and Subqueries` | `SQL Aggregations` | `SQL Window Functions` | `SQL CTEs` | `SQL JSON and XML` | `SQL Temporal` | `SQL Search` | `SQL Server Architecture` | `SQL Server Administration` | `SQL Server Performance` | `SQL Server High Availability` | `SQL Server Security` | `PostgreSQL` | `MySQL` | `Indexing Fundamentals` | `Indexing Advanced` | `Query Optimization` | `Transactions` | `Isolation Levels` | `Locking and Deadlocks` | `Replication` | `Partitioning` | `Stored Procedures and Views` | `Database Security` | `Backup and Recovery` | `Schema Migration` | `Dapper` | `Database Patterns` | `Database Monitoring` | `Database Testing` | `Redis`

---

## Note Structure — 9 Mandatory Sections

---

### Section 1 — Navigation & Context

```markdown
## Navigation

**Domain:** [[8 — Databases]] > **Group:** [Group Name]
**Previous:** [[8.XXX — Topic]] | **Next:** [[8.XXX — Topic]]

### Prerequisites
- [[8.XXX — Topic]] — why required (one sentence)
- [[3.XXX — EF Core Topic]] — if EF Core knowledge is required

### Where This Fits
2–4 sentences. What problem does this solve? Where does a .NET backend engineer encounter this in production? What breaks when this is unknown or misapplied? What is the interview signal this concept represents?
```

---

### Section 2 — Core Mental Model

````markdown
## Core Mental Model

One precise paragraph. Not a textbook definition — an engineer's working model. What is the invariant? What does the database engine actually do? What is the recognition pattern for when this concept applies?

### Classification

**For SQL topics:** what clause or operator family this belongs to, what the query optimizer can and cannot do with it, whether it is SARGable.
**For indexing topics:** the data structure used, the access path it enables, the write overhead it introduces.
**For architecture topics:** which layer of the engine this lives in, what it trades for its guarantee.
**For .NET topics:** which abstraction handles this, what is hidden from the developer, where the abstraction leaks.

[REQUIRED Mermaid diagram]

For **query topics**: show the logical execution order or the execution plan shape.
For **index topics**: draw the B-tree or index structure showing key columns, leaf pages, and row pointers.
For **concurrency topics**: draw the state machine or the timeline of concurrent transactions.
For **architecture topics**: draw the component hierarchy or the data flow.

```mermaid
[diagram here — valid syntax required]
````

### Key Properties

|Property|Value|Notes|
|---|---|---|
|Time Complexity|O(?)|[for the primary operation]|
|Write Cost|[High/Medium/Low]|[what writes are affected]|
|SARGable|[Yes/No/Partial]|[for query/index topics]|
|Locking Behavior|[Row/Page/Table]|[for concurrency topics]|

````

---

### Section 3 — Deep Mechanics

```markdown
## Deep Mechanics

### How the Engine Executes This

Step-by-step. For SQL operations: trace the exact execution order — parsing, binding, optimization, execution. For indexes: trace a seek from root to leaf, counting page reads. For transactions: trace the log writes and buffer pool interactions. For replication: trace the change from source commit to subscriber delivery.

### SQL Visibility

**Every SQL topic must show the actual T-SQL AND the EF Core LINQ that generates it.**

```sql
-- The SQL being discussed
SELECT o.OrderId, o.CustomerId, SUM(oi.Quantity * oi.UnitPrice) AS OrderTotal
FROM Orders o
INNER JOIN OrderItems oi ON o.OrderId = oi.OrderId
GROUP BY o.OrderId, o.CustomerId;
````

```csharp
// The EF Core LINQ that generates equivalent SQL
var orderTotals = await dbContext.Orders
    .Include(o => o.OrderItems)
    .Select(o => new {
        o.OrderId,
        o.CustomerId,
        OrderTotal = o.OrderItems.Sum(oi => oi.Quantity * oi.UnitPrice)
    })
    .ToListAsync(cancellationToken);
```

**Generated SQL (from EF Core logs):**

```sql
-- Paste the actual EF Core generated SQL here — not pseudocode
```

### Execution Plan Analysis

Describe the expected execution plan for the primary SQL example:

- What operators appear?
- Where are seeks vs scans?
- What is the estimated vs actual row count?
- What is the cost percentage per operator?
- What would the plan look like without the index?

```
Expected plan shape:
[Table Scan / Index Seek] → [Nested Loops / Hash Match] → [Sort] → [SELECT]
Estimated Cost: X%  |  Logical Reads: ~N
```

### Cost Visibility

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- The query
[SQL here]

-- Expected output:
-- Table 'Orders'. Scan count N, logical reads N, physical reads N
-- SQL Server Execution Times: CPU time = Nms, elapsed time = Nms
```

### Failure Modes

What breaks and how. What query pattern causes a full table scan when you expected a seek? What transaction pattern causes deadlocks? What index choice causes write amplification? Show the DMV query that reveals the problem.

````

---

### Section 4 — Production Patterns and Implementation

```markdown
## Production Patterns and Implementation

### Primary SQL Implementation

Complete, executable T-SQL for the core concept. Requirements:
- Realistic table and column names — Orders, Customers, Products, OrderItems, Payments, Invoices — never Foo/Bar
- Include CREATE TABLE with appropriate constraints if schema context is needed
- Show the SARGable version AND the non-SARGable version for comparison where relevant
- Every query must be executable in SQL Server (or the target database)

```sql
-- Production-realistic SQL
-- Label key parts with comments
````

### EF Core Implementation

```csharp
// EF Core equivalent — complete, async, with CancellationToken
// Show the DbContext configuration where relevant (OnModelCreating)
// Include IServiceCollection registration
```

### Dapper Implementation

```csharp
// Dapper equivalent where meaningful
// Show connection management, parameter passing, result mapping
public async Task<IReadOnlyList<OrderSummary>> GetOrderSummariesAsync(
    int customerId,
    CancellationToken cancellationToken = default)
{
    const string sql = @"
        SELECT ...
        FROM Orders o
        WHERE o.CustomerId = @CustomerId";
    
    await using var connection = _connectionFactory.Create();
    var results = await connection.QueryAsync<OrderSummary>(
        new CommandDefinition(sql, new { CustomerId = customerId },
            cancellationToken: cancellationToken));
    return results.AsList();
}
```

### Configuration and Wiring

```csharp
// Program.cs / IServiceCollection registration
// DbContext options, connection string, retry policies
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        connectionString,
        sqlOptions => sqlOptions.EnableRetryOnFailure(3)));
```

### SQL Server vs PostgreSQL Differences

For topics that differ between SQL Server and PostgreSQL, show the PostgreSQL equivalent:

```sql
-- PostgreSQL equivalent
[SQL here]
```

````

---

### Section 5 — Gotchas and Production Pitfalls

```markdown
## Gotchas and Production Pitfalls

Format: **Pitfall** → **Symptom** → **Fix** → **Cost of not fixing**

Minimum 4. Maximum 8. Every entry must be something that has burned production SQL Server or PostgreSQL systems. Focus on:
1. The non-SARGable predicate that causes a full table scan
2. The missing index that causes a key lookup explosion
3. The transaction scope that holds locks too long
4. The implicit conversion that defeats an index
5. The EF Core anti-pattern that generates unexpected SQL
6. The parameter sniffing trap

### [Pitfall Name]

**Pitfall:** What the engineer does wrong.

```sql
-- ❌ Wrong SQL or configuration
````

**Symptom:** What appears in production — the wait stat, the slow query log entry, the blocking chain, the error message.

**Fix:**

```sql
-- ✅ Correct SQL or configuration
```

**Cost of not fixing:** What happens at 3 AM. Specific: "Table scan on 50M row table causing 45-second queries, blocking 200 concurrent users" not "performance issues."

````

---

### Section 6 — Performance Implications

```markdown
## Performance Implications

### Benchmark: Before and After

For every performance-relevant topic, show the actual difference in logical reads:

```sql
-- Baseline (without optimization)
SET STATISTICS IO ON;
[unoptimized query]
-- Logical reads: N,000

-- Optimized version
[optimized query]
-- Logical reads: N (after index / rewrite)
````

**Improvement:** Xx reduction in logical reads, from N,000 to N.

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class [TopicName]Benchmark
{
    private IDbConnection _connection = default!;

    [GlobalSetup]
    public void Setup()
    {
        _connection = new SqlConnection(TestConnectionString);
        // seed test data
    }

    [Benchmark(Baseline = true)]
    public async Task<List<T>> Without_[Optimization]()
    {
        // unoptimized approach
    }

    [Benchmark]
    public async Task<List<T>> With_[Optimization]()
    {
        // optimized approach
    }
}
```

**Expected results (approximate, SQL Server 2022, NVMe, 1M rows):**

|Method|Mean|Logical Reads|Allocated|
|---|---|---|---|
|Without_[Optimization]|~X ms|~N,000|Y KB|
|With_[Optimization]|~X ms|~N|Z B|

### Write Amplification (for index topics)

For index notes, show the INSERT/UPDATE/DELETE overhead:

|Operation|Without Index|With Index|Overhead|
|---|---|---|---|
|INSERT 1 row|X ms|Y ms|+Z%|
|UPDATE indexed col|X ms|Y ms|+Z%|
|DELETE 1 row|X ms|Y ms|+Z%|

````

---

### Section 7 — Interview Arsenal

```markdown
## Interview Arsenal

### Question Bank

6–8 questions, foundational → advanced:

1. [Definition — what it is and what problem it solves]
2. [Mechanism — how the database engine handles it internally]
3. [Performance — what is the cost and how do you measure it]
4. [Gotcha — what goes wrong when this is misused]
5. [Comparison — this vs the most commonly confused alternative]
6. [Execution plan — what does the plan look like and why]
7. [Scale — how does this behave at 100M rows / 10,000 concurrent users]
8. [.NET integration — how do EF Core and Dapper handle this]

### Spoken Answers

Full spoken-narrative for questions 1, 5, and the most advanced question. Two tiers:

**Q: [Question]**

> **Average answer:** What most candidates say — technically correct but surface-level. Missing the execution plan, the logical read count, or the .NET behavior.

> **Great answer:** What a senior candidate says. Derives the performance implication from the storage engine behavior. Names the exact DMV or wait stat that reveals the problem. Connects to a real production scenario with specific numbers. Knows the EF Core behavior and whether it generates SARGable SQL.

### Interview Trigger

One paragraph. If this topic appears in an interview, what question surfaces it? What follow-up does the interviewer ask to separate candidates who know the concept from those who know it deeply?

### Comparison Table

| | [This] | [Most Confused With] |
|---|---|---|
| What it does | | |
| Performance profile | | |
| Locking behavior | | |
| .NET implementation | | |
| When to choose | | |
````

---

### Section 8 — Decision Framework

````markdown
## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Problem or trigger condition] --> B{Key decision}
    B -->|Condition A| C[Apply this approach]
    B -->|Condition B| D{Secondary decision}
    D -->|Condition C| E[Alternative A]
    D -->|Condition D| F[Alternative B]
    C --> G[Expected outcome with metrics]
````

### Application Checklist

- [ ] The problem this solves is present
- [ ] The table size justifies this approach (give the number)
- [ ] The write cost is acceptable for this workload ratio
- [ ] Statistics are current and will allow the optimizer to use this
- [ ] The .NET data access layer generates SARGable SQL for this

### Tradeoff Summary

|What You Gain|What You Pay|
|---|---|
|[Read performance gain]|[Write overhead]|
|[Reduced logical reads]|[Storage cost]|
|[Lock reduction]|[Complexity]|

### Scale Thresholds

When does this matter? Give real numbers:

- "Relevant when table exceeds ~100K rows"
- "Critical when concurrent writers exceed ~50/second"
- "Required when query runs more than ~1000x/hour"

````

---

### Section 9 — Self-Check

```markdown
## Self-Check

### Conceptual Questions

1. [Tests: definition — what is it without looking it up]
2. [Tests: engine behavior — what does SQL Server actually do]
3. [Tests: performance measurement — which DMV or SET STATISTICS shows this]
4. [Tests: the gotcha — what common mistake defeats this]
5. [Tests: EF Core behavior — does EF Core generate SARGable SQL for this]
6. [Tests: Dapper usage — how would you implement this with Dapper]
7. [Tests: comparison — this vs the nearest alternative]
8. [Tests: scale — at what row count / concurrency does this matter]
9. [Tests: connection to indexing — what index supports or hinders this]
10. [Tests: interview articulation — explain this in 60 seconds to a senior interviewer]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer with engine-level detail]
3. [Answer naming the specific DMV, wait stat, or SET STATISTICS output]
4. [Answer with the specific mistake and its consequence]
5. [Answer — yes/no/depends + what EF Core generates]
6. [Answer with Dapper code snippet]
7. [Answer with structural comparison]
8. [Answer with real numbers]
9. [Answer with index name and column order]
10. [Answer as 60-second spoken narrative]

</details>

---

### Query Challenges

**Challenge 1 — Write the SQL**

[Problem statement in plain English — realistic business requirement, 2–3 sentences]

<details>
<summary>Solution</summary>

```sql
-- Solution
````

**Logical reads:** ~N **Execution plan:** [Key operators] **EF Core equivalent:**

```csharp
// LINQ
```

</details>

---

**Challenge 2 — Fix the performance problem**

```sql
-- This query is slow. It runs in 8 seconds on a 10M row table.
-- Identify why and fix it.
[slow query here]
-- SET STATISTICS IO: logical reads = 450,000
```

<details> <summary>Solution</summary>

**Root cause:** [What makes it slow — non-SARGable, missing index, wrong join type, etc.]

```sql
-- Fixed query
```

**Index to create:**

```sql
CREATE INDEX IX_[TableName]_[Column] ON [TableName]([Column]) INCLUDE ([OtherCol]);
```

**After fix — logical reads:** ~N (from 450,000 to N)

</details>

---

**Challenge 3 — Explain the execution plan**

```sql
-- Given this query and this execution plan output:
[query and plan description]
```

Why does the optimizer choose [Plan A] instead of [Plan B]? What would you change to get a different plan?

<details> <summary>Solution</summary>

**Why [Plan A]:** [Engine reasoning — statistics, cardinality, cost] **To get [Plan B]:** [Index, hint, or rewrite] **Tradeoff:** [What you gain vs give up by forcing the alternative]

</details>

---

**Challenge 4 — Diagnose the concurrency problem**

[Description of a blocking or deadlock scenario — 3–4 sentences with the symptoms]

<details> <summary>Solution</summary>

**Root cause:** [Lock type, isolation level, transaction duration] **Detection query:**

```sql
-- DMV query to see the problem
```

**Fix:** [Isolation level change, index to reduce lock duration, query rewrite] **In .NET:** [How to handle this in EF Core / Dapper with retry logic]

</details>

---

**Challenge 5 — Design the index**

**Scenario:** [Realistic query workload description — 3–4 sentences with table size, query patterns, read/write ratio]

Design the optimal index strategy. Show the CREATE INDEX statements and explain each choice.

<details> <summary>Solution</summary>

```sql
-- Index 1: why this column order
CREATE INDEX IX_[Name] ON [Table]([Col1], [Col2]) INCLUDE ([Col3]);

-- Index 2: filtered index for sparse data
CREATE INDEX IX_[Name] ON [Table]([Col1]) WHERE [Col2] IS NOT NULL;
```

**Tradeoffs:** [Write overhead accepted, storage cost, what queries benefit] **What NOT to index:** [Columns that would hurt write performance without proportional read benefit]

</details> ```

---

## Domain-Specific Generation Rules

### Rule 1 — SQL Visibility Is Mandatory

Every note covering a SQL concept, query pattern, or database feature must show the actual T-SQL. No pseudocode. No placeholder comments. The SQL must be executable on SQL Server (and PostgreSQL where specified). Every SQL block must have a companion EF Core LINQ block showing what generates that SQL.

### Rule 2 — Logical Reads Are the Primary Performance Metric

"Faster" means nothing. "Reduces logical reads from 45,000 to 12" means something. Every performance comparison must use SET STATISTICS IO output or sys.dm_exec_query_stats logical_reads. Never use elapsed time alone as the metric.

### Rule 3 — Execution Plans Must Be Described

For every query example, Section 3 must describe the execution plan operators that will appear, whether there is a seek or scan, and what the key lookup situation is. Use the textual format: `[Clustered Index Seek] → [Nested Loops] → [SELECT]`.

### Rule 4 — SARGability Must Be Addressed

Every note covering a predicate, function, or WHERE clause condition must explicitly state: "This predicate IS SARGable" or "This predicate is NOT SARGable because [reason] — the optimizer cannot use an index seek and must scan." This is the single most important concept for SQL interview performance questions.

### Rule 5 — Both EF Core and Dapper Are Shown

Every .NET implementation section must show both EF Core and Dapper approaches where both are applicable. Notes in the Dapper group show only Dapper. Notes in the Database Patterns group show both. SQL-only notes (stored procedures, execution plans, server architecture) show the EF Core logging approach to observe the behavior.

### Rule 6 — Realistic Table Names

All SQL uses realistic business domain names: `Orders`, `Customers`, `Products`, `OrderItems`, `Payments`, `Invoices`, `ShipmentDetails`, `InventoryItems`, `ProductCategories`, `UserAccounts`, `AuditLog`. Never `Table1`, `MyTable`, `TestDB`.

### Rule 7 — Write Cost Is Always Disclosed

Every indexing note must explicitly state the write cost: how many additional page operations occur on INSERT/UPDATE/DELETE because of this index. "This index adds approximately N page writes per INSERT on a table with M rows and K existing non-clustered indexes."

### Rule 8 — Cross-References Connect SQL to .NET to System Design

Every note must link to at least 3 other notes. Required cross-references:

- At least 1 link within Domain 8 (related SQL or indexing concept)
- At least 1 link to Domain 3 (EF Core) or Domain 7 (System Design) where the database concept surfaces at the application or architecture level
- At least 1 link to a performance or monitoring note that shows how to detect or measure the concept

### Rule 9 — No Oversimplification of NULL

Any note that touches NULL behavior must explicitly state: "NULL is not a value — it is the absence of a value. SQL uses three-valued logic (TRUE, FALSE, UNKNOWN). Any comparison with NULL using = or <> returns UNKNOWN, not FALSE." This distinction causes production bugs regularly and must never be glossed over.

### Rule 10 — Redis Notes Show .NET Code

Every Redis note must include StackExchange.Redis code in .NET. Show `ConnectionMultiplexer`, `IDatabase`, the specific Redis command, and error handling. Redis Cluster and Sentinel notes must show how `ConnectionMultiplexer` handles failover.

---

## Priority Tier Reference

|Tier|Label|Interview frequency|
|---|---|---|
|1|Critical|Core SQL and indexing — will appear|
|2|High|Performance and advanced SQL — likely in senior rounds|
|3|Medium|Administration and specialized topics — deep dives|
|4|Reference|Completeness — rarely tested directly|

---

## Pre-Save Checklist

- [ ] YAML frontmatter complete — id, title, domain_id, group, priority, prerequisites, related
- [ ] All 9 sections present, fully populated
- [ ] Mermaid diagram in Section 2 — valid syntax
- [ ] Mermaid decision flowchart in Section 8
- [ ] Section 3 has actual T-SQL with SET STATISTICS IO context
- [ ] Section 3 has EF Core LINQ equivalent and generated SQL
- [ ] Section 3 describes the execution plan operators
- [ ] Section 3 explicitly states SARGability (for query/index topics)
- [ ] Section 4 has complete T-SQL + EF Core + Dapper (where applicable)
- [ ] Section 5 has minimum 4 pitfalls in Pitfall → Symptom → Fix → Cost format
- [ ] Section 6 has logical reads before/after comparison
- [ ] Section 6 has BenchmarkDotNet code
- [ ] Section 7 has spoken answers at two tiers for 3+ questions
- [ ] Section 9 has 10 conceptual questions + 5 query/concurrency challenges
- [ ] Minimum 3 Domain 8 wiki-links + 1 cross-domain link
- [ ] No Table1, MyTable, TestDB — all realistic domain names
- [ ] Write cost disclosed for all index topics
- [ ] NULL behavior addressed for any predicate topic
- [ ] File saved as `8_XXX_Topic_Name.md`