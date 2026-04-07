# C# IDisposable

> The pattern for deterministic cleanup of resources the GC doesn't know about — file handles, database connections, network sockets, unmanaged memory — released the moment you call `Dispose()` rather than waiting for finalisation.

---

## Quick Reference

| | |
|---|---|
| **Interface** | `IDisposable` — one method: `void Dispose()` |
| **Syntax sugar** | `using` statement / `using` declaration |
| **Async version** | `IAsyncDisposable` + `await using` (C# 8) |
| **C# version** | C# 1.0 (`IDisposable`), C# 2.0 (`using`), C# 8.0 (`IAsyncDisposable`) |

---

## When To Use It

Implement `IDisposable` on any class that:
- Owns an unmanaged resource directly (file handle, socket, unmanaged memory via `SafeHandle`)
- Owns another `IDisposable` (e.g., a class that holds a `DbContext` or `HttpClient`)

Callers **must** call `Dispose()` when done. The correct way is with a `using` block — it guarantees disposal even when exceptions are thrown.

---

## Core Concept

The GC cleans up managed memory automatically but knows nothing about file handles, database connections, or native memory. Without `IDisposable`, these resources would only be released when the finaliser runs — which can be arbitrary time later, or never.

`IDisposable` + `using` provides deterministic release: the resource is freed exactly when the `using` block exits, even on exception. This is analogous to RAII in C++.

The standard implementation pattern separates managed resource cleanup (called from `Dispose()`) from finaliser fallback (called from `~MyClass()` if `Dispose()` is never called). Calling `GC.SuppressFinalize(this)` inside `Dispose()` tells the GC not to run the finaliser — avoiding the two-GC-cycle penalty when `Dispose()` was already called.

---

## The Code

**`using` — the only correct way to consume `IDisposable`**
```csharp
// using statement: Dispose() called at end of block, even on exception
using (var conn = new SqlConnection(connectionString))
{
    conn.Open();
    // ...
} // conn.Dispose() always called here

// using declaration (C# 8): Dispose() called at end of enclosing scope
using var reader = new StreamReader("file.txt");
string content = reader.ReadToEnd();
// reader.Dispose() called when method returns
```

**Implementing `IDisposable` — the standard pattern**
```csharp
public class ResourceHolder : IDisposable
{
    private Stream? _stream;
    private bool _disposed;

    public ResourceHolder(string path)
        => _stream = File.OpenRead(path);

    public void DoWork()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        // ... use _stream ...
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this); // don't run finaliser — we already cleaned up
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;
        if (disposing)
            _stream?.Dispose(); // managed resource — only dispose from Dispose(), not finaliser
        _stream = null;
        _disposed = true;
    }

    ~ResourceHolder() => Dispose(disposing: false); // fallback — runs if Dispose() not called
}
```

**`IAsyncDisposable` — for async cleanup (C# 8)**
```csharp
public class AsyncResource : IAsyncDisposable
{
    private readonly NetworkStream _stream;

    public AsyncResource(string host, int port)
        => _stream = new TcpClient(host, port).GetStream();

    public async ValueTask DisposeAsync()
    {
        await _stream.FlushAsync();
        await _stream.DisposeAsync();
        GC.SuppressFinalize(this);
    }
}

await using var resource = new AsyncResource("localhost", 8080);
// DisposeAsync() called on scope exit
```

**Dispose in `IDisposable` owners — cascade disposal**
```csharp
public class OrderRepository : IDisposable
{
    private readonly DbContext _context; // owned resource
    private bool _disposed;

    public OrderRepository(DbContext context) => _context = context;

    public Task<Order?> FindAsync(int id, CancellationToken ct)
        => _context.Set<Order>().FindAsync(new object[] { id }, ct).AsTask();

    public void Dispose()
    {
        if (_disposed) return;
        _context.Dispose(); // cascade — dispose what we own
        _disposed = true;
        GC.SuppressFinalize(this);
    }
}
```

---

## Real World Example

A multi-resource unit of work disposes everything in a single `using` block via `IAsyncDisposable`.

```csharp
public class DataExportService : IAsyncDisposable
{
    private readonly IDbConnection _connection;
    private readonly FileStream _output;
    private readonly StreamWriter _writer;
    private bool _disposed;

    public static async Task<DataExportService> CreateAsync(string dbConn, string outputPath)
    {
        var conn   = new SqlConnection(dbConn);
        await conn.OpenAsync();
        var output = new FileStream(outputPath, FileMode.Create);
        return new DataExportService(conn, output);
    }

    private DataExportService(IDbConnection connection, FileStream output)
    {
        _connection = connection;
        _output     = output;
        _writer     = new StreamWriter(_output);
    }

    public async Task ExportAsync(CancellationToken ct)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT Id, Name FROM Products";
        using var reader = await ((DbCommand)cmd).ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            await _writer.WriteLineAsync($"{reader[0]},{reader[1]}");
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        await _writer.DisposeAsync();
        await _output.DisposeAsync();
        _connection.Dispose();
        _disposed = true;
        GC.SuppressFinalize(this);
    }
}

await using var exporter = await DataExportService.CreateAsync(connStr, "export.csv");
await exporter.ExportAsync(ct);
// DisposeAsync: writer flushed, file closed, DB connection returned to pool
```

---

## Gotchas

- **Not calling `Dispose()` is a resource leak — not just a performance issue.** File handles, database connections, and sockets are finite OS resources. Leaking them causes `IOException`, `SqlException`, or connection pool exhaustion.
- **Double-dispose must be safe.** `Dispose()` is expected to be idempotent — the second call does nothing. Always guard with `if (_disposed) return`.
- **Finaliser is a fallback, not an alternative.** Don't rely on the finaliser for timely cleanup. It runs on an unpredictable GC cycle and on a separate thread. Use `using` for deterministic cleanup.
- **`using` on `IAsyncDisposable` without `await` calls synchronous `Dispose()` if available, not `DisposeAsync()`.** Always use `await using` for `IAsyncDisposable`.
- **Event subscribers keep the subscriber alive.** Unsubscribe in `Dispose()` — see events topic.

---

## Interview Angle

**What they're really testing:** Whether you understand deterministic resource cleanup vs GC finalisation, and the `using` pattern as the enforcement mechanism.

**Common question forms:**
- "What is `IDisposable` and when do you implement it?"
- "Why use `using` instead of just calling `Dispose()`?"
- "What's the difference between `Dispose` and a finaliser?"

**The depth signal:** A senior explains that `Dispose()` is deterministic (called at a known point), while finalisation is non-deterministic (GC decides). They know `GC.SuppressFinalize` avoids the two-cycle penalty, that double-dispose must be safe, and that not disposing a connection exhausts the connection pool — not just "wastes memory."

---

## Related Topics

- [[dotnet/csharp/csharp-garbage-collector.md]] — The GC handles memory; `IDisposable` handles everything else
- [[dotnet/csharp/csharp-events.md]] — Unsubscribing from events in `Dispose()` prevents subscriber-as-GC-root memory leaks
- [[dotnet/csharp/csharp-async-await.md]] — `IAsyncDisposable` and `await using` for async cleanup

---

## Source

[IDisposable — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/implementing-dispose)

---
*Last updated: 2026-04-06*