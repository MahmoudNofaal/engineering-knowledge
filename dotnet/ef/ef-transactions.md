# EF Core Transactions

> A transaction is a way to group multiple database operations so they either all succeed or all fail together.

---

## When To Use It
Use transactions when you need atomicity across multiple write operations — e.g., inserting an order and deducting inventory at the same time. If either step fails, neither should persist. Don't wrap single-operation calls in explicit transactions; EF Core already does that for you via `SaveChanges()`. Avoid long-running transactions — they hold locks and kill throughput under load.

---

## Core Concept
Every call to `SaveChanges()` is already wrapped in a transaction automatically. The moment you need *multiple* `SaveChanges()` calls to behave as one unit — or you're mixing EF with raw SQL — you need to take control manually. You do that by calling `BeginTransactionAsync()` on the `DbContext`, then explicitly committing or rolling back. EF's `IDbContextTransaction` is just a thin wrapper around ADO.NET's transaction. If you're coordinating across two completely separate systems (e.g., database + message broker), you're looking at a different beast: distributed transactions or the outbox pattern.

---

## The Code
```csharp
// 1. Basic explicit transaction
await using var transaction = await _context.Database.BeginTransactionAsync();
try
{
    _context.Orders.Add(newOrder);
    await _context.SaveChangesAsync();

    inventory.Stock -= newOrder.Quantity;
    await _context.SaveChangesAsync();   // second save, same transaction

    await transaction.CommitAsync();
}
catch
{
    await transaction.RollbackAsync();   // rolls back both saves
    throw;
}
```
```csharp
// 2. Sharing a transaction with raw ADO.NET (e.g., dapper or stored proc)
await using var transaction = await _context.Database.BeginTransactionAsync();

// Give the same underlying connection/transaction to Dapper
var conn = _context.Database.GetDbConnection();
await conn.ExecuteAsync("UPDATE audit_log SET ...", transaction: transaction.GetDbTransaction());

_context.Orders.Add(newOrder);
await _context.SaveChangesAsync();

await transaction.CommitAsync();
```
```csharp
// 3. SavepointAsync — partial rollback inside one transaction (.NET 6+)
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
    await transaction.RollbackToSavepointAsync("after_order"); // only notification rolled back
}

await transaction.CommitAsync();
```

---

## Gotchas
- **`SaveChanges()` inside a transaction does NOT auto-commit.** It just flushes changes to the connection. The commit only happens when you call `CommitAsync()`. If you forget, the transaction rolls back on dispose.
- **Calling `BeginTransaction()` twice on the same `DbContext` throws.** Only one active transaction per context at a time. If you need nested behavior, use savepoints.
- **`await using` matters.** If you use `using` (sync dispose) on an async transaction, the connection can be returned to the pool before the rollback completes. Always `await using`.
- **Long-held transactions cause lock contention.** Wrapping HTTP request logic or external API calls inside a transaction is a common production mistake — you hold DB locks for the entire duration.
- **`ExecutionStrategy` conflicts with manual transactions.** If you're using EF's built-in retry strategy (e.g., for SQL Azure), you can't wrap it in a manual transaction directly. You must use `strategy.ExecuteAsync(async () => { ... })` with the transaction inside the lambda.

---

## Interview Angle
**What they're really testing:** Understanding of atomicity, EF's implicit vs explicit transaction model, and real failure modes in production.

**Common question form:** *"How do you handle transactions in EF Core? What if you need to span multiple `SaveChanges()` calls?"*

**The depth signal:** A junior answers "use `BeginTransaction()`" and stops there. A senior knows that `SaveChanges()` is already transactional, explains *when* you actually need explicit control, mentions the retry strategy conflict with manual transactions, and brings up the tradeoff between explicit transactions and the outbox pattern for cross-system consistency.

---

## Related Topics
- [[dotnet/dbcontext-lifetime.md]] — Transaction scope is tied to `DbContext` lifetime; getting that wrong causes subtle bugs.
- [[dotnet/ef-raw-sql.md]] — Raw SQL via `ExecuteSqlRaw` must share the same transaction if used alongside EF operations.
- [[system-design/outbox-pattern.md]] — When a transaction needs to span a database write and a message broker publish, this is the alternative to distributed transactions.
- [[databases/isolation-levels.md]] — Transaction behavior changes significantly depending on the isolation level set on the connection.

---

## Source
https://learn.microsoft.com/en-us/ef/core/saving/transactions

---
*Last updated: 2026-03-24*