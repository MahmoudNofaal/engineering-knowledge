# C# Interlocked

> A static class that performs atomic read-modify-write operations on shared variables without using a lock.

---

## When To Use It

Use `Interlocked` when multiple threads need to update a single numeric value or reference — counters, flags, sequence numbers, statistics — and you want to avoid the overhead of a full `lock` block. It is the right tool when the operation fits one of its methods: increment, decrement, add, exchange, or compare-and-swap. Do not reach for it when you need to protect multiple variables together or perform compound logic; `Interlocked` is atomic per call, not across calls. For anything more complex than a single-field update, use `lock` or a concurrent collection.

---

## Core Concept

A CPU reads a value, modifies it, and writes it back. On a multi-core machine, two threads can each read the same value before either writes back — they both see `0`, both compute `1`, both write `1`, and the counter ends up at `1` instead of `2`. This is a race condition. `Interlocked` eliminates it by using CPU-level atomic instructions (like `LOCK XADD` on x86) that make read-modify-write indivisible. No other core can touch the memory location between the read and the write. There is no OS lock, no thread suspension, no kernel call — just a single CPU instruction that the hardware guarantees is atomic. That is why `Interlocked` is faster than `lock` for single-variable updates, and why it only works on one variable at a time.

---

## The Code
```csharp
// --- Increment / Decrement: thread-safe counter ---
private int _requestCount = 0;

public void OnRequest()
{
    Interlocked.Increment(ref _requestCount); // equivalent to _requestCount++ but atomic
}

public void OnComplete()
{
    Interlocked.Decrement(ref _requestCount);
}

public int ActiveRequests => Interlocked.CompareExchange(ref _requestCount, 0, 0); // atomic read

// --- Add: accumulate a value atomically ---
private long _totalBytes = 0;

public void RecordBytesRead(int bytes)
{
    Interlocked.Add(ref _totalBytes, bytes);
}

// --- Exchange: atomically set a value and get the old one back ---
private int _state = 0;

public int SetState(int newState)
{
    return Interlocked.Exchange(ref _state, newState); // returns previous value
}

// --- CompareExchange (CAS): only update if current value matches expected ---
// This is the foundation of all lock-free algorithms.
private int _initialized = 0;

public bool TryInitialize()
{
    // Only the first thread to see _initialized == 0 will swap it to 1.
    // Every subsequent thread finds the value is already 1, not 0, and returns 1.
    int previous = Interlocked.CompareExchange(ref _initialized, 1, comparand: 0);
    return previous == 0; // true means this thread won the race
}

// --- CAS loop: lock-free update of a computed value ---
// Pattern: read → compute → CAS → retry if someone else changed it first
private int _max = 0;

public void UpdateMax(int candidate)
{
    int current;
    do
    {
        current = _max;
        if (candidate <= current) return; // already below current max, nothing to do
    }
    while (Interlocked.CompareExchange(ref _max, candidate, current) != current);
    // If CAS fails (another thread changed _max), loop and try again with the new current
}

// --- Interlocked on references: swap object references atomically ---
private string _status = "idle";

public string SetStatus(string newStatus)
{
    return Interlocked.Exchange(ref _status, newStatus);
}

// --- Read: atomic 64-bit read on 32-bit platforms ---
private long _timestamp = 0;

public long GetTimestamp()
{
    // On 32-bit processes, reading a long is two separate 32-bit reads — not atomic.
    // Interlocked.Read guarantees the full 64-bit value is read atomically.
    return Interlocked.Read(ref _timestamp);
}
```

---

## Gotchas

- **`Interlocked` does not make the variable `volatile`.** The CPU or JIT may still cache a read of the same field in a register elsewhere in your code. If you read `_requestCount` directly without going through `Interlocked`, you might see a stale value. Either read it exclusively through `Interlocked.CompareExchange(ref field, 0, 0)` (a no-op CAS that forces a fresh read) or mark the field `volatile`.
- **CAS loops can spin indefinitely under extreme contention.** The compare-and-swap pattern retries whenever another thread wins the race. With many threads hammering the same field, some threads may retry many times before succeeding — effectively spinning. In high-contention scenarios, a `lock` or `SemaphoreSlim` may produce better throughput because it queues waiters rather than having them all race repeatedly.
- **`Interlocked.Add` does not exist for `double` or `float`.** Only `int` and `long` are supported. For floating-point accumulators, you need either a `lock`, a `long`-backed fixed-point representation, or the `Unsafe`/`Volatile` APIs introduced in .NET 7+.
- **`Interlocked.CompareExchange` returns the value that was in the field at the time of the operation, not the value you tried to set.** A common mistake is comparing the return value to `newValue` to check success. The correct check is `returnValue == comparand` — if they match, the swap happened; if they don't, another thread changed the field first.
- **`Interlocked.Read` is only needed on 32-bit processes for `long` fields.** On 64-bit processes, aligned 64-bit reads are naturally atomic on x86-64. Including it on a 64-bit target is harmless but unnecessary. More importantly, forgetting it on a 32-bit target or ARM where alignment isn't guaranteed can cause a torn read — reading the high 32 bits from one write and the low 32 bits from another.

---

## Interview Angle

**What they're really testing:** Whether you understand why race conditions happen at the hardware level and how atomic instructions eliminate them — not just "use Interlocked instead of ++."

**Common question form:** "How would you implement a thread-safe counter without a lock?" or "Explain compare-and-swap and where you'd use it."

**The depth signal:** A junior says "`Interlocked.Increment` is like `++` but thread-safe." A senior explains that the race condition happens because read-modify-write is three steps and two threads can interleave them, that `Interlocked` uses a single CPU atomic instruction to make those steps indivisible, that `CompareExchange` is the building block for all lock-free algorithms because it lets you optimistically update and detect if another thread raced you, and knows the CAS retry loop pattern — including that high contention can make it slower than a `lock` because spinning threads waste CPU cycles whereas queued threads do not.

---

## Related Topics

- [[dotnet/csharp-lock-mutex.md]] — `lock` is the right tool when `Interlocked` is too narrow; knowing both lets you pick the lightest primitive that fits.
- [[dotnet/csharp-threads.md]] — The race condition `Interlocked` solves is caused by multiple threads sharing memory; understanding threads makes the problem concrete.
- [[dotnet/csharp-concurrent-collections.md]] — Concurrent collections use `Interlocked` and CAS internally; knowing the primitive explains why they are fast and what their limits are.
- [[dotnet/csharp-deadlocks.md]] — Lock-free code via `Interlocked` eliminates one whole class of deadlocks by removing the lock entirely; a useful contrast when discussing synchronisation strategies.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/api/system.threading.interlocked](https://learn.microsoft.com/en-us/dotnet/api/system.threading.interlocked)

---
*Last updated: 2026-03-23*