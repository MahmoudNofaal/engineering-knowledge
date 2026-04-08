# EF Core Transactions

> A transaction is a way to group multiple database operations so they either all succeed or all fail together.

---

## When To Use It

Use transactions when you need atomicity across multiple write operations — inserting an order and deducting inventory at the same time, for example. If either step fails, neither should persist. Don't wrap single-operation calls in explicit transactions; `SaveChanges()` already does that for you. Avoid long-running transactions — they hold locks and kill throughput under load. For operations spanning multiple systems (database + message broker), use the outbox pattern instead of distributed transactions.

---

## Core Concept

Every call to `SaveChanges()` is already wrapped in a transaction automatically. The moment you need *multiple* `SaveChanges()` calls to behave as one unit — or you're mixing EF with raw SQL — you need to take control manually with `BeginTransactionAsync()`. EF's `IDbContextTransaction` is a thin wrapper around the underlying ADO.NET transaction. The isolation level of that transaction determines what concurrent reads and writes are visible. For cross-system consistency (database + Kafka, database + email), there is no reliable distributed transaction — use the outbox pattern to write both the domain change and the message to the database in the same transaction, then deliver the message separately.

---

## The Code

**1. Basic explicit transaction**
```csharp
await using var transaction = await _context.Database.BeginTransactionAsync();
try
{
    _context.Orders.Add(newOrder);
    await _context.SaveChangesAsync();

    inventory.Stock -= newOrder.Quantity;
    await _context.SaveChangesAsync(); // second save, same transaction

    await transaction.CommitAsync();
}
catch
{
    await transaction.RollbackAsync(); // rolls back both saves
    throw;
}
```

**2. Sharing a transaction with raw ADO.NET or Dapper**
```csharp
await using var transaction = await _context.Database.BeginTransactionAsync();

var conn = _context.Database.GetDbConnection();
await conn.ExecuteAsync(
    "UPDATE audit_log SET reviewed = 1 WHERE order_id = @id",
    new { id = newOrder.Id },
    transaction: transaction.GetDbTransaction()); // shares the same ADO.NET transaction

_context.Orders.Add(newOrder);
await _context.SaveChangesAsync();

await transaction.CommitAsync();
```

**3. Savepoints — partial rollback inside one transaction**
```csharp
await using var transaction = await _context.Database.BeginTransactionAsync();

_context.Orders.Add(newOrder);
await _context.SaveChangesAsync();

await transaction.CreateSavepointAsync("after_order");

try
{
    _context.Notifications.Add(notification);
    await _context.SaveChangesAsync();
}
catch
{
    // Notification failed — roll back only the notification, keep the order
    await transaction.RollbackToSavepointAsync("after_order");
}

await transaction.CommitAsync();
```

**4. ExecutionStrategy and retries — the manual transaction pattern**
```csharp
// EnableRetryOnFailure conflicts with manual transactions
// The retry strategy can't replay a partial transaction — it doesn't know what committed
// Wrap the entire transaction in strategy.ExecuteAsync() to give it retry scope

var strategy = _context.Database.CreateExecutionStrategy();

await strategy.ExecuteAsync(async () =>
{
    await using var transaction = await _context.Database.BeginTransactionAsync();
    try
    {
        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        inventory.Stock -= order.Quantity;
        await _context.SaveChangesAsync();

        await transaction.CommitAsync();
    }
    catch
    {
        await transaction.RollbackAsync();
        throw; // strategy evaluates if the exception is transient and retries
    }
});
```

**5. Controlling isolation level**
```csharp
// Default isolation level is READ COMMITTED on SQL Server
// Change for specific scenarios — dirty reads, phantom reads, serializable guarantees

// READ UNCOMMITTED — allows dirty reads (fastest, least safe)
// Use only for reports where slightly stale data is acceptable
await using var transaction = await _context.Database.BeginTransactionAsync(
    IsolationLevel.ReadUncommitted);

var report = await _context.Orders
    .AsNoTracking()
    .SumAsync(o => o.Total);

await transaction.CommitAsync();

// SERIALIZABLE — full isolation, no phantom reads (slowest, most locks)
// Use for financial operations where exact consistency is required
await using var transaction = await _context.Database.BeginTransactionAsync(
    IsolationLevel.Serializable);

var balance = await _context.Accounts
    .Where(a => a.Id == accountId)
    .Select(a => a.Balance)
    .SingleAsync();

if (balance >= amount)
{
    account.Balance -= amount;
    await _context.SaveChangesAsync();
}

await transaction.CommitAsync();

// SNAPSHOT — readers don't block writers (requires snapshot isolation enabled on SQL Server)
// Best for read-heavy workloads with occasional writes
await using var transaction = await _context.Database.BeginTransactionAsync(
    IsolationLevel.Snapshot);
```

