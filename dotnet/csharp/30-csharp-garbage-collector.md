# C# Garbage Collector

> The .NET GC is a generational, mark-and-compact heap manager that automatically reclaims memory for objects with no live references — freeing you from manual `malloc`/`free` while introducing pauses and allocation cost as tradeoffs.

---

## Quick Reference

| Generation | Collected | Contents | Cost |
|---|---|---|---|
| Gen 0 | Most frequently | Short-lived temporaries | Fast — small heap |
| Gen 1 | Occasionally | Survived one Gen 0 | Medium |
| Gen 2 | Rarely | Long-lived objects | Slow — full heap scan |
| LOH | With Gen 2 | Objects ≥ 85 KB | Never compacted (by default) |

---

## When To Worry About It

The GC runs transparently for most code. Worry about it when:
- Profiler shows high allocation rate or frequent Gen 0 collections in tight loops
- Latency spikes in a low-latency service correlate with GC pauses
- `OutOfMemoryException` despite having plenty of RAM (fragmented LOH)

The right response to GC pressure is **reduce allocations** — not fight the GC with manual tricks.

---

## Core Concept

The GC divides the heap into three generations. Every new object starts in Gen 0 — the smallest, cheapest-to-collect generation. If an object survives a Gen 0 collection, it's promoted to Gen 1. Survive Gen 1, promoted to Gen 2. Gen 2 collections scan the whole heap and are expensive.

The insight: **most objects die young** (short-lived temporaries). By keeping Gen 0 small and collecting it often, the GC handles high allocation rates with low latency — most pauses are microseconds for Gen 0.

GC pauses ("stop-the-world") freeze all managed threads while the GC traces live references. Server GC and background GC in .NET reduce pause length but can't eliminate them entirely.

The **Large Object Heap (LOH)** stores objects ≥ 85,000 bytes. It's never compacted by default, causing fragmentation over time. Allocating many large short-lived objects can exhaust the LOH.

---

## The Code

**Understanding allocation patterns**
```csharp
// These allocate on the heap — GC must eventually collect them
var list    = new List<int>();         // one heap allocation
var person  = new Person("Alice", 30); // one heap allocation
var boxed   = (object)42;             // boxing — one heap allocation

// These DON'T allocate (or allocate once)
int x = 42;                    // stack — no GC
Span<byte> buf = stackalloc byte[64]; // stack — no GC
static readonly Func<int, bool> IsEven = static n => n % 2 == 0; // one alloc, reused
```

**Reducing allocations — common patterns**
```csharp
// Object pooling — reuse expensive objects
var pool = System.Buffers.ArrayPool<byte>.Shared;
byte[] buffer = pool.Rent(4096); // from pool — no allocation if available
try { /* use buffer */ }
finally { pool.Return(buffer); }

// Avoid per-iteration allocations in loops
var sb = new StringBuilder(); // allocate OUTSIDE loop
for (int i = 0; i < 10_000; i++)
{
    sb.Clear();
    sb.Append("Item ").Append(i);
    Process(sb.ToString()); // one allocation per iteration instead of many
}
```

**LOH — avoid large short-lived allocations**
```csharp
// BAD: each call allocates 1 MB on LOH — fragments LOH over time
void ProcessBad()
{
    byte[] buffer = new byte[1_024_000]; // LOH — never compacted
    // ... use and discard ...
}

// GOOD: rent from pool — LOH object lives for the app lifetime
void ProcessGood()
{
    byte[] buffer = System.Buffers.ArrayPool<byte>.Shared.Rent(1_024_000);
    try { /* use */ }
    finally { System.Buffers.ArrayPool<byte>.Shared.Return(buffer); }
}
```

**GC APIs — rarely needed but useful for diagnostics**
```csharp
// Force collection — use only in benchmarks/tests, never production
GC.Collect();
GC.WaitForPendingFinalizers();

// Allocation diagnostics
long before = GC.GetTotalAllocatedBytes(precise: true);
DoWork();
long after  = GC.GetTotalAllocatedBytes(precise: true);
Console.WriteLine($"Allocated: {after - before} bytes");

// Tell GC a large external resource has been allocated
GC.AddMemoryPressure(nativeSize);   // hints: collect sooner
GC.RemoveMemoryPressure(nativeSize); // when released
```

---

## Common Misconceptions

**"Calling `GC.Collect()` in production helps performance"**
It usually hurts — you force a full Gen 2 collection (expensive) at a time of your choosing rather than the GC's. The GC's heuristics are well-tuned. Only valid exceptions: after a known large allocation spike (like loading a level in a game) to establish a known clean state.

**"The GC runs on a separate thread so my code never pauses"**
Background GC parallelises much of the work, but there are still brief stop-the-world pauses for synchronisation. Server GC has multiple heaps (one per logical CPU) and shorter pauses, but they still exist.

---

## Gotchas

- **Event subscriptions root the subscriber in the publisher.** A short-lived subscriber that doesn't unsubscribe keeps itself alive as long as the publisher lives. The most common managed memory leak.
- **Static fields live forever.** A `static List<T>` never gets GC'd. Growing it indefinitely is a memory leak.
- **Closures captured in long-lived delegates root their captured variables.** A closure that captures `DbContext` and is stored in a static event keeps the context alive.
- **`GC.KeepAlive(obj)` prevents premature collection.** When interoperating with native code that holds an unmanaged handle, the managed wrapper can be collected before the native side is done.
- **Finalisation adds two GC cycles.** An object with a finalizer (`~MyClass()`) is placed on the finalisation queue rather than collected immediately. This promotes it to Gen 1 or 2, delaying reclamation by at least one collection cycle.

---

## Interview Angle

**What they're really testing:** Whether you understand the generational model and can reason about what causes GC pressure, not just that GC "manages memory."

**Common question forms:**
- "How does the .NET GC work?"
- "What is the Large Object Heap?"
- "What causes GC pauses and how do you reduce them?"

**The depth signal:** A senior explains the generational hypothesis — most objects die young, so Gen 0 collections are cheap and frequent. They know the LOH is for ≥ 85 KB objects, is never compacted by default (causing fragmentation), and the fix is `ArrayPool<T>`. They can name the three concrete allocation anti-patterns: boxing in loops, string concatenation in loops, and event subscription leaks.

---

## Related Topics

- [[dotnet/csharp/csharp-idisposable.md]] — Deterministic cleanup of unmanaged resources; complements GC for non-memory resources
- [[dotnet/csharp/csharp-span-memory.md]] — Zero-allocation patterns that reduce GC pressure
- [[dotnet/csharp/csharp-boxing-unboxing.md]] — A major source of unexpected allocations

---

## Source

[Fundamentals of garbage collection — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals)

---
*Last updated: 2026-04-06*