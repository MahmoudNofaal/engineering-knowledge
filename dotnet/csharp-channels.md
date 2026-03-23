# C# Channels

> A `Channel<T>` is an async-native, bounded or unbounded pipe for passing data between producer and writer threads without shared state or explicit locking.

---

## When To Use It

Use `Channel<T>` any time you need a producer/consumer pipeline where producers and consumers run concurrently and both sides should be able to `await` rather than block. It is the modern replacement for `BlockingCollection<T>` in async code — same mental model, fully async API. Use a bounded channel when you want backpressure: slow consumers will naturally slow down fast producers instead of letting memory grow unbounded. Do not use it when you only need a fire-and-forget queue with no consumer coordination — a `ConcurrentQueue` is simpler. Do not use it when both sides are synchronous; `BlockingCollection` has less ceremony there.

---

## Core Concept

A `Channel<T>` has two ends: a `ChannelWriter<T>` that producers write to, and a `ChannelReader<T>` that consumers read from. They are separate objects on purpose — you give the writer to producers and the reader to consumers; neither side can touch the other's end. Internally, the channel manages a queue and coordinates the two sides with async continuations: if a consumer calls `ReadAsync` and nothing is available, it suspends and is resumed the moment a producer writes. If the channel is bounded and full, the producer's `WriteAsync` suspends until a consumer drains space. No locks, no spinning, no blocked threads. You signal the end of the stream by calling `writer.Complete()`, which causes the reader's `await foreach` to exit cleanly.

---

## The Code
```csharp
// --- Unbounded channel: producer never blocks ---
Channel<int> channel = Channel.CreateUnbounded<int>();

// --- Bounded channel: producer blocks when full (backpressure) ---
Channel<int> bounded = Channel.CreateBounded<int>(new BoundedChannelOptions(capacity: 100)
{
    FullMode = BoundedChannelFullMode.Wait,       // producer awaits space (default)
    // FullMode = BoundedChannelFullMode.DropOldest, // drop oldest item instead of waiting
    SingleWriter = false,
    SingleReader = false
});

// --- Basic producer / consumer ---
ChannelWriter<int> writer = channel.Writer;
ChannelReader<int> reader = channel.Reader;

Task producer = Task.Run(async () =>
{
    for (int i = 0; i < 20; i++)
    {
        await writer.WriteAsync(i);
        await Task.Delay(10); // simulate work between writes
    }
    writer.Complete(); // signals no more items; reader's foreach will exit
});

Task consumer = Task.Run(async () =>
{
    await foreach (int item in reader.ReadAllAsync()) // exits when writer.Complete() called
    {
        Console.WriteLine(item);
    }
});

await Task.WhenAll(producer, consumer);

// --- Multiple producers, single consumer ---
Channel<string> pipe = Channel.CreateUnbounded<string>(new UnboundedChannelOptions
{
    SingleWriter = false, // allows concurrent writers (slightly more overhead)
    SingleReader = true
});

Task[] producers = Enumerable.Range(0, 4).Select(id => Task.Run(async () =>
{
    for (int i = 0; i < 5; i++)
        await pipe.Writer.WriteAsync($"producer-{id}: item-{i}");
})).ToArray();

await Task.WhenAll(producers);
pipe.Writer.Complete();

await foreach (string msg in pipe.Reader.ReadAllAsync())
    Console.WriteLine(msg);

// --- TryWrite / TryRead: non-blocking fast path ---
if (!channel.Writer.TryWrite(99))
{
    // channel is full or completed — handle without awaiting
    Console.WriteLine("Could not write, channel full or closed.");
}

if (channel.Reader.TryRead(out int value))
    Console.WriteLine($"Got {value} immediately");

// --- Pipeline: chain two channels (transform stage) ---
Channel<string> raw    = Channel.CreateUnbounded<string>();
Channel<string> parsed = Channel.CreateUnbounded<string>();

Task ingest = Task.Run(async () =>
{
    foreach (string line in File.ReadLines("input.txt"))
        await raw.Writer.WriteAsync(line);
    raw.Writer.Complete();
});

Task transform = Task.Run(async () =>
{
    await foreach (string line in raw.Reader.ReadAllAsync())
        await parsed.Writer.WriteAsync(line.Trim().ToUpperInvariant());
    parsed.Writer.Complete();
});

Task output = Task.Run(async () =>
{
    await foreach (string line in parsed.Reader.ReadAllAsync())
        Console.WriteLine(line);
});

await Task.WhenAll(ingest, transform, output);
```

