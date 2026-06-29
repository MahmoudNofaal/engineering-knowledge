# EF CORE DOMAIN — COMPLETE TOPIC INDEX

> **Purpose of this file:** The master list of every topic in the EF Core Mastery domain. Use it to track progress, pick the next topic to generate, and copy the `RELATED_TOPICS` value directly into the generation prompt.

---

## PROGRESS TRACKER

```
Total Topics:  30
Generated:      0
Remaining:     30
```

**Status Legend**

- ✅ Complete — note generated, reviewed
- 🔄 In Progress — being written
- ⬜ Not Started — queued

studied_well: false
---

## STUDY PRIORITY GUIDE

Before picking what to generate next, use this priority map:

```
TIER 1 — Generate First (interview + production critical)
  3.01     DbContext: Lifecycle, Internals, and DI Scoping
  3.02     Change Tracker: Entity States and the Unit of Work Pattern
  3.03     LINQ to SQL: Query Translation Pipeline
  3.04     Loading Strategies: Eager, Lazy, and Explicit Loading
  3.05     The N+1 Problem: Diagnosis and Solutions
  3.07     Migrations: Internals, Strategy, and Production Deployment

TIER 2 — Generate Second (interview important, production daily)
  3.06     Relationships: One-to-Many, Many-to-Many, and Configuration
  3.08     Performance: AsNoTracking and Read-Optimized Patterns
  3.09     Transactions and SaveChanges Internals
  3.10     Optimistic Concurrency: RowVersion and Conflict Resolution
  3.11     Bulk Operations: ExecuteUpdate and ExecuteDelete (EF7+)
  3.13     Global Query Filters: Multi-Tenancy and Soft Delete
  3.21     Testing EF Core: SQLite, InMemory Provider, and Mocking Strategies

TIER 3 — Generate Third (production important, interview moderate)
  3.12     Owned Entities and Value Converters
  3.14     Compiled Queries and Query Plan Caching
  3.15     Raw SQL: FromSqlRaw, ExecuteSqlRaw, and Stored Procedures
  3.22     Specification Pattern with IQueryable<T>
  3.23     Repository and Unit of Work: When to Use and When to Avoid
  3.24     Keyset Pagination and Cursor-Based Navigation
  3.26     Connection Resilience, Retry Policies, and Execution Strategies
  3.27     Fluent API Deep Dive: IEntityTypeConfiguration<T>

TIER 4 — Generate Last (advanced / specialist)
  3.16     Interceptors: DbCommandInterceptor and Connection Interceptors
  3.17     Shadow Properties, Backing Fields, and Keyless Entities
  3.18     Inheritance Mapping: TPH, TPT, and TPC
  3.19     JSON Columns and Complex Type Mapping (EF7+)
  3.20     Temporal Tables and Point-in-Time Queries (EF6+)
  3.25     Database Functions, EF.Functions, and Custom Translations
  3.28     Complex Mapping: Table Splitting and Shared-Type Entities
  3.29     Multi-Tenancy: Row-Level Security and Tenant Isolation Patterns
  3.30     Diagnostics: Logging, Query Plans, and Slow Query Detection
```

---

## FULL TOPIC TABLE

|ID|Topic Name|Status|Interview Importance|Production Importance|Tier|
|---|---|---|---|---|---|
|3.01|DbContext: Lifecycle, Internals, and DI Scoping|⬜|🔴 Critical|🔴 Critical|1|
|3.02|Change Tracker: Entity States and Unit of Work|⬜|🔴 Critical|🔴 Critical|1|
|3.03|LINQ to SQL: Query Translation Pipeline|⬜|🔴 Critical|🔴 Critical|1|
|3.04|Loading Strategies: Eager, Lazy, Explicit|⬜|🔴 Critical|🔴 Critical|1|
|3.05|The N+1 Problem: Diagnosis and Solutions|⬜|🔴 Critical|🔴 Critical|1|
|3.06|Relationships: Configuration and Navigation Props|⬜|🟠 High|🔴 Critical|2|
|3.07|Migrations: Internals, Strategy, and Deployment|⬜|🟠 High|🔴 Critical|1|
|3.08|Performance: AsNoTracking and Read-Only Patterns|⬜|🔴 Critical|🔴 Critical|2|
|3.09|Transactions and SaveChanges Internals|⬜|🟠 High|🔴 Critical|2|
|3.10|Optimistic Concurrency: RowVersion and Conflicts|⬜|🟠 High|🟠 High|2|
|3.11|Bulk Operations: ExecuteUpdate and ExecuteDelete|⬜|🟠 High|🔴 Critical|2|
|3.12|Owned Entities and Value Converters|⬜|🟡 Medium|🟠 High|3|
|3.13|Global Query Filters: Multi-Tenancy and Soft Delete|⬜|🟠 High|🟠 High|2|
|3.14|Compiled Queries and Query Plan Caching|⬜|🟡 Medium|🟠 High|3|
|3.15|Raw SQL: FromSqlRaw, ExecuteSqlRaw, Stored Procs|⬜|🟡 Medium|🟠 High|3|
|3.16|Interceptors: DbCommandInterceptor and Connection|⬜|🟡 Medium|🟡 Medium|4|
|3.17|Shadow Properties, Backing Fields, Keyless Entities|⬜|🟡 Medium|🟠 High|4|
|3.18|Inheritance Mapping: TPH, TPT, and TPC|⬜|🟠 High|🟠 High|4|
|3.19|JSON Columns and Complex Type Mapping (EF7+)|⬜|🟡 Medium|🟠 High|4|
|3.20|Temporal Tables and Point-in-Time Queries|⬜|🟡 Medium|🟡 Medium|4|
|3.21|Testing: SQLite, InMemory Provider, and Mocking|⬜|🟠 High|🔴 Critical|2|
|3.22|Specification Pattern with IQueryable<T>|⬜|🟡 Medium|🟠 High|3|
|3.23|Repository and Unit of Work: When to Use/Avoid|⬜|🟠 High|🟠 High|3|
|3.24|Keyset Pagination and Cursor-Based Navigation|⬜|🟡 Medium|🟠 High|3|
|3.25|Database Functions, EF.Functions, Custom Trans.|⬜|🟡 Medium|🟡 Medium|4|
|3.26|Connection Resilience, Retry, Execution Strategies|⬜|🟡 Medium|🟠 High|3|
|3.27|Fluent API Deep Dive: IEntityTypeConfiguration<T>|⬜|🟠 High|🔴 Critical|3|
|3.28|Complex Mapping: Table Splitting and Shared-Type|⬜|🟡 Medium|🟡 Medium|4|
|3.29|Multi-Tenancy: Row-Level Security and Isolation|⬜|🟡 Medium|🟠 High|4|
|3.30|Diagnostics: Logging, Query Plans, Slow Queries|⬜|🟡 Medium|🟠 High|4|

