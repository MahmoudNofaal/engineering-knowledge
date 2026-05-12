# C# Concurrent Collections

> Thread-safe collection types in `System.Collections.Concurrent` that allow multiple threads to add, remove, and read without external locking.

---

## Quick Reference

| Type | Model | Use for |
|---|---|---|
| `ConcurrentDictionary<K,V>` | Striped hash table | Shared caches, counters |
| `ConcurrentQueue<T>` | Lock-free FIFO | Producer/consumer queues |
| `ConcurrentStack<T>` | Lock-free LIFO | Work-stealing, undo |
| `ConcurrentBag<T>` | Thread-local LIFO | Object pools (same-thread produce+consume) |
| `BlockingCollection<T>` | Bounded + blocking | Bounded producer/consumer |

---

## When To Use It

Use concurrent collections any time multiple threads need to share a collection. They replace the pattern of wrapping a `List<T>` or `Dictionary<K,V>` in a `lock` block — which is correct but creates a single contention point.

**Don't use them when:**
- Only one thread ever touches the collection — overhead is unnecessary
- You need atomic operations across multiple collections simultaneously — they protect individual operations, not multi-collection transactions

---

## Core Concept

Standard collections aren't thread-safe — concurrent `Add` calls can corrupt internal state. The naive fix is a `lock` around every access, which serialises all threads. Concurrent collections use finer-grained strategies: `ConcurrentDictionary` stripes its internal buckets so threads operating on different keys rarely contend; `ConcurrentQueue` and `ConcurrentStack` use lock-free compare-and-swap (CAS) operations.

**Critical limitation:** Each *individual* method call is atomic, but compound operations ("check then act") are not. Two separate method calls can be interleaved by other threads between them.

---

## The Code

**`ConcurrentDictionary`**
```csharp
var cache = new ConcurrentDictionary<string, string>();

// GetOrAdd: atomic — factory only runs if key is absent
string value = cache.GetOrAdd("user:1", key => LoadFromDb(key));

// AddOrUpdate: atomic read-modify-write
cache.AddOrUpdate(
    key: "counter",
    addValue: "1",
    updateValueFactory: (key, existing) => (int.Parse(existing) + 1).ToString());

if (cache.TryGetValue("user:1", out string? result))
    Console.WriteLine(result);

cache.TryRemove("user:1", out _);
```

**`ConcurrentQueue` — lock-free FIFO**
```csharp
var queue = new ConcurrentQueue<int>();
Parallel.For(0, 10, i => queue.Enqueue(i));
while (queue.TryDequeue(out int item))
    Console.WriteLine(item);
```

**`BlockingCollection` — bounded producer/consumer**
```csharp
using var buffer = new BlockingCollection<string>(boundedCapacity: 100);

Task producer = Task.Run(() =>
{
    foreach (string item in GetItems())
        buffer.Add(item);          // blocks if full (backpressure)
    buffer.CompleteAdding();       // signals no more items
});

Task consumer = Task.Run(() =>
{
    foreach (string item in buffer.GetConsumingEnumerable()) // blocks until available
        Process(item);
    // exits cleanly when CompleteAdding() called and queue is drained
});

await Task.WhenAll(producer, consumer);
```

**`ConcurrentBag` — object pool pattern**
```csharp
var pool = new ConcurrentBag<StringBuilder>();

StringBuilder GetBuilder()
{
    if (!pool.TryTake(out var sb))
        sb = new StringBuilder();
    return sb;
}

void ReturnBuilder(StringBuilder sb) { sb.Clear(); pool.Add(sb); }
```

---

## Real World Example

A request-scoped counter tracks API usage without locks using `ConcurrentDictionary`.

```csharp
public class ApiUsageTracker
{
    private readonly ConcurrentDictionary<string, long> _counts = new();
    private readonly ConcurrentDictionary<string, long> _bytes  = new();

    public void RecordRequest(string apiKey, long bytesServed)
    {
        // AddOrUpdate is one atomic operation — no race between read and write
        _counts.AddOrUpdate(apiKey, 1L, (_, c) => c + 1);
        _bytes.AddOrUpdate(apiKey, bytesServed, (_, b) => b + bytesServed);
    }

    public (long Requests, long Bytes) GetUsage(string apiKey)
        => (_counts.GetValueOrDefault(apiKey),
            _bytes.GetValueOrDefault(apiKey));
}
```

---

## Gotchas

- **`GetOrAdd` factory can run more than once.** Under contention, two threads may both find the key missing and both invoke the factory. Only one result is stored, but the factory runs twice. Wrap with `Lazy<T>` as the value type when the factory must run exactly once.
- **Compound operations are not atomic.** `ContainsKey` followed by `TryGetValue` is not safe as a pair — another thread can remove the key between them. Always use the single atomic methods: `TryGetValue`, `GetOrAdd`, `AddOrUpdate`, `TryRemove`.
- **`ConcurrentBag` degrades with cross-thread produce/consume.** It's optimised for same-thread scenarios. For cross-thread producer/consumer, use `ConcurrentQueue`.
- **`BlockingCollection.Add` throws after `CompleteAdding`.** Wrap in try/catch for `InvalidOperationException` in shutdown-sensitive paths.
- **Enumeration gives a snapshot, not a live view.** Safe to iterate but reflects state at an unspecified point in time — items added/removed during iteration may or may not appear.

---

## Interview Angle

**What they're really testing:** Whether you understand why thread-safe collections exist and where their guarantees end.

**Common question forms:**
- "How would you share a cache across multiple threads?"
- "What's wrong with locking a `Dictionary` yourself?"

**The depth signal:** A senior explains bucket-level striping, names the `GetOrAdd`-factory-runs-twice problem and the `Lazy<T>` fix, and distinguishes per-call atomicity from compound-operation atomicity.

---

## Related Topics

- [[dotnet/csharp/csharp-lock-mutex.md]] — When manual locking is still needed
- [[dotnet/csharp/csharp-channels.md]] — `Channel<T>` for async-native producer/consumer

---

## Source

[Thread-Safe Collections — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/)

---
*Last updated: 2026-04-06*