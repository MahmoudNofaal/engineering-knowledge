# C# Garbage Collector

> The GC is the .NET runtime's automatic memory manager — it tracks which objects are still reachable and periodically frees the ones that aren't.

---

## When To Use It

You're always using it — there's no opt-out. What matters is understanding it well enough to avoid fighting it. It matters most when you're diagnosing high memory usage, GC-induced latency spikes, or `OutOfMemoryException` in long-running services. Don't try to outsmart it with manual `GC.Collect()` calls in production; that almost always makes things worse.

---

## Core Concept

The GC divides the heap into three generations: 0, 1, and 2. New objects land in Gen 0. If they survive a collection, they get promoted to Gen 1, then Gen 2. The insight behind this is that most objects die young — short-lived allocations like loop variables and method return values get collected cheaply in Gen 0 without touching long-lived objects in Gen 2. Gen 2 collections are expensive because they scan the whole heap and block threads (a "full GC" or "stop-the-world" pause). There's also a separate Large Object Heap (LOH) for objects ≥ 85,000 bytes — these skip Gen 0/1 entirely and are collected alongside Gen 2. The GC determines reachability by tracing from "roots" (static fields, local variables, CPU registers) — anything not reachable from a root is dead and its memory is reclaimed.

---

## The Code
```csharp
// --- Implementing IDisposable correctly (the standard pattern) ---
public class FileProcessor : IDisposable
{
    private FileStream? _stream;
    private bool _disposed;

    public FileProcessor(string path)
    {
        _stream = File.OpenRead(path);
    }

    public void Process() { /* read from _stream */ }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);   // tell GC: no need to call finalizer
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;
        if (disposing)
            _stream?.Dispose();      // free managed resources
        _disposed = true;
    }
}

// Caller always uses using — guarantees Dispose even on exception
using var processor = new FileProcessor("data.csv");
processor.Process();
```
```csharp
// --- Adding a finalizer (only when holding unmanaged resources directly) ---
public class NativeBuffer : IDisposable
{
    private IntPtr _handle;
    private bool _disposed;

    public NativeBuffer()
    {
        _handle = NativeLib.Alloc(1024);
    }

    ~NativeBuffer()                             // finalizer — GC calls this if Dispose was skipped
    {
        Dispose(disposing: false);
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;
        NativeLib.Free(_handle);                // always free unmanaged handle
        _handle = IntPtr.Zero;
        _disposed = true;
    }
}
```
```csharp
// --- WeakReference: hold a reference without preventing collection ---
var cache = new Dictionary<int, WeakReference<byte[]>>();

void Store(int id, byte[] data) =>
    cache[id] = new WeakReference<byte[]>(data);

byte[] Get(int id)
{
    if (cache.TryGetValue(id, out var weak) &&
        weak.TryGetTarget(out var data))        // returns false if GC already collected it
        return data;

    // cache miss — reload from source
    var fresh = LoadFromDisk(id);
    Store(id, fresh);
    return fresh;
}
```
```csharp
// --- Checking GC pressure in diagnostics / benchmarks ---
long before = GC.GetTotalMemory(forceFullCollection: false);
long gen0Before = GC.CollectionCount(0);

RunWorkload();

long gen0After = GC.CollectionCount(0);
Console.WriteLine($"Gen 0 collections during workload: {gen0After - gen0Before}");
Console.WriteLine($"Memory delta: {GC.GetTotalMemory(false) - before:N0} bytes");
```

---

## Gotchas

- **Finalizers delay collection by one GC cycle.** When an object with a finalizer becomes unreachable, the GC puts it on the finalizer queue instead of freeing it immediately. It gets collected in the *next* cycle. If you allocate many finalizable objects quickly, you grow the finalizer queue and increase memory pressure. Always call `GC.SuppressFinalize(this)` inside `Dispose` to short-circuit this.
- **LOH is not compacted by default.** Objects on the Large Object Heap (≥ 85 KB) are collected but the freed space isn't moved together. This causes LOH fragmentation — you can end up with plenty of total free memory but no contiguous block large enough for a new allocation, causing an `OutOfMemoryException`. You can opt in to LOH compaction with `GCSettings.LargeObjectHeapCompactionMode = GCLargeObjectHeapCompactionMode.CompactOnce` before a `GC.Collect()`, but it's expensive.
- **Captured variables in lambdas/closures create hidden long-lived references.** If a lambda stored in a static field or a long-lived event captures a local object, that object is rooted for the lifetime of the lambda — it never gets collected. This is one of the most common sources of unintentional memory leaks in C# services.
- **`GC.Collect()` in production almost always backfires.** It forces a full Gen 2 collection, which is the most expensive kind and triggers a stop-the-world pause. The GC is better than you at deciding when to collect. Only use it in controlled scenarios like benchmarks or after releasing a known large object where you want to measure memory accurately.
- **Server GC vs Workstation GC behave differently.** ASP.NET Core uses Server GC by default — it runs a GC thread per logical core and prioritizes throughput over latency. Workstation GC (the default for console apps) prioritizes lower pause times. A service that behaves fine in local development (Workstation GC) can have very different memory and pause characteristics in production (Server GC). You can control this in `runtimeconfig.json` with `"System.GC.Server": true/false`.

---

## Interview Angle

**What they're really testing:** Whether you understand generational collection, why `IDisposable` exists, and the difference between managed memory and unmanaged resources.

**Common question form:** "Explain how the GC works in .NET" or "What's the difference between `Dispose` and a finalizer?" or "How would you find a memory leak in a .NET service?"

**The depth signal:** A junior knows `IDisposable`, `using`, and that the GC frees memory automatically. A senior explains *why* finalizers exist separately from `Dispose` (unmanaged resources can't be freed by the GC itself — it has no knowledge of what `IntPtr` points to), why `GC.SuppressFinalize` matters for performance (skips the two-cycle finalizer queue), and how to diagnose a real leak: attaching dotMemory or using `dotnet-dump` + `dotnet-gcdump` to take a heap snapshot, then looking for unexpected object retention — specifically, following the reference chain from a bloated type back to its GC root to find the accidental capture or forgotten event subscription.

---

## Related Topics

- [[dotnet/idisposable-pattern.md]] — the full `IDisposable` / finalizer pattern is the main interface between your code and GC lifecycle
- [[dotnet/value-types-vs-reference-types.md]] — stack-allocated value types don't go through the GC at all; understanding the difference explains why structs reduce GC pressure
- [[dotnet/memory-and-span.md]] — `Span<T>`, `Memory<T>`, and `ArrayPool<T>` are the primary tools for reducing GC allocations in hot paths
- [[dotnet/async-and-valuetask.md]] — `ValueTask` exists specifically to avoid the `Task` allocation that would otherwise pressure Gen 0 in high-throughput async code

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals)

---
*Last updated: 2026-03-23*