---

## TOPIC DETAILS — PROMPT VALUES

For each topic below you will find the exact values to paste into the generation prompt.

---

### 3.01 — DbContext: Lifecycle, Internals, and DI Scoping

**TOPIC_ID:** `3.01` **TOPIC_NAME:** `DbContext: Lifecycle, Internals, and DI Scoping` **RELATED_TOPICS:**

```
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — DbContext owns the Change Tracker; its lifetime determines what gets tracked
- [[3.09 — Transactions and SaveChanges Internals]] — SaveChanges opens/closes a transaction on the DbContext's connection
- [[3.21 — Testing EF Core]] — tests must configure DbContext correctly; AddDbContext scoping is the most common test setup mistake
- [[2.29 — Dependency Injection Internals]] — DbContext is Scoped by default; the captive dependency bug (Singleton → Scoped) is the top DI+EF mistake
- [[2.16 — IDisposable and Resource Management]] — DbContext implements IDisposable; not disposing it leaks the database connection
```

**Key topics inside this note:** `DbContext` internal state (connection, transaction, model, Change Tracker), `AddDbContext` vs `AddDbContextFactory`, scoped lifetime and why Singleton DbContext is a bug (shared Change Tracker, thread safety, stale data), `DbContextOptions<T>` and configuration, `OnModelCreating` execution (once per pool, cached), `DbContext pooling` (`AddDbContextPool`) and what it resets between requests, connection management (lazy open on first query, close on dispose), `IDbContextFactory<T>` for background workers, the classic ASP.NET Core scope bug.

---

### 3.02 — Change Tracker: Entity States and the Unit of Work Pattern

**TOPIC_ID:** `3.02` **TOPIC_NAME:** `Change Tracker: Entity States and the Unit of Work Pattern` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — DbContext IS the Unit of Work; the Change Tracker lives inside it
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — AsNoTracking bypasses the Change Tracker entirely; the most impactful read optimization
- [[3.09 — Transactions and SaveChanges Internals]] — SaveChanges reads the Change Tracker to build the INSERT/UPDATE/DELETE batch
- [[3.11 — Bulk Operations: ExecuteUpdate and ExecuteDelete]] — ExecuteUpdate/Delete bypass the Change Tracker; different performance profile
- [[2.01 — Value Types vs. Reference Types]] — snapshot-based change detection copies entity property values (value semantics for comparison)
```

**Key topics inside this note:** Five entity states (`Added`, `Unchanged`, `Modified`, `Deleted`, `Detached`) with full state machine diagram, snapshot-based vs. proxy-based change detection, `DetectChanges()` cost (O(n) scan of all tracked entities), `ChangeTracker.AutoDetectChangesEnabled = false` for batch insert optimization, `Entry(entity).State` manipulation for disconnected scenarios (API update pattern), `Attach()` vs `Update()` difference, `AsNoTracking()` and `AsNoTrackingWithIdentityResolution()`, tracking vs no-tracking memory comparison with 10k entities, `ChangeTracker.Clear()` for resetting in long-running services.

---

### 3.03 — LINQ to SQL: Query Translation Pipeline

**TOPIC_ID:** `3.03` **TOPIC_NAME:** `LINQ to SQL: Query Translation Pipeline` **RELATED_TOPICS:**

```
- [[2.06 — LINQ: Execution Model and Every Operator]] — the C# LINQ pipeline (IEnumerable<T>) is the foundation; IQueryable<T> adds expression-tree-based translation
- [[2.10 — Expression Trees]] — IQueryable<T> is built on expression trees, not compiled delegates; EF Core walks the tree to produce SQL
- [[3.04 — Loading Strategies: Eager, Lazy, and Explicit Loading]] — Include() modifies the IQueryable<T> expression tree before translation
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — AsNoTracking() is appended to the expression tree and alters the materialization pipeline
- [[3.14 — Compiled Queries and Query Plan Caching]] — compiled queries skip expression tree walking on every call; understanding the pipeline shows why this matters
```

**Key topics inside this note:** `IQueryable<T>` vs `IEnumerable<T>` — the database execution boundary, EF Core query pipeline stages (model → query compiler → relational command generator → ADO.NET execution → result materialization), expression tree walking and where translation fails (throws `InvalidOperationException: could not be translated`), client evaluation removal in EF Core 3.0 and why it was the right call, `ToList()` / `FirstOrDefault()` / `Any()` as the SQL execution triggers, deferred execution and the "query is executed when iterated" rule, `IQueryable` composition before execution, `EF.Property<T>()` for accessing shadow properties in queries, provider-specific SQL generation differences (SQL Server vs PostgreSQL vs SQLite).

---

### 3.04 — Loading Strategies: Eager, Lazy, and Explicit Loading

**TOPIC_ID:** `3.04` **TOPIC_NAME:** `Loading Strategies: Eager, Lazy, and Explicit Loading` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — eager loading via Include() is translated to JOINs or split queries in the SQL pipeline
- [[3.05 — The N+1 Problem: Diagnosis and Solutions]] — lazy loading is the primary cause of N+1; understanding the distinction between strategies is the fix
- [[3.06 — Relationships: Configuration and Navigation Properties]] — loading strategies operate on navigation properties; the relationship must be configured correctly
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — no-tracking + projection is faster than eager loading for read-only scenarios
```

**Key topics inside this note:** Eager loading with `Include()` and `ThenInclude()` — generated SQL (LEFT JOIN or split query), `AsSplitQuery()` vs single query tradeoffs (N+1 vs Cartesian explosion), lazy loading via proxies (`UseLazyLoadingProxies`) and via `ILazyLoader` injection — what the proxy generates at runtime, explicit loading with `Entry(e).Collection(e => e.Orders).LoadAsync()`, `Entry(e).Reference(e => e.Customer).LoadAsync()`, filtered includes (`Include(o => o.Items.Where(i => i.IsActive))`), projection as the alternative to all three strategies (zero navigation loading), `AsSingleQuery` vs `AsSplitQuery` benchmark with Cartesian explosion example.