**6. Read-only transaction with NO LOCK hint**
```csharp
// For reporting queries where you want to avoid blocking on locked rows
// Without a full READ UNCOMMITTED transaction — just for this query
var total = await _context.Orders
    .FromSqlRaw("SELECT * FROM Orders WITH (NOLOCK)")
    .SumAsync(o => o.Total);
// Note: WITH (NOLOCK) is SQL Server-specific and may return dirty reads
// Prefer SNAPSHOT isolation as a cleaner alternative
```

**7. Ambient transactions — TransactionScope (avoid in async code)**
```csharp
// TransactionScope creates an ambient transaction — any ADO.NET connection
// opened inside the scope automatically enlists in it
// Works for synchronous code but is BROKEN in async code — do not use in modern .NET

// WRONG — TransactionScope doesn't flow correctly across async/await without TransactionScopeAsyncFlowOption
using var scope = new TransactionScope(); // missing async option — will deadlock

// CORRECT if you must use TransactionScope (legacy interop only)
using var scope = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);
_context.Orders.Add(order);
await _context.SaveChangesAsync();
scope.Complete(); // commit

// Prefer BeginTransactionAsync() for all new code — it's explicit and async-native
```

---

## Gotchas

- **`SaveChanges()` inside a transaction does NOT auto-commit.** It flushes changes to the connection but the transaction is only committed when you call `CommitAsync()`. If you forget, the transaction rolls back on dispose.
- **Calling `BeginTransaction()` twice on the same `DbContext` throws.** Only one active transaction per context. For nested behaviour, use savepoints.
- **`await using` matters.** If you use synchronous `using` on an async transaction, the connection can be returned to the pool before rollback completes. Always `await using`.
- **Long-held transactions cause lock contention.** Wrapping an HTTP request handler or external API call inside a transaction holds locks for the entire duration — a production bottleneck for any table with concurrent writers.
- **`EnableRetryOnFailure` + manual transaction = retry conflict.** The retry strategy can't automatically retry a partial transaction. You must use `strategy.ExecuteAsync()` to wrap the entire transactional block so the strategy can retry the whole unit, not just the failed operation.
- **`TransactionScope` deadlocks in async code without `TransactionScopeAsyncFlowOption.Enabled`.** The default scope doesn't flow across `await` continuations on thread pool threads. Avoid `TransactionScope` in new code — use `BeginTransactionAsync()`.

---

## Interview Angle

**What they're really testing:** Understanding of atomicity, EF's implicit vs explicit transaction model, isolation levels, and the retry strategy conflict.

**Common question form:** *"How do you handle transactions in EF Core? What if you need to span multiple `SaveChanges()` calls?"*

**The depth signal:** A junior answers "use `BeginTransaction()`" and stops. A senior knows that `SaveChanges()` is already transactional (so explicit transactions are only needed for multi-SaveChanges scenarios), explains the `EnableRetryOnFailure` + manual transaction conflict and the `strategy.ExecuteAsync()` fix, understands isolation levels and when to change them (READ UNCOMMITTED for reporting, SNAPSHOT for read-heavy workloads, SERIALIZABLE for financial operations), knows why `TransactionScope` is broken in async code, and brings up the outbox pattern as the answer to cross-system consistency rather than distributed transactions.

---

## Related Topics

- [[dotnet/ef/ef-dbcontext.md]] — Transaction scope is tied to `DbContext` lifetime; getting lifetime wrong causes subtle bugs.
- [[dotnet/ef/ef-raw-sql.md]] — Raw SQL via `ExecuteSqlRaw` must share the same transaction if used alongside EF operations; use `GetDbTransaction()` to pass the transaction through.
- [[dotnet/ef/ef-concurrency.md]] — Concurrency conflicts often surface as `DbUpdateConcurrencyException` inside a transaction; retry logic and isolation level interact with concurrency control.
- [[system-design/communication-patterns/event-driven-architecture.md]] — The outbox pattern is the correct replacement for distributed transactions across a database and a message broker.
- [[databases/sql/sql-isolation-levels.md]] — Isolation level behaviour (dirty reads, phantom reads, lock escalation) is a database concept; understanding it explains why different levels are appropriate for different scenarios.

---

## Source

https://learn.microsoft.com/en-us/ef/core/saving/transactions

---
*Last updated: 2026-04-08*