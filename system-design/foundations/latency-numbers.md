# Latency Numbers Every Engineer Should Know

> A reference set of hardware and network operation speeds that ground system design decisions in physical reality.

---

## When To Use It
Whenever you're making a decision that involves data movement — reading from disk vs. memory, making a network call vs. computing locally, choosing between a cache hit and a database query. These numbers tell you whether your proposed design is fast or slow before you build it. In interviews, citing concrete latency numbers when justifying a design choice is a clear senior signal.

---

## Core Concept
Different storage and network layers differ in speed by several orders of magnitude. L1 cache access is around 1 nanosecond. Reading 1 MB from RAM takes around 250 microseconds. A round trip within the same datacenter is roughly 500 microseconds. A round trip across the internet can be 150 milliseconds or more. The mental model to internalize: memory is fast, disk is slow, network is slow, and cross-region network is painful. Every cache, every local computation, every async queue is an attempt to avoid paying the cost of the slow layers.

---

## The Code
```csharp
// Latency reference table — memorize the orders of magnitude, not the exact nanoseconds.
// Source: Jeff Dean's numbers, updated for modern hardware.

var latenciesNs = new Dictionary<string, long>
{
    // ── CPU & Memory ──────────────────────────────────────────────
    { "L1 cache reference",              (long)0.5 },
    { "Branch misprediction",            5 },
    { "L2 cache reference",              7 },
    { "Mutex lock/unlock",               25 },
    { "Main memory reference",           100 },

    // ── Storage ───────────────────────────────────────────────────
    { "SSD random read (NVMe)",          20_000 },          // 20 µs
    { "Read 1 MB sequentially from SSD", 1_000_000 },       // 1 ms
    { "HDD disk seek",                   10_000_000 },      // 10 ms
    { "Read 1 MB sequentially from HDD", 20_000_000 },      // 20 ms

    // ── Network ───────────────────────────────────────────────────
    { "Send 1 KB over 1 Gbps network",   10_000 },          // 10 µs
    { "Same datacenter round trip",      500_000 },         // 0.5 ms
    { "Cross-region round trip (US–EU)", 150_000_000 },     // 150 ms
};

Console.WriteLine($"{"Operation",-42} {"Latency",12}");
Console.WriteLine(new string('-', 56));
foreach (var kvp in latenciesNs)
{
    string label;
    if (kvp.Value >= 1_000_000)
        label = $"{kvp.Value / 1_000_000.0:F1} ms";
    else if (kvp.Value >= 1_000)
        label = $"{kvp.Value / 1_000.0:F1} µs";
    else
        label = $"{kvp.Value:F1} ns";
    Console.WriteLine($"{kvp.Key,-42} {label,12}");
}
```
```csharp
// ── Practical implications in design decisions ────────────────────────────

public void DesignDecision(string readSource, int readsPerSecond)
{
    var latenciesMs = new Dictionary<string, double>
    {
        { "l1_cache",       0.0000005 },
        { "ram",            0.0001 },
        { "ssd",            0.02 },
        { "hdd",            10.0 },
        { "local_network",  0.5 },
        { "cross_region",   150.0 },
    };
    
    double latency = latenciesMs[readSource];
    double totalLatencyS = (latency * readsPerSecond) / 1000;
    Console.WriteLine($"{readsPerSecond} reads/s from {readSource}: {totalLatencyS:F2}s of I/O per second");
}

// 10K reads/sec from HDD = this is catastrophic
DesignDecision("hdd", 10_000);

// 10K reads/sec from RAM = totally fine
DesignDecision("ram", 10_000);
```

---

## Gotchas
- **Latency numbers change, but ratios don't.** NVMe SSDs have made disk reads far faster than the classic Jeff Dean numbers. What stays true is that memory is ~1000x faster than SSD, and SSD is ~100x faster than spinning disk. Memorize the ratios, not the absolutes.
- **Network latency has a floor set by physics.** Light through fiber travels at roughly 200,000 km/s. A London–New York round trip has a physical minimum of ~35ms regardless of how fast your servers are. No optimization overcomes geography.
- **Tail latency is what users feel.** p99 latency (the slowest 1% of requests) is often 10x the median. A system with 5ms median and 500ms p99 is a slow system from the user's perspective. Always ask about p99, not average.
- **Serialization and deserialization add up.** JSON encoding/decoding on a hot path at high RPS can add milliseconds of CPU latency that doesn't show up in your network measurements. Profile the full round trip, not just the wire time.
- **These numbers assume no queueing.** Under load, requests queue in buffers at every layer (NIC, kernel, application). Actual observed latency at 80% utilization is far higher than the raw hardware latency suggests.

---

## Interview Angle
**What they're really testing:** Whether your design intuitions are grounded in hardware reality or just pattern matching.

**Common question form:** "Why would you use a cache here?" or "Why not just read from the database every time?"

**The depth signal:** A junior candidate says "the cache is faster." A senior candidate says "a cache hit in Redis is sub-millisecond because it's an in-memory read — roughly 100µs. A Postgres query hitting disk is 10–20ms without optimization, and at 5000 RPS that's the difference between a database that's fine and one that's on fire. The cache also absorbs read amplification — one popular record doesn't cause 5000 disk reads per second." The separation is: juniors know caching is good, seniors know *why* and can quantify it.

---

## Related Topics
- [[system-design/back-of-envelope.md]] — Latency numbers feed directly into throughput and bandwidth calculations.
- [[system-design/caching-strategies.md]] — The primary tool for avoiding slow-layer latency at scale.
- [[system-design/client-server-model.md]] — Network latency is paid on every client-server round trip.

---

## Source
https://colin-scott.github.io/personal_website/research/interactive_latency.html

---
*Last updated: 2026-03-24*