---

### 3.05 — The N+1 Problem: Diagnosis and Solutions

**TOPIC_ID:** `3.05` **TOPIC_NAME:** `The N+1 Problem: Diagnosis and Solutions` **RELATED_TOPICS:**

```
- [[3.04 — Loading Strategies: Eager, Lazy, and Explicit Loading]] — N+1 is caused by lazy loading or implicit navigation access; eager loading and projection are the solutions
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — understanding that navigation access outside IQueryable triggers a new query is key
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — projection is the fastest N+1 fix; AsNoTracking removes tracking overhead from the solution
- [[3.30 — Diagnostics: Logging, Query Plans, and Slow Query Detection]] — N+1 is detected via query logging; EnableSensitiveDataLogging reveals the pattern
```

**Key topics inside this note:** What N+1 is (1 query to load N entities + N queries to load related data = N+1 total), why lazy loading is the silent cause (accessing `.Orders` on a tracked `Customer` fires a query per customer), how to detect it (EF Core logging, MiniProfiler, Application Insights query count), the three fixes: `Include()` (single-query with JOIN), projection with `Select()` (no navigation loading at all), explicit batching with `LoadAsync()`, the Cartesian explosion problem with multiple `Include()` calls (when `AsSplitQuery` is the right trade-off), `SelectMany` for flattening nested includes, benchmark showing 1 query vs N+1 queries at 1000 rows.

---

### 3.06 — Relationships: One-to-Many, Many-to-Many, and Configuration

**TOPIC_ID:** `3.06` **TOPIC_NAME:** `Relationships: One-to-Many, Many-to-Many, and Configuration` **RELATED_TOPICS:**

```
- [[3.04 — Loading Strategies: Eager, Lazy, and Explicit Loading]] — relationships define what navigation properties exist; loading strategies determine when they are populated
- [[3.12 — Owned Entities and Value Converters]] — owned entities are a special relationship type: fully dependent, no separate identity
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — relationship configuration lives in OnModelCreating or IEntityTypeConfiguration<T>
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — relationship configuration drives the foreign key columns and indexes in migrations
```

**Key topics inside this note:** One-to-many configuration (HasMany/WithOne, HasForeignKey, IsRequired, cascade delete), many-to-many with auto join table (EF5+) vs explicit join entity, one-to-one (HasOne/WithOne, principal vs dependent), required vs optional relationships (nullable FK vs non-nullable FK), cascade delete behaviors (`Cascade`, `SetNull`, `Restrict`, `NoAction`) and their SQL implications, shadow foreign key properties, navigation property naming conventions (when EF Core infers relationships automatically), self-referencing relationships (category trees, employee hierarchy), `DeleteBehavior` and the ON DELETE constraints generated in migrations.

---

### 3.07 — Migrations: Internals, Strategy, and Production Deployment

**TOPIC_ID:** `3.07` **TOPIC_NAME:** `Migrations: Internals, Strategy, and Production Deployment` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — the model snapshot that migrations diff against is owned by the DbContext
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — Fluent API configuration is the source of truth the migration generator reads
- [[3.18 — Inheritance Mapping: TPH, TPT, and TPC]] — TPH vs TPT vs TPC generate radically different migration SQL; understanding migrations is prerequisite
```

**Key topics inside this note:** Migration internals (`ModelSnapshot`, `MigrationBuilder`, the `__EFMigrationsHistory` table), `dotnet ef migrations add` pipeline (model diff → operations → SQL), `Up()` vs `Down()` methods and why `Down()` is often wrong in production, `MigrationBuilder.Sql()` for raw SQL in migrations, data migrations (populating data during schema change), zero-downtime migration strategies (expand-contract pattern, adding nullable columns first), `DbContext.Database.MigrateAsync()` in startup vs CLI deployment, environment-specific migrations, the idempotency problem (`IF NOT EXISTS` patterns), `EnsureCreated()` vs `Migrate()` and why you never use `EnsureCreated()` in production.

---

### 3.08 — Performance: AsNoTracking and Read-Optimized Patterns

**TOPIC_ID:** `3.08` **TOPIC_NAME:** `Performance: AsNoTracking and Read-Optimized Patterns` **RELATED_TOPICS:**

```
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — AsNoTracking bypasses the Change Tracker entirely; knowing what the tracker does explains why bypassing it helps
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — projections limit columns in the SELECT clause; understanding query translation shows how much work EF Core skips
- [[3.05 — The N+1 Problem: Diagnosis and Solutions]] — projection is both an N+1 fix and a read performance tool
- [[3.14 — Compiled Queries and Query Plan Caching]] — compiled queries + AsNoTracking is the maximum read performance configuration
- [[2.15 — Performance: Zero-Allocation Patterns]] — same philosophy: measure first, eliminate unnecessary work, use the right tool for the job
```

**Key topics inside this note:** `AsNoTracking()` — what it skips (snapshot allocation, identity map lookup, DetectChanges), when to use it (all read-only queries), `AsNoTrackingWithIdentityResolution()` for reads with related entities that must be deduplicated, projection with `Select()` — why returning DTOs instead of entities reduces SQL column count and allocation, `ToListAsync()` vs `ToArrayAsync()` vs streaming with `AsAsyncEnumerable()` for large result sets, `AsSplitQuery()` for eager loading with multiple collections, benchmark: tracked vs no-tracking vs projection at 10k rows, `DbContext.ChangeTracker.QueryTrackingBehavior = QueryTrackingBehavior.NoTracking` as the global default for read-heavy services.

---

### 3.09 — Transactions and SaveChanges Internals

**TOPIC_ID:** `3.09` **TOPIC_NAME:** `Transactions and SaveChanges Internals` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — SaveChanges uses the DbContext's connection; the transaction is scoped to the DbContext
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — SaveChanges reads all Modified/Added/Deleted entries from the Change Tracker to build the command batch
- [[3.10 — Optimistic Concurrency: RowVersion and Conflict Resolution]] — DbUpdateConcurrencyException is thrown inside SaveChanges when a RowVersion check fails
- [[3.11 — Bulk Operations: ExecuteUpdate and ExecuteDelete]] — ExecuteUpdate/Delete bypass SaveChanges and issue a single SQL statement directly
- [[2.23 — Threading Primitives]] — DbContext is not thread-safe; concurrent SaveChanges calls on the same context are a bug
```

