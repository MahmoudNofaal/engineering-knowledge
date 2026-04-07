# C# Channels

> `System.Threading.Channels` provides async-native, bounded or unbounded producer/consumer queues — the correct abstraction for decoupling work producers from consumers in async pipelines.

---

## Quick Reference

| | `Channel.CreateUnbounded<T>()` | `Channel.CreateBounded<T>(N)` |
|---|---|---|
| **Capacity** | Unlimited | N items max |
| **Write blocks?** | Never | When full (backpressure) |
| **OOM risk** | Yes, if producer outpaces consumer | No |
| **Use when** | Consumer always keeps up | Backpressure needed |

---

## When To Use It

Use channels for **async producer/consumer pipelines** — one or more producers enqueue work, one or more consumers process it asynchronously. Channels are the modern replacement for `BlockingCollection<T>` because they're fully async — writers and readers await rather than block.

Don't use channels when all work can be created before processing starts (`Task.WhenAll` is simpler) or when you need rich ordering/priority semantics.

---

## Core Concept

A `Channel<T>` has a `Writer` and a `Reader`. The writer calls `await writer.WriteAsync(item, ct)` — returns immediately if there's capacity, or awaits until space is available (bounded). The reader calls `await reader.ReadAsync(ct)` — returns the next item or awaits until one is available.

When the producer is done, it calls `writer.Complete()` — the reader's `ReadAllAsync()` loop terminates naturally after draining remaining items.

---

## The Code

**Basic producer/consumer pipeline**
```csharp
var channel = Channel.CreateBounded<Order>(capacity: 100);

// Producer: writes orders
Task producer = Task.Run(async () =>
{
    await foreach (var order in FetchOrdersAsync(ct))
    {
        await channel.Writer.WriteAsync(order, ct); // blocks if full — backpressure
    }
    channel.Writer.Complete(); // signal no more items
});

// Consumer: processes orders
Task consumer = Task.Run(async () =>
{
    await foreach (var order in channel.Reader.ReadAllAsync(ct))
        await ProcessOrderAsync(order, ct);
    // loop exits cleanly when writer.Complete() is called and channel drained
});

await Task.WhenAll(producer, consumer);
```

**Multiple consumers — fan-out**
```csharp
var channel = Channel.CreateUnbounded<WorkItem>();

// 4 concurrent workers — all read from the same channel
var workers = Enumerable.Range(0, 4)
    .Select(_ => Task.Run(async () =>
    {
        await foreach (var item in channel.Reader.ReadAllAsync(ct))
            await ProcessAsync(item, ct);
    }))
    .ToArray();

// Produce work
foreach (var item in GetWork())
    await channel.Writer.WriteAsync(item, ct);
channel.Writer.Complete();

await Task.WhenAll(workers);
```

**Bounded channel with drop-oldest strategy**
```csharp
var options = new BoundedChannelOptions(100)
{
    FullMode = BoundedChannelFullMode.DropOldest // drop old items when full
};
var channel = Channel.CreateBounded<LogEntry>(options);
```

---

## Real World Example

An event ingestion pipeline receives webhook events and processes them with controlled concurrency.

```csharp
public class WebhookProcessor : BackgroundService
{
    private readonly Channel<WebhookEvent> _channel
        = Channel.CreateBounded<WebhookEvent>(new BoundedChannelOptions(500)
            { FullMode = BoundedChannelFullMode.Wait });

    public async Task EnqueueAsync(WebhookEvent evt, CancellationToken ct)
        => await _channel.Writer.WriteAsync(evt, ct); // HTTP handler enqueues

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var workers = Enumerable.Range(0, 4)
            .Select(_ => ProcessLoopAsync(stoppingToken))
            .ToArray();
        await Task.WhenAll(workers);
    }

    private async Task ProcessLoopAsync(CancellationToken ct)
    {
        await foreach (var evt in _channel.Reader.ReadAllAsync(ct))
        {
            try   { await HandleAsync(evt, ct); }
            catch (Exception ex) { logger.LogError(ex, "Failed: {Id}", evt.Id); }
        }
    }
}
```

---

## Gotchas

- **Not calling `writer.Complete()` hangs `ReadAllAsync` consumers forever.** They await the next item that never comes.
- **`CreateUnbounded` can exhaust memory** if the producer is faster than the consumer. Use `CreateBounded` for production code.
- **`TryWrite` never awaits — returns false when full.** Use `WriteAsync` for backpressure.
- **Multiple writers need no synchronisation** — `ChannelWriter<T>` is thread-safe. Same for `ChannelReader<T>`.

---

## Interview Angle

**What they're really testing:** Whether you know channels as the modern async alternative to `BlockingCollection` and can articulate backpressure.

**Common question forms:**
- "How would you implement a producer/consumer pattern in async code?"
- "What's the difference between bounded and unbounded channels?"

**The depth signal:** A senior reaches for bounded channels to apply backpressure (the producer naturally slows when the consumer can't keep up), and knows `writer.Complete()` is required for clean shutdown of `ReadAllAsync`.

---

## Related Topics

- [[dotnet/csharp/csharp-async-await.md]] — Channels are fully async; `await foreach` drains the reader
- [[dotnet/csharp/csharp-concurrent-collections.md]] — `BlockingCollection<T>` is the sync predecessor

---

## Source

[Channels — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)

---
*Last updated: 2026-04-06*