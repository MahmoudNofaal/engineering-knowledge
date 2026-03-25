# Database Connection Pooling

> A mechanism that maintains a cache of reusable database connections so applications don't pay the cost of establishing a new TCP connection and authentication handshake on every query.

---

## When To Use It

Use connection pooling any time more than one application process connects to a database — which is every production web application. Without pooling, each request that hits your app opens a connection, runs queries, and closes it. Under load, you exhaust the database's `max_connections` limit, and new connections start failing. Pooling is the fix. The second scenario is serverless or short-lived processes — Lambda functions, container tasks — where every invocation would otherwise create and destroy a connection, making the connection overhead dominate query time.

---

## Core Concept

A connection pool maintains N open connections to the database. When the application needs a connection, it borrows one from the pool, uses it, and returns it — the underlying TCP connection stays open. The pool has a minimum size (always-warm connections) and a maximum size (the ceiling, beyond which requests queue or fail). The hard constraint is the database server's `max_connections`: the sum of connections across all pool instances must stay below it. With multiple application servers each running a pool, this multiplies fast — three servers × pool size 20 = 60 connections, which is fine; thirty servers × pool size 20 = 600 connections, which overwhelms most databases. PgBouncer solves this by sitting between the application and the database, multiplexing many application connections onto few database connections.

---

## The Code