**Key topics inside this note:** `SaveChanges()` internal pipeline (DetectChanges → build command batch → open transaction → execute commands → commit → update entity states → return count), implicit transaction (SaveChanges wraps everything in one transaction automatically), explicit transaction with `context.Database.BeginTransactionAsync()`, `IDbContextTransaction` and `CommitAsync()`/`RollbackAsync()`, cross-DbContext transactions with `UseTransaction()`, savepoints (EF Core 5+), `SaveChangesAsync` vs `SaveChanges` — always prefer async in ASP.NET Core, `DbUpdateException` vs `DbUpdateConcurrencyException`, `ISaveChangesInterceptor` for auditing (CreatedAt/UpdatedAt via interceptor), the `SaveChanges` return value (number of rows affected).

---

### 3.10 — Optimistic Concurrency: RowVersion and Conflict Resolution

**TOPIC_ID:** `3.10` **TOPIC_NAME:** `Optimistic Concurrency: RowVersion and Conflict Resolution` **RELATED_TOPICS:**

```
- [[3.09 — Transactions and SaveChanges Internals]] — DbUpdateConcurrencyException is thrown during SaveChanges when the WHERE clause of the UPDATE finds no rows
- [[3.17 — Shadow Properties, Backing Fields, and Keyless Entities]] — RowVersion is often configured as a shadow property (no C# field needed)
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — EF Core tracks the original RowVersion value in the Change Tracker for comparison
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — IsConcurrencyToken() and IsRowVersion() are Fluent API configuration calls
```

**Key topics inside this note:** Optimistic vs pessimistic concurrency — when each is appropriate, `[Timestamp]` attribute and `IsRowVersion()` Fluent API — what SQL is generated (`WHERE Id = @id AND RowVersion = @rowVersion`), the `DbUpdateConcurrencyException` — what it contains (original values, current values, database values), conflict resolution strategies: last-write-wins, client-wins, database-wins, merge-fields, `entry.Reload()` pattern, `entry.OriginalValues` vs `entry.CurrentValues` vs `entry.GetDatabaseValues()`, `xmin` column in PostgreSQL as a free concurrency token, ETag-based concurrency for HTTP APIs with `[ConcurrencyCheck]` on individual properties.

---

### 3.11 — Bulk Operations: ExecuteUpdate and ExecuteDelete (EF7+)

**TOPIC_ID:** `3.11` **TOPIC_NAME:** `Bulk Operations: ExecuteUpdate and ExecuteDelete (EF7+)` **RELATED_TOPICS:**

```
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — ExecuteUpdate/Delete bypass the Change Tracker; entities modified this way are NOT reflected in tracked entities
- [[3.09 — Transactions and SaveChanges Internals]] — ExecuteUpdate/Delete run in the ambient transaction if one exists; otherwise they auto-commit
- [[3.15 — Raw SQL: FromSqlRaw, ExecuteSqlRaw, and Stored Procedures]] — ExecuteSqlRaw is the pre-EF7 alternative; ExecuteUpdate is safer (no SQL injection risk)
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — same performance philosophy: avoid the Change Tracker overhead for write-heavy paths
```

**Key topics inside this note:** `ExecuteUpdateAsync()` — syntax, generated SQL (`UPDATE ... SET ... WHERE`), no Change Tracker involvement, `ExecuteDeleteAsync()` — syntax, generated SQL (`DELETE FROM ... WHERE`), the critical caveat: tracked entities are NOT updated (stale state after ExecuteUpdate), combining with `Where()` for filtered bulk updates, batch size limits and chunking pattern for very large updates, `EFCore.BulkExtensions` for pre-EF7 bulk operations or for INSERT scenarios, when NOT to use bulk ops (when you need auditing interceptors, when you need RowVersion checks), benchmark: SaveChanges loop vs ExecuteUpdate at 10k rows.

---

### 3.12 — Owned Entities and Value Converters

**TOPIC_ID:** `3.12` **TOPIC_NAME:** `Owned Entities and Value Converters` **RELATED_TOPICS:**

```
- [[3.06 — Relationships: Configuration and Navigation Properties]] — owned entities are a dependent entity type with no independent identity; a special relationship
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — OwnsOne/OwnsMany and HasConversion are Fluent API calls
- [[3.19 — JSON Columns and Complex Type Mapping (EF7+)]] — in EF8, owned entities can be mapped to JSON columns with ToJson()
- [[2.01 — Value Types vs. Reference Types]] — owned entities implement the Domain-Driven Design value object pattern, which parallels struct value semantics in C#
```

**Key topics inside this note:** Owned entities (`OwnsOne`, `OwnsMany`) — what they are, how they map (columns embedded in owner table by default), vs separate table with `ToTable()`, `Address` as a canonical owned entity example, null handling for optional owned entities, `OwnsMany` — collection of owned entities mapped to a separate table with shadow FK, value converters (`HasConversion<T>`) — converting domain types to primitives for storage (Money → decimal, Email → string, Status → int), built-in converters (`EnumToStringConverter`, `DateTimeOffsetToBinaryConverter`), custom converter for encrypted values, performance: owned entities have no extra JOIN (same table), value converters do not translate comparison operators in all providers.

---

### 3.13 — Global Query Filters: Multi-Tenancy and Soft Delete

**TOPIC_ID:** `3.13` **TOPIC_NAME:** `Global Query Filters: Multi-Tenancy and Soft Delete` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — global filters are injected into the IQueryable<T> expression tree before SQL translation
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — filters are configured in OnModelCreating; tenant context must be injected into the DbContext
- [[3.29 — Multi-Tenancy: Row-Level Security and Tenant Isolation Patterns]] — global filters are the primary mechanism for row-level tenant isolation in EF Core
```

**Key topics inside this note:** `HasQueryFilter(e => !e.IsDeleted)` — what SQL is appended to every query, soft delete pattern (IsDeleted column, DeletedAt timestamp, filter auto-applies), `IgnoreQueryFilters()` for admin/restore scenarios, multi-tenant filter with `ITenantProvider` injected into DbContext (generated SQL includes `WHERE TenantId = @tenantId`), combining multiple filters (soft delete + tenant — both WHERE conditions), performance: index on IsDeleted + TenantId is mandatory for filtered queries to use indexes, filter with null check for optional tenancy, the gotcha: `Include()` of soft-deleted navigations — filters apply on includes too.

---

### 3.14 — Compiled Queries and Query Plan Caching

**TOPIC_ID:** `3.14` **TOPIC_NAME:** `Compiled Queries and Query Plan Caching` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — compiled queries skip the expression tree → SQL translation step; understanding what gets skipped shows why they're faster
- [[2.10 — Expression Trees]] — query compilation walks an expression tree and caches the resulting SQL template; compiled queries pre-compute this once
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — compiled queries + AsNoTracking is the maximum read throughput configuration
```

