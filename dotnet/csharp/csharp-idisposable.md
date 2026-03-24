# C# IDisposable

> `IDisposable` is a contract that says "this object holds resources the GC can't clean up automatically — call `Dispose()` when you're done with it."

---

## When To Use It

Implement `IDisposable` whenever your class directly holds something outside managed memory: file handles, database connections, network sockets, unmanaged memory, or wrappers around other `IDisposable` objects. If your class only holds plain managed objects (strings, lists, POCOs), you don't need it. The problem it solves is deterministic cleanup — you're telling callers exactly when resources are released, rather than waiting for the GC to eventually run a finalizer.

---

## Core Concept

The GC knows how to reclaim managed heap memory, but it has no idea how to close a file or release a database connection — those are OS-level resources. `IDisposable` gives you a hook to do that cleanup yourself at a predictable moment. The `using` statement is just syntactic sugar that guarantees `Dispose()` is called even if an exception is thrown. The full pattern has two layers: a public `Dispose()` for callers, and a protected `Dispose(bool disposing)` that separates "called by user code" from "called by the GC finalizer" — because when the finalizer calls you, managed objects may already be gone and you should only touch unmanaged handles.

---

## The Code
```csharp
// --- Minimal IDisposable: wrapping a single managed disposable ---
// Use this when your class owns one or more IDisposable fields
// and doesn't hold unmanaged resources directly.
public class ReportWriter : IDisposable
{
    private StreamWriter? _writer;
    private bool _disposed;

    public ReportWriter(string path)
    {
        _writer = new StreamWriter(path);
    }

    public void WriteLine(string line)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        _writer!.WriteLine(line);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _writer?.Dispose();
        _disposed = true;
        GC.SuppressFinalize(this);   // no finalizer here, but good habit
    }
}
```
```csharp
// --- Full pattern: class that holds an unmanaged resource directly ---
// Add a finalizer as a safety net for callers who forget to call Dispose().
public class NativeFileHandle : IDisposable
{
    private IntPtr _handle;
    private bool _disposed;

    public NativeFileHandle(string path)
    {
        _handle = NativeApi.OpenFile(path);
    }

    ~NativeFileHandle()                         // safety net — runs if Dispose was never called
    {
        Dispose(disposing: false);
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);              // finalizer no longer needed
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;

        if (disposing)
        {
            // safe to touch managed objects here
        }

        if (_handle != IntPtr.Zero)
        {
            NativeApi.CloseFile(_handle);       // always release unmanaged handle
            _handle = IntPtr.Zero;
        }

        _disposed = true;
    }
}
```
```csharp
// --- Calling disposable objects: always use `using` ---
using var writer = new ReportWriter("output.txt");
writer.WriteLine("Hello");
// Dispose() is called here automatically, even if an exception was thrown above

// Equivalent without using (pre-C# 8 style or when you need explicit scope):
ReportWriter? writer2 = null;
try
{
    writer2 = new ReportWriter("output2.txt");
    writer2.WriteLine("Hello");
}
finally
{
    writer2?.Dispose();
}
```
```csharp
// --- Async version: IAsyncDisposable (EF Core, HttpClient, etc.) ---
public class AsyncDbSession : IAsyncDisposable
{
    private readonly SqlConnection _conn;

    public AsyncDbSession(string connString)
    {
        _conn = new SqlConnection(connString);
    }

    public async ValueTask DisposeAsync()
    {
        await _conn.DisposeAsync();
        GC.SuppressFinalize(this);
    }
}

// Caller:
await using var session = new AsyncDbSession(connectionString);
```

---

## Gotchas

- **`Dispose()` must be idempotent — calling it twice should be safe.** The `if (_disposed) return;` guard is not optional. Many callers and frameworks (EF Core, ASP.NET middleware) may call `Dispose()` more than once. If you skip the guard and call `_writer.Dispose()` twice, `StreamWriter` handles it, but your custom unmanaged cleanup likely won't.
- **`using var` scope ends at the enclosing block, not the line.** `using var conn = new SqlConnection(...)` inside a method keeps the connection open until the method returns — not just until the next statement. If you open a connection early and do unrelated work after, you're holding the connection longer than you think. Use an explicit `{ }` block to tighten the scope.
- **Implement `IAsyncDisposable` when your cleanup is async.** If `Dispose()` calls `.GetAwaiter().GetResult()` on an async method to flush or close something, you risk deadlocks in ASP.NET Core contexts. If cleanup needs `await`, implement `IAsyncDisposable` and use `await using`.
- **Don't throw exceptions from `Dispose()`.** If `Dispose()` throws inside a `using` block that is already unwinding from another exception, the original exception is silently swallowed. Wrap cleanup code in try/catch inside `Dispose` and log errors rather than rethrowing.
- **`protected virtual Dispose(bool)` exists for inheritance, not just for finalizers.** If a subclass adds its own resources, it should override `Dispose(bool disposing)`, call `base.Dispose(disposing)`, and clean up its own fields. If you seal your class, skip `virtual` — but the bool overload still keeps managed vs. unmanaged cleanup logically separated and is worth keeping.

---

## Interview Angle

**What they're really testing:** Whether you understand the boundary between managed and unmanaged resources, and why deterministic cleanup exists at all.

**Common question form:** "When do you implement `IDisposable`?" or "What's the difference between `Dispose` and a finalizer?" or "What does `GC.SuppressFinalize` do?"

**The depth signal:** A junior knows to use `using` and that `IDisposable` is for "cleanup." A senior explains that finalizers exist as a *safety net* for unmanaged handles — not as the primary cleanup path — and that `GC.SuppressFinalize` is critical because objects with finalizers survive one extra GC cycle before collection (they go on the finalization queue), which increases memory pressure. They also know when to reach for `IAsyncDisposable` vs `IDisposable`, and that the `Dispose(bool disposing)` split exists specifically because when the finalizer calls `Dispose(false)`, managed objects in the graph may already have been collected and accessing them is undefined behavior.

---

## Related Topics

- [[dotnet/csharp-garbage-collector.md]] — `IDisposable` is the user-facing interface to GC lifecycle; understanding generations and finalization explains *why* the pattern is shaped the way it is
- [[dotnet/async-and-valuetask.md]] — `IAsyncDisposable` and `await using` are the async counterparts; `ValueTask` appears in `DisposeAsync()` return types
- [[dotnet/csharp-reflection.md]] — DI containers use reflection to discover and call `Dispose()` on registered services at scope end; knowing both explains how scoped lifetimes work
- [[dotnet/dependency-injection.md]] — ASP.NET Core's DI container calls `Dispose()` automatically on scoped and transient services it created; understanding this prevents double-dispose bugs

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/implementing-dispose](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/implementing-dispose)

---
*Last updated: 2026-03-23*