**SQLAlchemy connection pool (C# — application-side pooling)**
```csharp
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;

public class PoolingContext : DbContext
{
    public PoolingContext(DbContextOptions<PoolingContext> options) : base(options) { }
}

public class Program
{
    public static async Task Main()
    {
        var optionsBuilder = new DbContextOptionsBuilder<PoolingContext>()
            .UseNpgsql(
                "Server=localhost;Port=5432;Database=mydb;User Id=user;Password=pass;",
                options => options
                    .UseConnectionString("Server=localhost;Port=5432;Database=mydb;User Id=user;Password=pass;")
            );
        
        using (var context = new PoolingContext(optionsBuilder.Options))
        {
            // Connection is automatically pooled and reused
            var count = await context.Database.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM users"
            );
            System.Console.WriteLine($"User count: {count}");
        }
        
        // Connection returned to pool when DbContext disposed
    }
}
```

**Npgsql with connection pool (async C#)**
```csharp
using Npgsql;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public class AsyncPoolExample
{
    public static async Task Main()
    {
        // Npgsql has built-in connection pooling
        var connString = "Server=localhost;Port=5432;Database=mydb;User Id=user;Password=pass;" +
                        "Maximum Pool Size=20;Minimum Pool Size=5;Connection Idle Lifetime=300;";

        using (var conn = new NpgsqlConnection(connString))
        {
            await conn.OpenAsync();
            using (var cmd = conn.CreateCommand())
            {
                cmd.CommandText = "SELECT id, name FROM users LIMIT 10";
                using (var reader = await cmd.ExecuteReaderAsync())
                {
                    var rows = new List<(int id, string name)>();
                    while (await reader.ReadAsync())
                        rows.Add((reader.GetInt32(0), reader.GetString(1)));
                }
            }
        }
        // Connection automatically returned to pool when disposed
    }
}
```

**PgBouncer — server-side connection pooler for Postgres**
```ini
# /etc/pgbouncer/pgbouncer.ini

[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr     = 0.0.0.0
listen_port     = 5432          ; PgBouncer listens here, app connects here
auth_type       = md5
auth_file       = /etc/pgbouncer/userlist.txt

; Pool mode — the most important setting
pool_mode       = transaction   ; connection returned to pool after each transaction
                                ; session: held for entire session (least multiplexing)
                                ; statement: returned after each statement (most aggressive)

max_client_conn = 1000          ; max connections from applications
default_pool_size = 20          ; connections to actual Postgres per database/user pair
min_pool_size   = 5
reserve_pool_size = 5           ; emergency connections if pool is exhausted

; Timeouts
server_idle_timeout = 600       ; close idle server connections after 10 min
client_idle_timeout = 0         ; don't close idle client connections (0 = disabled)
query_timeout       = 0         ; per-query timeout (0 = disabled, set in app)

; Logging
log_connections = 1
log_disconnections = 1
```
```bash
# userlist.txt — hashed passwords
# Generate hash: echo -n "passwordusername" | md5sum
"myuser" "md5<hash>"

# Start PgBouncer
pgbouncer /etc/pgbouncer/pgbouncer.ini

# Monitor pool stats
psql -h localhost -p 5432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
psql -h localhost -p 5432 -U pgbouncer pgbouncer -c "SHOW STATS;"
psql -h localhost -p 5432 -U pgbouncer pgbouncer -c "SHOW CLIENTS;"
```

**HikariCP — Java connection pool (most common JVM pool)**
```java
HikariConfig config = new HikariConfig();
config.setJdbcUrl("jdbc:postgresql://localhost:5432/mydb");
config.setUsername("user");
config.setPassword("pass");

// Pool sizing
config.setMaximumPoolSize(10);       // max connections
config.setMinimumIdle(5);            // minimum idle connections
config.setIdleTimeout(300_000);      // ms before idle connection is removed (5 min)
config.setMaxLifetime(1_800_000);    // ms max connection lifetime (30 min)
config.setConnectionTimeout(30_000); // ms to wait for connection from pool

// Health check — runs before handing connection to app
config.setConnectionTestQuery("SELECT 1");
config.setKeepaliveTime(60_000);     // ms between keepalive pings

HikariDataSource ds = new HikariDataSource(config);

// Usage
try (Connection conn = ds.getConnection()) {
    PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
    ps.setInt(1, 42);
    ResultSet rs = ps.executeQuery();
}
```

**Right-sizing pool size — the formula**
```csharp
// Postgres recommendation: pool_size = num_cores * 2 + num_spindle_disks
// For a 4-core server with SSD: pool_size = 4 * 2 + 1 = 9 (~10)
// More connections does not mean more throughput — beyond saturation,
// connections compete for CPU and slow each other down

// Total connection budget across all instances:
// max_connections (Postgres) = sum(pool_size * num_app_instances) + admin headroom

// Example:
int maxConnections = 100;        // Postgres max_connections
int adminHeadroom = 5;           // for psql, monitoring, migrations
int available = maxConnections - adminHeadroom;  // 95
int appInstances = 5;
int poolSize = available / appInstances;  // 95 / 5 = 19
// Set to 15 with overflow to 19

// With PgBouncer as proxy:
// PgBouncer → Postgres: 20 connections (server pool)
// App → PgBouncer:      500 connections (client pool)
// Postgres sees only 20 connections regardless of app instance count
```

**Detecting pool exhaustion**
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;

public class PoolMonitoring
{
    public static void ConfigureLogging(DbContextOptionsBuilder options)
    {
        var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
        options.UseLoggerFactory(loggerFactory);
        options.EnableSensitiveDataLogging();
    }

    // Monitor these metrics in production:
    // - Connection pool exhaustion warnings in logs
    // - Database connection count via: SELECT count(*) FROM pg_stat_activity;
    // - Connection wait time: Application Insights or custom instrumentation
    // - Pool overflow events: Application Insights custom events
}

// Example instrumentation:
public class PoolExhaustionDetector
{
    private readonly NpgsqlDataSource _dataSource;
    private readonly ILogger _logger;

    public async Task CheckPoolHealthAsync()
    {
        using (var conn = _dataSource.OpenConnection())
        {
            var stats = await conn.ExecuteScalarAsync(
                "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction';"
            );
            _logger.LogWarning($"Idle connections: {stats}");
        }
    }
}
```

---

## Gotchas

- **Session-mode PgBouncer breaks prepared statements and advisory locks.** In transaction mode (which gives the best multiplexing), the connection is returned to the pool after each transaction — so session-level state like prepared statements, `SET` variables, and advisory locks don't survive. Applications that rely on these must use session mode, which gives worse multiplexing ratios.
- **`pool_pre_ping=True` adds a round-trip per checkout but prevents errors from stale connections.** Without it, a connection dropped by the database (firewall timeout, restart) stays in the pool and throws on first use. With it, a lightweight `SELECT 1` catches dead connections before handing them to the application.
- **Pool size × app instances must stay below `max_connections`.** Each horizontal scale event multiplies connection count. With ten app servers at pool_size=50, you need `max_connections=500` on Postgres — which means 500 MB of shared memory just for connection overhead. Use PgBouncer to decouple app connection count from database connection count.
- **Transactions held open starve the pool.** If a request borrows a connection, starts a transaction, and then does external work (HTTP calls, file I/O) before committing, the connection is held for the duration of that external work. With pool_size=10, ten slow requests block everyone else. Never hold a database transaction open across external I/O.
- **`max_lifetime` / `pool_recycle` is not optional.** Database-side firewalls silently drop TCP connections after idle periods (commonly 10–30 minutes on cloud providers). Without recycling, the pool holds dead connections that fail on first use. Set `pool_recycle` to less than the firewall idle timeout — 1800 seconds (30 min) is a safe default.

---

## Interview Angle

**What they're really testing:** Whether you understand the connection lifecycle and can reason about resource limits under horizontal scale.

**Common question form:** *"Your app works fine with 2 servers but falls over at 10 — what's wrong?"* or *"How do you size a connection pool?"* or *"What's PgBouncer and why would you use it?"*

**The depth signal:** A junior says "increase max_connections." A senior explains that increasing max_connections past the database's CPU core capacity hurts throughput (more context switching, more lock contention) — the right answer is PgBouncer in transaction mode to multiplex many app connections onto few database connections. They can derive the pool size formula (cores × 2), explain why session-mode PgBouncer breaks prepared statements, and know that holding a database transaction open across an HTTP call is how you exhaust a pool under moderate load with a perfectly reasonable pool_size.

---

## Related Topics

- [[databases/database-monitoring.md]] — Pool checkout wait time and connection count are the key metrics to watch.
- [[databases/postgres-vs-sqlserver.md]] — Postgres connection overhead is higher than SQL Server's; this makes PgBouncer more critical for Postgres at scale.
- [[databases/migrations-strategy.md]] — Long-running migrations hold connections and can starve the application pool during deployment.
- [[system-design/database-selection.md]] — Connection pooling constraints factor into database selection for serverless and high-concurrency architectures.

---

## Source

[PgBouncer documentation](https://www.pgbouncer.org/config.html)

---
*Last updated: 2026-03-24*