**Key topics inside this note:** EF Core's internal query plan cache (keyed on expression tree shape — parameter values are separate), what `EF.CompileQuery()` does (caches the compiled delegate at class level, skips all translation on subsequent calls), `EF.CompileAsyncQuery()` for async paths, syntax with typed parameters, when compiled queries matter most (high-throughput APIs, queries called >100 req/s), the limitation: compiled queries cannot use dynamically built expressions (no conditional includes), `CompiledQueryCacheHitRate` counter via metrics, the `@__p_0` parameterization pattern and why EF Core parameterizes by default (SQL injection prevention + query plan reuse in SQL Server).

---

### 3.15 — Raw SQL: FromSqlRaw, ExecuteSqlRaw, and Stored Procedures

**TOPIC_ID:** `3.15` **TOPIC_NAME:** `Raw SQL: FromSqlRaw, ExecuteSqlRaw, and Stored Procedures` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — use raw SQL when EF Core's LINQ translator cannot express the query; raw SQL bypasses the translator entirely
- [[3.11 — Bulk Operations: ExecuteUpdate and ExecuteDelete]] — ExecuteSqlRaw is the pre-EF7 alternative for bulk writes; prefer ExecuteUpdate/Delete when possible
- [[3.09 — Transactions and SaveChanges Internals]] — raw SQL executes on the same connection/transaction as the DbContext
```

**Key topics inside this note:** `FromSqlRaw()` vs `FromSqlInterpolated()` (SQL injection safety), composing LINQ on top of raw SQL (`FromSqlRaw().Where().OrderBy()`), `ExecuteSqlRawAsync()` for non-query statements (UPDATE, DELETE, stored procs without results), `SqlParameter` and parameterization for `FromSqlRaw()`, calling stored procedures with output parameters, `SqlQueryRaw<T>()` (EF7+) for ad-hoc type mapping (no entity type needed), when to drop to Dapper: multiple result sets, highly complex SQL that doesn't compose well, reporting queries, benchmark: EF LINQ vs EF raw SQL vs Dapper for the same query, SQL injection prevention: why string interpolation with `$""` is safe in `FromSqlInterpolated` but dangerous in `FromSqlRaw`.

---

### 3.16 — Interceptors: DbCommandInterceptor and Connection Interceptors

**TOPIC_ID:** `3.16` **TOPIC_NAME:** `Interceptors: DbCommandInterceptor and Connection Interceptors` **RELATED_TOPICS:**

```
- [[3.30 — Diagnostics: Logging, Query Plans, and Slow Query Detection]] — interceptors are the hook for custom query diagnostics and slow query alerting
- [[3.09 — Transactions and SaveChanges Internals]] — ISaveChangesInterceptor is the hook for auditing and soft-delete automation
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — IDbCommandInterceptor runs after SQL generation; it sees the final SQL string
```

**Key topics inside this note:** `IDbCommandInterceptor` — `ReaderExecutingAsync`, `ScalarExecutingAsync`, `NonQueryExecutingAsync` and their result counterparts, query hints injection interceptor (adding `WITH (NOLOCK)` or query tags), slow query logging interceptor (log queries taking > threshold), `ISaveChangesInterceptor` — `SavingChangesAsync` for pre-save auditing (auto-set CreatedAt/UpdatedAt/TenantId), `SavedChangesAsync` for post-save events, `IDbConnectionInterceptor` for connection events, `IDbTransactionInterceptor` for distributed transaction correlation, registering interceptors via `optionsBuilder.AddInterceptors()`, performance: interceptors are synchronous hooks in the hot path — keep them fast.

---

### 3.17 — Shadow Properties, Backing Fields, and Keyless Entities

**TOPIC_ID:** `3.17` **TOPIC_NAME:** `Shadow Properties, Backing Fields, and Keyless Entities` **RELATED_TOPICS:**

```
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — shadow properties are configured with Property<T>("PropertyName") in Fluent API
- [[3.10 — Optimistic Concurrency: RowVersion and Conflict Resolution]] — RowVersion can be a shadow property; EF Core tracks the original value in the Change Tracker
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — shadow properties generate real columns in migrations; they are first-class citizens of the schema
```

**Key topics inside this note:** Shadow properties — properties that exist in the EF model and database but have no corresponding C# property (audit columns: `CreatedAt`, `UpdatedAt`, `TenantId`), `EF.Property<T>(entity, "PropertyName")` for querying shadow properties, `entry.Property("CreatedAt").CurrentValue` for reading/writing, backing fields (`HasField("_fieldName")`) for encapsulated DDD entities where setters should be private, `UsePropertyAccessMode(PropertyAccessMode.Field)`, keyless entity types (`HasNoKey()`) for views, raw SQL results, and read-only projections — they cannot be tracked or modified, `ToView()` for mapping to a database view with no migrations generated.

---

### 3.18 — Inheritance Mapping: TPH, TPT, and TPC

**TOPIC_ID:** `3.18` **TOPIC_NAME:** `Inheritance Mapping: TPH, TPT, and TPC` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — TPH adds a discriminator WHERE clause to every query; TPT generates JOINs; TPC generates UNION ALL
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — TPH generates one table; TPT generates N tables; TPC generates N tables, each with all columns
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — inheritance strategy is configured via HasDiscriminator(), ToTable(), UseTpcMappingStrategy()
- [[2.04 — Pattern Matching]] — polymorphic entity access via C# type patterns maps to discriminator WHERE clauses in SQL
```

**Key topics inside this note:** Table-per-Hierarchy (TPH) — single table, discriminator column, generated SQL (`WHERE Discriminator = 'Order'`), sparse columns, performance (one table, index on discriminator), Table-per-Type (TPT) — one table per type, JOINs on every query, `INSERT` touches multiple tables, bad performance at scale, Table-per-Concrete-Type (TPC, EF7+) — one table per concrete type, no JOINs, `UNION ALL` for polymorphic queries, no shared identity strategy warning, when each strategy is correct: TPH for most cases, TPC for rare high-performance polymorphism, TPT almost never (avoid in production), discriminator value customization, `OfType<T>()` and the SQL it generates.

