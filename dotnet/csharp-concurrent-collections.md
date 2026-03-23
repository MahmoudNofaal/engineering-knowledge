# C# Concurrent Collections

> Thread-safe collection types in `System.Collections.Concurrent` that allow multiple threads to add, remove, and read without external locking.

---

## When To Use It

Use concurrent collections any time multiple threads need to share a collection — producer/consumer queues, caches shared across requests, aggregation from parallel work. They replace the pattern of wrapping a `List<T>` or `Dictionary<TKey,TValue>` in a `lock` block, which is correct but creates a single contention point. Do not use them when only one thread ever touches the collection — the overhead of thread-safe operations is unnecessary. Do not use them when you need atomic operations across multiple collections simultaneously — they protect individual operations, not multi-collection transactions.

---

## Core Concept

The standard collections (`List<T>`, `Dictionary<TKey,TValue>`, `Queue<T>`) are not thread-safe. If two threads call `Add` at the same moment, internal state can corrupt. The naive fix is a `lock` around every access, which works but serialises every reader and writer through a single gate. The concurrent collections use finer-grained strategies: `ConcurrentDictionary` stripes its internal buckets so threads operating on different keys rarely contend; `ConcurrentQueue` and `ConcurrentStack` use lock-free compare-and-swap (CAS) operations backed by `Interlocked`; `BlockingCollection` wraps any concurrent collection and adds bounded capacity plus blocking `Take` — the foundation of the producer/consumer pattern. The trade-off is that compound operations ("check then act") are not atomic across separate method calls — the collection provides atomicity per call, not per workflow.

---

## The Code
```csharp
// --- ConcurrentDictionary: thread-safe key-value store ---
var cache = new ConcurrentDictionary<string, string>();

// GetOrAdd is atomic: only one thread runs the factory for a given key
string value = cache.GetOrAdd("user:1", key => LoadFromDb(key));

// AddOrUpdate: atomically update an existing value or add new
cache.AddOrUpdate(
    key: "counter",
    addValue: "1",
    updateValueFactory: (key, existing) => (int.Parse(existing) + 1).ToString());

// TryGetValue / TryRemove are the safe read/remove primitives
if (cache.TryGetValue("user:1", out string? result))
    Console.WriteLine(result);

cache.TryRemove("user:1", out _);

// --- ConcurrentQueue: lock-free FIFO ---
var queue = new ConcurrentQueue<int>();

// Producer threads
Parallel.For(0, 10, i => queue.Enqueue(i));

// Consumer threads
while (queue.TryDequeue(out int item))
    Console.WriteLine(item);

// --- ConcurrentStack: lock-free LIFO ---
var stack = new ConcurrentStack<string>();
stack.Push("first");
stack.Push("second");

stack.TryPop(out string? top);      // "second"
stack.TryPeek(out string? peeked);  // non-destructive read

// PushRange / TryPopRange for batch operations (more efficient than one-by-one)
stack.PushRange(new[] { "a", "b", "c" });
string[] popped = new string[3];
int count = stack.TryPopRange(popped); // returns number actually popped

// --- BlockingCollection: bounded producer-consumer with backpressure ---
// Default backing store is ConcurrentQueue
using var buffer = new BlockingCollection<string>(boundedCapacity: 100);

// Producer (runs on its own thread)
Task producer = Task.Run(() =>
{
    foreach (string item in GetItems())
    {
        buffer.Add(item); // blocks if buffer is full (backpressure)
    }
    buffer.CompleteAdding(); // signals no more items coming
});

// Consumer (runs on its own thread)
Task consumer = Task.Run(() =>
{
    foreach (string item in buffer.GetConsumingEnumerable()) // blocks until item available
    {
        Process(item);
    } // exits cleanly when CompleteAdding() is called and queue is drained
});

await Task.WhenAll(producer, consumer);

// --- ConcurrentBag: unordered, optimised for same-thread produce+consume ---
// Good for object pools; poor for strict producer/consumer separation
var bag = new ConcurrentBag<StringBuilder>();
bag.Add(new StringBuilder());

if (!bag.TryTake(out StringBuilder? sb))
    sb = new StringBuilder(); // create new if pool is empty

sb.Clear();
bag.Add(sb); // return to pool
```

---

## Gotchas

- **`GetOrAdd` on `ConcurrentDictionary` can call the factory more than once.** Under contention, two threads may both find the key missing and both invoke the factory. Only one result is stored, but the factory runs twice. If the factory has side effects (creating a DB connection, allocating a large object), this causes real problems. Wrap with `Lazy<T>` as the value type when the factory must run exactly once.
- **Compound operations are not atomic.** `ContainsKey` followed by `TryGetValue` on `ConcurrentDictionary` is not thread-safe as a pair — another thread can remove the key between the two calls. Always use the single atomic methods: `TryGetValue`, `GetOrAdd`, `AddOrUpdate`, `TryRemove`. Never combine separate calls and assume the result is consistent.
- **`ConcurrentBag<T>` performs poorly when producers and consumers are different threads.** It is optimised for a thread-local list per thread. When one thread produces and a different thread consumes, it degenerates into high contention. Use `ConcurrentQueue` for cross-thread producer/consumer and `ConcurrentBag` only for same-thread pooling scenarios.
- **`BlockingCollection.Add` throws `InvalidOperationException` after `CompleteAdding` is called.** If a producer calls `Add` after the consumer has signalled completion — a race that can happen when shutdown ordering is wrong — the exception is thrown synchronously. Wrap `Add` in a `try/catch` for `InvalidOperationException` or check `IsAddingCompleted` first in shutdown-sensitive paths.
- **Enumerating concurrent collections gives a snapshot, not a live view.** Iterating a `ConcurrentDictionary` with `foreach` is safe but reflects the state at an unspecified point in time — items added or removed during the iteration may or may not appear. Never rely on enumeration for correctness in concurrent code; use it only for diagnostics or logging.

---

## Interview Angle

**What they're really testing:** Whether you understand why thread-safe collections exist at a mechanical level — not just "use `ConcurrentDictionary` instead of `Dictionary`" — and where their guarantees end.

**Common question form:** "How would you share a cache across multiple threads?" or "What's wrong with locking a `Dictionary` yourself?"

**The depth signal:** A junior says "use `ConcurrentDictionary` because it's thread-safe." A senior explains that `ConcurrentDictionary` uses bucket-level striping to reduce contention vs a single `lock`, names the `GetOrAdd`-factory-runs-twice problem and the `Lazy<T>` fix, distinguishes per-call atomicity from compound-operation atomicity, and knows that `BlockingCollection` with `CompleteAdding`/`GetConsumingEnumerable` is the canonical producer/consumer pattern — including that omitting `CompleteAdding` leaves the consumer blocked forever.

---

## Related Topics

- [[dotnet/csharp-lock-mutex.md]] — Concurrent collections eliminate the need for manual locking in most cases; knowing both shows when each is appropriate.
- [[dotnet/csharp-task-parallel-library.md]] — Parallel work almost always needs a thread-safe way to collect results; `ConcurrentBag` and `ConcurrentQueue` are the natural pairing with `Parallel.For` and `Task.WhenAll`.
- [[dotnet/csharp-channels.md]] — `Channel<T>` is the modern, async-native evolution of `BlockingCollection`; prefer it for new producer/consumer code where consumers need to `await` items.
- [[dotnet/csharp-deadlocks.md]] — Removing explicit locks with concurrent collections is one of the cleanest ways to eliminate lock-ordering deadlocks entirely.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/](https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/)

---
*Last updated: 2026-03-23*