---

## Gotchas

- **Forgetting `writer.Complete()` hangs the consumer forever.** `ReadAllAsync` and `ReadAsync` will keep waiting for more items. In shutdown scenarios where an exception interrupts the producer, pass the exception to `writer.Complete(exception)` — the reader will then throw that exception from its `await foreach`, giving you a propagated failure rather than a hung consumer.
- **`SingleWriter = true` and `SingleReader = true` are performance hints, not safety guards.** Setting `SingleWriter = true` allows the channel to use a simpler internal path that assumes concurrent writes will never happen. If you then write from two threads simultaneously, the behaviour is undefined — no exception is thrown. Only set these flags when you can structurally guarantee the constraint.
- **`TryWrite` on a bounded channel returns `false` when full, silently dropping the item.** This is intentional for `FullMode = DropWrite`, but surprises people who use `TryWrite` on a `Wait`-mode channel expecting a block. In `Wait` mode, always use `await WriteAsync` or explicitly handle the `false` return from `TryWrite`.
- **`ReadAllAsync` is not cancellable mid-item.** Passing a `CancellationToken` to `ReadAllAsync` cancels the wait for the next item, not the processing of the current one. If the consumer is slow and you cancel, it stops asking for new items but the current one is already dequeued and lost. Design consumers to check the token inside their processing loop too.
- **Disposing a channel does not complete the writer.** `Channel<T>` does not implement `IDisposable`. Stopping writing requires an explicit `writer.Complete()` call. A `using` block won't help you here — forgetting to call `Complete` in a `finally` is the most common production bug with channels.

---

## Interview Angle

**What they're really testing:** Whether you understand async producer/consumer coordination — backpressure, clean shutdown, and the difference between blocking and suspending.

**Common question form:** "How would you implement a pipeline that processes items concurrently without overwhelming downstream services?" or "What's the difference between `Channel<T>` and `BlockingCollection<T>`?"

**The depth signal:** A junior says "`Channel<T>` is async and `BlockingCollection` blocks threads." A senior explains that the real win is backpressure via `BoundedChannelOptions` with `FullMode.Wait` — the producer suspends without consuming a thread, which means a slow consumer passively throttles a fast producer with zero thread waste; that `writer.Complete(exception)` is the correct error propagation path so the consumer throws rather than hangs; and that `SingleWriter`/`SingleReader` hints let the runtime use a lock-free fast path internally, but violating them silently corrupts state rather than throwing.

---

## Related Topics

- [[dotnet/csharp-concurrent-collections.md]] — `BlockingCollection<T>` is the synchronous predecessor to `Channel<T>`; understanding both shows when each fits.
- [[dotnet/csharp-task-parallel-library.md]] — Channels pair naturally with `Task.WhenAll` for fan-out pipelines and with `async`/`await` throughout.
- [[dotnet/csharp-cancellation-token.md]] — `ReadAllAsync(ct)` and `WriteAsync(item, ct)` both accept tokens; clean shutdown of a channel pipeline requires threading the token through every stage.
- [[dotnet/csharp-concurrent-collections.md]] — `ConcurrentQueue<T>` is the right choice when you don't need async wait or backpressure; channels are overkill for simple in-memory queues.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/core/extensions/channels](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)

---
*Last updated: 2026-03-23*