---

### 3.19 — JSON Columns and Complex Type Mapping (EF7+)

**TOPIC_ID:** `3.19` **TOPIC_NAME:** `JSON Columns and Complex Type Mapping (EF7+)` **RELATED_TOPICS:**

```
- [[3.12 — Owned Entities and Value Converters]] — in EF8, owned entities are mapped to JSON columns with ToJson(); this is the primary JSON column configuration path
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — EF Core translates LINQ predicates on JSON properties to JSON path queries (JSON_VALUE, jsonb operators)
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — ToJson() is a Fluent API call on the owned entity configuration
```

**Key topics inside this note:** `OwnsOne(..., b => b.ToJson())` — mapping owned entities to a JSON column, `OwnsMany(..., b => b.ToJson())` — collection of owned entities in a JSON array column, generated SQL for JSON property access (`JSON_VALUE(column, '$.PropertyName')` on SQL Server, `column->>'PropertyName'` on PostgreSQL), LINQ predicates on JSON properties — what translates and what doesn't, EF8 complex types (`ComplexProperty`) vs owned entities — the distinction (complex types have no key, no table, no change tracking), `System.Text.Json` serialization used under the hood, performance: JSON columns vs normalized tables (denormalization trade-off), migration SQL for adding a JSON column.

---

### 3.20 — Temporal Tables and Point-in-Time Queries

**TOPIC_ID:** `3.20` **TOPIC_NAME:** `Temporal Tables and Point-in-Time Queries` **RELATED_TOPICS:**

```
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — temporal table configuration generates a migration with system-versioning SQL
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — TemporalAsOf/TemporalBetween methods generate FOR SYSTEM_TIME AS OF SQL (SQL Server)
- [[3.09 — Transactions and SaveChanges Internals]] — the period columns (ValidFrom, ValidTo) are automatically maintained by SQL Server inside the transaction
```

**Key topics inside this note:** `IsTemporal()` Fluent API configuration, migration SQL generated (`WITH SYSTEM_VERSIONING = ON`, history table), `TemporalAsOf(DateTime point)` — returns the state at a specific moment (generated SQL: `FOR SYSTEM_TIME AS OF`), `TemporalBetween/TemporalContainedIn/TemporalFromTo/TemporalAll` for range queries, `EF.Property<DateTime>(entity, "ValidFrom")` for accessing period columns in LINQ, use cases: audit trail, point-in-time recovery, slowly changing dimensions, current limitations (SQL Server only in EF Core 8; PostgreSQL temporal via custom mapping), performance: history table growth, index strategy for temporal queries.

---

### 3.21 — Testing EF Core: SQLite, InMemory Provider, and Mocking Strategies

**TOPIC_ID:** `3.21` **TOPIC_NAME:** `Testing EF Core: SQLite, InMemory Provider, and Mocking Strategies` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — test setup requires correct DbContext configuration; the most common mistake is leaking state between tests
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — EnsureCreated() creates the schema from the model without migrations; Migrate() runs migrations; tests should use EnsureCreated()
- [[2.29 — Dependency Injection Internals]] — integration tests configure a test DI container; IServiceScope per test is the correct pattern
```

**Key topics inside this note:** SQLite in-memory vs InMemory provider — key difference (SQLite enforces relational constraints, InMemory doesn't; SQLite is the correct choice for most tests), `UseInMemoryDatabase` vs `UseSqlite("DataSource=:memory:")` — when each is appropriate, `EnsureCreated()` in test setup, `EnsureDeleted()` + `EnsureCreated()` for test isolation, per-test DbContext with a unique database name, `WebApplicationFactory<T>` integration testing with a real SQLite database, repository/service testing without the database (mock the DbContext interface or use `DbSet<T>` replacements), `Microsoft.EntityFrameworkCore.InMemory` limitations (no transactions, no raw SQL, no joins in some cases), test data builders (Object Mother pattern) for seeding test data.

---

### 3.22 — Specification Pattern with IQueryable<T>

**TOPIC_ID:** `3.22` **TOPIC_NAME:** `Specification Pattern with IQueryable<T>` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — specifications compose IQueryable<T> expression trees; the full query is still translated to a single SQL statement
- [[2.10 — Expression Trees]] — specifications store Expression<Func<T, bool>> trees; combining them with AndAlso/OrElse builds a new tree that translates to a single WHERE clause
- [[3.13 — Global Query Filters: Multi-Tenancy and Soft Delete]] — global query filters use the same expression-tree injection mechanism as specifications
```

