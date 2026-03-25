# Database Migrations Strategy

> A controlled, versioned approach to evolving a database schema over time without data loss, downtime, or inconsistency between application code and database structure.

---

## When To Use It

Every production database that has application code deployed against it needs a migration strategy. Use it when adding columns, dropping columns, renaming tables, changing types, or backfilling data. The question is never whether to use migrations — it's which pattern fits your change. The wrong pattern on a large table causes full table locks that take your application down for minutes or hours.

---

## Core Concept

A migration is a versioned, ordered, repeatable script that moves a database from schema version N to N+1. The hard part isn't writing the SQL — it's making the change while the application is running. Old code and new code run simultaneously during deployment. That window means the schema must be compatible with both versions at the same time. The strategy is expand-contract: first expand the schema to support both old and new code, deploy the new code, then contract the schema to remove what old code needed. Skipping the expand-contract pattern is the source of most migration-related outages.

---

## The Code

**Migration tooling setup — Entity Framework Core (C#/Npgsql)**
```csharp
// appsettings.json configuration
/*
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Port=5432;Database=mydb;User Id=user;Password=pass;"
  }
}
*/

// DbContext setup
public class AppDbContext : DbContext
{
    public DbSet<User> Users { get; set; }
    public DbSet<Order> Orders { get; set; }

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Model configuration
        base.OnModelCreating(modelBuilder);
    }
}

// Migration commands:
// dotnet ef migrations add AddUserPhoneColumn
// Generated migration file: Migrations/20240324000000_AddUserPhoneColumn.cs

public partial class AddUserPhoneColumn : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "phone",
            table: "users",
            type: "character varying(20)",
            nullable: true
        );
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "phone",
            table: "users"
        );
    }
}

// Application
// dotnet ef database update
// dotnet ef migrations list
```

**Expand-contract pattern — the safe way to rename a column**
```sql
-- WRONG: rename directly — breaks old code reading the old name
ALTER TABLE users RENAME COLUMN username TO handle;  -- instant outage

-- CORRECT: three-phase expand-contract

-- Phase 1: EXPAND — add new column, keep old one (deploy with old code still running)
ALTER TABLE users ADD COLUMN handle VARCHAR(50);

-- Backfill in batches — never update millions of rows in one statement
UPDATE users SET handle = username
WHERE handle IS NULL AND id BETWEEN 1 AND 10000;
-- repeat for next batch...

-- Phase 2: deploy new code that writes to BOTH columns and reads from new one
-- old code still reads username, new code reads handle, both write to both

-- Phase 3: CONTRACT — drop old column after all instances run new code
ALTER TABLE users DROP COLUMN username;
```

**Large table migrations — batched backfill**
```csharp
// Never: UPDATE large_table SET new_col = compute(old_col)
// This locks the table for the duration of the update

using Npgsql;
using System;
using System.Threading.Tasks;

public class BatchedBackfillService
{
    private readonly string _connectionString;
    private const int BatchSize = 1000;

    public async Task BackfillInBatchesAsync()
    {
        using (var conn = new NpgsqlConnection(_connectionString))
        {
            await conn.OpenAsync();
            long lastId = 0;
            int batchCount = 0;

            while (true)
            {
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        UPDATE orders
                        SET    total_cents = (total * 100)::int
                        WHERE  id > @last_id
                          AND  total_cents IS NULL
                        ORDER BY id
                        LIMIT  @batch_size
                        RETURNING id";
                    cmd.Parameters.AddWithValue("@last_id", lastId);
                    cmd.Parameters.AddWithValue("@batch_size", BatchSize);

                    using (var reader = await cmd.ExecuteReaderAsync())
                    {
                        bool hasRows = false;
                        while (await reader.ReadAsync())
                        {
                            lastId = reader.GetInt64(0);
                            hasRows = true;
                        }
                        if (!hasRows)
                            break;  // No more rows to process
                    }
                }

                // Commit each batch — releases lock between batches
                conn.Close();
                await Task.Delay(50);  // Brief pause — reduces replication lag pressure
                await conn.OpenAsync();

                batchCount++;
                Console.WriteLine($"Backfilled batch {batchCount} (up to ID {lastId})");
            }
        }
    }
}
```

**Zero-downtime index creation — Postgres**
```sql
-- WRONG: blocks all reads and writes on large tables
CREATE INDEX idx_orders_customer ON orders (customer_id);

-- CORRECT: CONCURRENTLY — builds without locking (takes longer, uses more CPU)
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);

-- Drop also has a concurrent option
DROP INDEX CONCURRENTLY idx_orders_customer;

-- CONCURRENTLY cannot run inside a transaction block
-- Alembic: set execution_options({"postgresql_concurrently": True}) on the op
```

**Adding a NOT NULL column safely**
```sql
-- WRONG: immediate NOT NULL fails if any existing row is NULL during backfill window
ALTER TABLE users ADD COLUMN verified BOOLEAN NOT NULL DEFAULT FALSE;
-- On large tables, this rewrites the entire table in Postgres < 11

-- CORRECT for Postgres 11+: DEFAULT is stored as metadata, no rewrite
ALTER TABLE users ADD COLUMN verified BOOLEAN NOT NULL DEFAULT FALSE;
-- Fast in PG11+ — but still validates all rows on older versions

-- CORRECT for older Postgres or any DB:
-- Step 1: add nullable, no default
ALTER TABLE users ADD COLUMN verified BOOLEAN;
-- Step 2: backfill
UPDATE users SET verified = FALSE WHERE verified IS NULL;
-- Step 3: add constraint after backfill
ALTER TABLE users ALTER COLUMN verified SET NOT NULL;
ALTER TABLE users ALTER COLUMN verified SET DEFAULT FALSE;
```

**Foreign key — add without locking**
```sql
-- WRONG: validates entire table synchronously, holds lock
ALTER TABLE orders ADD CONSTRAINT fk_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);

-- CORRECT: add as NOT VALID first, validate separately
ALTER TABLE orders ADD CONSTRAINT fk_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    NOT VALID;   -- skips historical row validation, only validates new inserts

-- Validate separately — uses ShareUpdateExclusiveLock (doesn't block reads/writes)
ALTER TABLE orders VALIDATE CONSTRAINT fk_customer;
```

**Migration table — tracking applied versions**
```sql
-- Most tools create this automatically
-- Manual reference for what it looks like
CREATE TABLE schema_migrations (
    version     BIGINT PRIMARY KEY,      -- timestamp or sequence number
    applied_at  TIMESTAMPTZ DEFAULT NOW(),
    description TEXT
);

-- Check which migrations have run
SELECT version, description, applied_at
FROM schema_migrations
ORDER BY version DESC
LIMIT 20;
```

**Flyway (Java/.NET/SQL-first) — naming convention**
```sql
-- V{version}__{description}.sql
-- V1__create_users_table.sql
-- V2__add_user_phone.sql
-- R__repeatable_migration.sql  (runs whenever content changes — views, functions)

-- V2__add_user_phone.sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
CREATE INDEX CONCURRENTLY idx_users_phone ON users (phone);
```

---

## Gotchas

- **Never drop a column in the same deployment that stops using it.** Old instances still running the previous code will crash when they try to read the dropped column. Deploy the code change first, confirm all instances are updated, then drop in a follow-up migration.
- **`ALTER TABLE ... ADD COLUMN ... NOT NULL` without a default rewrites the entire table on Postgres < 11.** On a 500GB table this takes hours and holds an AccessExclusiveLock. Always add nullable first, backfill, then add the constraint.
- **`CREATE INDEX` without `CONCURRENTLY` takes an exclusive lock for the entire build duration.** On a table with millions of rows, that's minutes of blocked reads and writes. Always use `CONCURRENTLY` in production — even if it takes longer.
- **Batched backfills must be idempotent.** If the backfill crashes halfway, you need to re-run it safely. Always filter on `WHERE new_col IS NULL` or use a cursor on `id`. Never use `OFFSET` — it recalculates from the start on each batch.
- **Migration tools serialize by version number, not by merge order.** Two developers creating migrations simultaneously with sequential version numbers causes conflicts on merge. Use timestamps (YYYYMMDDHHmmss) instead of integers to reduce collisions, and treat conflicts as a build failure that requires manual resolution before deployment.

---

## Interview Angle

**What they're really testing:** Whether you understand the deploy/schema compatibility window and can design schema changes that don't cause downtime.

**Common question form:** *"How would you rename a column in production without downtime?"* or *"How do you add a NOT NULL column to a table with 100M rows?"*

**The depth signal:** A junior writes `ALTER TABLE users RENAME COLUMN username TO handle` and calls it done. A senior explains the expand-contract pattern: add the new column, dual-write from the application, backfill old rows in batches, deploy the code cutover, then drop the old column — across three separate deployments. They also know that `CREATE INDEX CONCURRENTLY` is the difference between a 2-minute planned maintenance and a surprise outage, that `ADD CONSTRAINT ... NOT VALID` followed by `VALIDATE CONSTRAINT` is how you add foreign keys without a table lock, and that idempotent batched backfills are non-negotiable on large tables.

---

## Related Topics

- [[databases/postgres-vs-sqlserver.md]] — Lock behavior during DDL differs significantly; Postgres MVCC makes some migrations safer than SQL Server.
- [[databases/indexing-strategies.md]] — Adding indexes in migrations is where `CONCURRENTLY` matters most.
- [[devops/deployment-strategies.md]] — Blue-green and rolling deployments define the compatibility window migrations must span.
- [[databases/database-monitoring.md]] — Monitoring lock wait time and replication lag during migrations is how you catch problems before they become outages.

---

## Source

[PostgreSQL documentation — ALTER TABLE and lock levels](https://www.postgresql.org/docs/current/sql-altertable.html)

---
*Last updated: 2026-03-24*