**Key topics inside this note:** `ISpecification<T>` interface with `Criteria`, `Includes`, `OrderBy`, `IsPagingEnabled` properties, `Expression<Func<T, bool>>` vs `Func<T, bool>` — why specifications must use Expression (it stays in the query tree and becomes SQL, not a C# predicate that loads all rows), `AndSpecification<T>` and `OrSpecification<T>` using `Expression.AndAlso` / `Expression.OrElse`, `SpecificationEvaluator<T>` applying a specification to an `IQueryable<T>`, generated SQL showing the combined WHERE clause, the Ardalis.Specification library as a production-ready implementation, when specifications are worth it (domain-rich queries, reusable filter logic) vs when they are overkill (simple CRUD endpoints).

---

### 3.23 — Repository and Unit of Work: When to Use and When to Avoid

**TOPIC_ID:** `3.23` **TOPIC_NAME:** `Repository and Unit of Work: When to Use and When to Avoid` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — DbContext IS the Unit of Work; adding a UoW wrapper is often redundant
- [[3.02 — Change Tracker: Entity States and Unit of Work]] — DbSet<T> IS a repository; Change Tracker IS the identity map; understanding this is the key to deciding whether to add an abstraction
- [[3.22 — Specification Pattern with IQueryable<T>]] — repositories often use specifications to encapsulate query logic; the specification is more useful than the repository
```

**Key topics inside this note:** DbContext as the built-in Unit of Work (IUnitOfWork interface over DbContext), DbSet<T> as the built-in Repository (`IRepository<T>` over DbSet<T>), the argument for repositories: testability (mocking), separation of concerns, the argument against: leaky abstraction, `IQueryable<T>` leaks through anyway, double maintenance cost, the pragmatic middle ground: `IOrderRepository` for domain-specific queries only (not CRUD), generic `IRepository<T>` is an anti-pattern in modern EF Core, mocking DbContext directly with in-memory SQLite as the better testing strategy, DDD aggregate roots and why repositories map to aggregates, not entities.

---

### 3.24 — Keyset Pagination and Cursor-Based Navigation

**TOPIC_ID:** `3.24` **TOPIC_NAME:** `Keyset Pagination and Cursor-Based Navigation` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — keyset pagination uses WHERE key > @lastKey instead of OFFSET; understanding query translation shows why this is a different SQL structure
- [[3.08 — Performance: AsNoTracking and Read-Only Patterns]] — pagination queries are always read-only; AsNoTracking is mandatory
```

**Key topics inside this note:** Offset pagination (`Skip(n).Take(n)`) — generated SQL (`OFFSET n ROWS FETCH NEXT n ROWS ONLY`), the performance problem (O(n) full scan to reach page N, inconsistent on concurrent inserts), keyset pagination — `WHERE Id > @lastId ORDER BY Id` — O(1) regardless of page depth, the cursor strategy (encode the last-seen values, pass as parameter), compound keyset for non-unique sort keys (`WHERE (CreatedAt, Id) > (@lastCreatedAt, @lastId)`), forward-only vs bidirectional cursors, GraphQL-style cursor encoding (base64), benchmark: OFFSET page 1000 vs keyset page 1000 at 1M rows, when offset is acceptable (admin UI, small tables, predictable size).

---

### 3.25 — Database Functions, EF.Functions, and Custom Translations

**TOPIC_ID:** `3.25` **TOPIC_NAME:** `Database Functions, EF.Functions, and Custom Translations` **RELATED_TOPICS:**

```
- [[3.03 — LINQ to SQL: Query Translation Pipeline]] — custom function translations extend the LINQ-to-SQL translator; they register new expression nodes that map to SQL function calls
- [[3.15 — Raw SQL: FromSqlRaw, ExecuteSqlRaw, and Stored Procedures]] — raw SQL is the escape hatch when function translation is not worth building
- [[2.10 — Expression Trees]] — function translations register handlers in the expression tree visitor
```

**Key topics inside this note:** Built-in `EF.Functions` — `Like()`, `FreeText()`, `Contains()`, `DateDiffDay()`, `AtTimeZone()`, `IsNumeric()`, `Random()`, user-defined function mapping with `[DbFunction]` attribute and Fluent API `HasDbFunction()`, scalar UDF mapping (C# stub method → SQL function call), `IMethodCallTranslator` for custom LINQ method → SQL translation, `DbFunctions` extension class pattern for provider-specific functions, aggregate function mapping (`HasTranslation` with aggregation), niladic functions (no parameters, e.g. `GETDATE()`), what cannot be translated (most custom C# logic) and how to detect it via the `InvalidOperationException: could not be translated` message.

---

### 3.26 — Connection Resilience, Retry Policies, and Execution Strategies

**TOPIC_ID:** `3.26` **TOPIC_NAME:** `Connection Resilience, Retry Policies, and Execution Strategies` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — execution strategies are configured on DbContextOptions; they wrap the connection/command lifecycle
- [[3.09 — Transactions and SaveChanges Internals]] — the critical gotcha: explicit transactions require manual execution strategy calls; SaveChanges is NOT retried automatically inside a user transaction
```

**Key topics inside this note:** `EnableRetryOnFailure()` — what it configures (SqlServerRetryingExecutionStrategy with exponential backoff), transient error detection (SQL error codes that are safe to retry vs ones that are not), `IExecutionStrategy.ExecuteAsync()` — the required wrapper for explicit transactions (without this, the transaction is not retried), the idempotency requirement for retried operations (why non-idempotent operations are dangerous with retry), `Polly` as an alternative for cross-cutting retry with circuit breaker, Azure SQL transient fault codes vs PostgreSQL vs SQLite, connection pool configuration (`MaxPoolSize`, `MinPoolSize`, `ConnectTimeout`), connection pool exhaustion symptoms and diagnosis.

---

### 3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>

**TOPIC_ID:** `3.27` **TOPIC_NAME:** `Fluent API Deep Dive: IEntityTypeConfiguration<T>` **RELATED_TOPICS:**

```
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — OnModelCreating is where Fluent API is applied; DbContext.Model is the cached result
- [[3.06 — Relationships: Configuration and Navigation Properties]] — HasMany/HasOne/WithMany/WithOne are Fluent API calls
- [[3.07 — Migrations: Internals, Strategy, and Production Deployment]] — the model built by Fluent API is diffed against the snapshot to generate migration operations
- [[3.12 — Owned Entities and Value Converters]] — OwnsOne/OwnsMany/HasConversion are Fluent API calls
```

**Key topics inside this note:** `IEntityTypeConfiguration<T>` for separating configuration per entity (over bloated `OnModelCreating`), `ApplyConfigurationsFromAssembly()` for auto-discovery, key configuration (`HasKey`, composite keys, `HasAlternateKey`), index configuration (`HasIndex`, `IsUnique`, `IncludeProperties` for covering indexes), column configuration (`HasColumnName`, `HasColumnType`, `HasDefaultValue`, `HasComputedColumnSql`), table configuration (`ToTable`, `HasCheckConstraint`, `HasTrigger`), precision and scale for decimal columns (critical — EF Core default decimal is `decimal(18,2)`), the order of Fluent API and data annotations (Fluent API wins), convention-based vs explicit configuration trade-offs.

---

### 3.28 — Complex Mapping: Table Splitting and Shared-Type Entities

**TOPIC_ID:** `3.28` **TOPIC_NAME:** `Complex Mapping: Table Splitting and Shared-Type Entities` **RELATED_TOPICS:**

```
- [[3.18 — Inheritance Mapping: TPH, TPT, and TPC]] — TPT is a form of complex multi-table mapping; its JOIN overhead makes it a cautionary tale
- [[3.12 — Owned Entities and Value Converters]] — table splitting maps two entity types to one table; owned entities in the same table use the same mechanism
- [[3.27 — Fluent API Deep Dive: IEntityTypeConfiguration<T>]] — all complex mapping scenarios require explicit Fluent API configuration
```

**Key topics inside this note:** Table splitting — two C# entity types mapped to one database table (share a primary key), use case (lazy-load large columns like `ProductDescription` only when needed), generated SQL (SELECT with specific columns, JOIN when loading the split entity), shared-type entity types (dictionary-of-string mapping pattern), `EntitySplitting` (EF7+) — single entity split across multiple tables by column groups, when table splitting is useful (BLOB/CLOB columns on high-read entities), the gotcha: both entity types must always be saved together (same transaction, both sides required for INSERT), mapping to a view with `ToView()` as a simpler alternative to read-splitting.

---

### 3.29 — Multi-Tenancy: Row-Level Security and Tenant Isolation Patterns

**TOPIC_ID:** `3.29` **TOPIC_NAME:** `Multi-Tenancy: Row-Level Security and Tenant Isolation Patterns` **RELATED_TOPICS:**

```
- [[3.13 — Global Query Filters: Multi-Tenancy and Soft Delete]] — global query filters are the EF Core mechanism for automatic tenant isolation in queries
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — the per-request DbContext scope is what makes per-tenant context injection safe
- [[2.29 — Dependency Injection Internals]] — ITenantProvider is injected into DbContext via DI; understanding scope lifetimes is prerequisite
```

**Key topics inside this note:** Three multi-tenancy strategies in EF Core: separate databases (DbContext per tenant with a connection string resolver), separate schemas (same DB, schema-per-tenant, `ToSchema()` in Fluent API), shared tables (TenantId column + global query filter), `ITenantProvider` injected into DbContext constructor, global filter: `HasQueryFilter(e => e.TenantId == _tenantProvider.TenantId)`, ensuring `TenantId` is set on `ISaveChangesInterceptor`, index strategy: composite index on `(TenantId, Id)` is mandatory for performance, database-level row security (SQL Server RLS, PostgreSQL Row Security Policy) as a defense-in-depth layer, the global filter bypass risk with `IgnoreQueryFilters()` — audit all usages.

---

### 3.30 — Diagnostics: Logging, Query Plans, and Slow Query Detection

**TOPIC_ID:** `3.30` **TOPIC_NAME:** `Diagnostics: Logging, Query Plans, and Slow Query Detection` **RELATED_TOPICS:**

```
- [[3.16 — Interceptors: DbCommandInterceptor and Connection Interceptors]] — interceptors are the hook for capturing slow queries and adding diagnostics
- [[3.05 — The N+1 Problem: Diagnosis and Solutions]] — N+1 is detected by observing query counts in logs; EnableSensitiveDataLogging reveals parameter values
- [[3.14 — Compiled Queries and Query Plan Caching]] — identify hot queries via logging, then compile them; diagnostics drives the optimization workflow
```

**Key topics inside this note:** `optionsBuilder.LogTo(Console.WriteLine, LogLevel.Information)` for development logging, `EnableSensitiveDataLogging()` and when NOT to use it in production (logs parameter values), `EnableDetailedErrors()` for inner exception details, MiniProfiler integration with EF Core (query count + duration per request), `DbCommandInterceptor` for slow query alerting (log queries > 500ms, send to Application Insights), `QueryTagWith()` for annotating SQL with the calling code location (appears as SQL comments), SQL Server execution plan capture (`SET STATISTICS IO ON`, SSMS Actual Execution Plan), reading a query plan: index seek vs index scan vs table scan, identifying the missing index from a query plan, EF Core diagnostic source and `DiagnosticListener` for metrics.

---

## GENERATION ORDER (Recommended)

Copy this checklist and work through it in order:

```
[ ] 3.01 — DbContext: Lifecycle, Internals, and DI Scoping       (foundation for everything)
[ ] 3.02 — Change Tracker: Entity States and Unit of Work         (write path foundation)
[ ] 3.03 — LINQ to SQL: Query Translation Pipeline                (query path foundation)
[ ] 3.04 — Loading Strategies: Eager, Lazy, Explicit             (daily production code)
[ ] 3.05 — The N+1 Problem: Diagnosis and Solutions              (most asked in interviews)
[ ] 3.07 — Migrations: Strategy and Production Deployment         (DevOps critical)
[ ] 3.08 — Performance: AsNoTracking and Projections             (highest impact optimization)
[ ] 3.06 — Relationships: Configuration and Navigation            (model foundation)
[ ] 3.09 — Transactions and SaveChanges Internals                (correctness critical)
[ ] 3.11 — Bulk Operations: ExecuteUpdate and ExecuteDelete       (write performance)
[ ] 3.10 — Optimistic Concurrency: RowVersion and Conflicts      (concurrent systems)
[ ] 3.13 — Global Query Filters: Multi-Tenancy and Soft Delete   (SaaS applications)
[ ] 3.21 — Testing EF Core: SQLite and InMemory                  (engineering quality)
[ ] 3.27 — Fluent API Deep Dive                                  (configuration mastery)
[ ] 3.12 — Owned Entities and Value Converters                   (DDD patterns)
[ ] 3.14 — Compiled Queries and Query Plan Caching               (high-throughput APIs)
[ ] 3.15 — Raw SQL: FromSqlRaw and Stored Procedures             (escape hatch)
[ ] 3.22 — Specification Pattern with IQueryable<T>              (query architecture)
[ ] 3.23 — Repository and Unit of Work                           (architecture decisions)
[ ] 3.24 — Keyset Pagination                                     (API design)
[ ] 3.26 — Connection Resilience and Execution Strategies        (production reliability)
[ ] 3.18 — Inheritance Mapping: TPH, TPT, and TPC                (advanced modeling)
[ ] 3.16 — Interceptors                                          (cross-cutting concerns)
[ ] 3.17 — Shadow Properties and Backing Fields                  (advanced mapping)
[ ] 3.19 — JSON Columns (EF7+)                                   (modern patterns)
[ ] 3.30 — Diagnostics: Logging and Query Plans                  (production tooling)
[ ] 3.25 — Database Functions and Custom Translations            (advanced query)
[ ] 3.20 — Temporal Tables                                       (audit patterns)
[ ] 3.28 — Complex Mapping Scenarios                             (specialist)
[ ] 3.29 — Multi-Tenancy Patterns                                (SaaS specialist)
```

---

_Last updated: 2026-06 · Domain: EF Core Mastery · File: Topic Index_ _Tags: #index #efcore #dotnet #engineering #study-system_
