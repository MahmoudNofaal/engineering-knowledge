# Performance Testing in .NET

> Performance testing measures how fast code runs and how it behaves under load — benchmarks for micro-level speed, load tests for system-level throughput and latency.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Measuring and validating execution speed and throughput |
| **Use when** | Validating hot paths, catching performance regressions, capacity planning |
| **Avoid when** | Premature optimisation — profile first to confirm the bottleneck |
| **Micro-benchmarks** | `BenchmarkDotNet` — standard library for method-level benchmarks |
| **Load testing** | `NBomber` (.NET-native) or `k6` (JS scripts, wide industry use) |
| **Key package** | `BenchmarkDotNet` |

---

## When To Use It
Use performance tests when you have a specific bottleneck hypothesis (confirmed by profiling), a hot path that must meet a latency SLA, or a regression risk on critical infrastructure code. Don't benchmark before profiling — profiling tells you *where* time is spent; benchmarking tells you *how much*. Don't write benchmarks for code that's called once at startup or in low-frequency paths — the ROI is in tight loops, serialisation, caching, and data access layers. Load tests belong in CI only if the infrastructure to run them exists; they're expensive and environment-sensitive.

---

## Core Concept
**BenchmarkDotNet** measures how long a method takes by running it thousands of times, warming up the JIT, discarding outliers, and producing statistically valid results with mean, median, and standard deviation. It handles the subtleties that make naive `Stopwatch` benchmarks unreliable: JIT compilation, GC pressure, CPU cache effects, and process noise. The output is a table comparing methods with their execution time and memory allocation.

**Load testing** is different — it sends concurrent HTTP requests to a running service to find throughput limits, identify degradation under sustained load, and surface concurrency bugs. `NBomber` is .NET-native and integrates with xUnit for test assertions. `k6` is language-agnostic and more common in teams with mixed stacks.

The key rule for benchmarks: **never benchmark in Debug mode** and **never run benchmarks inside xUnit tests**. BenchmarkDotNet spawns separate processes in Release mode to get clean results — running it inline in a test produces meaningless numbers.

---

## Version History

| Package | Version | What changed |
|---|---|---|
| `BenchmarkDotNet` | 0.10 | Column providers, exporters (HTML, CSV, JSON) |
| `BenchmarkDotNet` | 0.12 | Disassembly diagnoser; `[MemoryDiagnoser]` for allocation tracking |
| `BenchmarkDotNet` | 0.13 | `[HideColumns]`, `[SimpleJob]` for parameterised runtimes |
| `BenchmarkDotNet` | 0.13.5+ | .NET 7/8 support; `[ThreadingDiagnoser]` for concurrency |
| `NBomber` | 5.x | Scenario-based load testing; xUnit integration |

---

## Performance

BenchmarkDotNet itself adds no overhead to production code — it only runs in dedicated benchmark projects. A full benchmark run takes 1–10 minutes depending on how many methods are benchmarked and how many warmup/iteration cycles are configured.

---

## The Code

```csharp
// Setup — benchmarks live in a separate console project, not the test project
// dotnet new console -n MyApp.Benchmarks
// dotnet add package BenchmarkDotNet
```

```csharp
// 1. Basic benchmark — comparing two serialisation approaches
[MemoryDiagnoser]           // tracks allocations per operation
[SimpleJob(RuntimeMoniker.Net80)]
public class SerializationBenchmarks
{
    private readonly OrderDto _order = new OrderDto
    {
        Id = 1, CustomerId = "cust-001", Total = 150m, Status = "Pending",
        Items = Enumerable.Range(1, 10)
            .Select(i => new OrderItemDto { ProductId = $"prod-{i}", Quantity = i })
            .ToList()
    };

    [Benchmark(Baseline = true)]
    public string SystemTextJson()
    {
        return System.Text.Json.JsonSerializer.Serialize(_order);
    }

    [Benchmark]
    public string NewtonsoftJson()
    {
        return Newtonsoft.Json.JsonConvert.SerializeObject(_order);
    }
}

// Run with: dotnet run -c Release
// Output:
// | Method          | Mean     | Alloc |
// |---------------- |---------:|------:|
// | SystemTextJson  | 1.23 µs  |  640 B|
// | NewtonsoftJson  | 3.87 µs  | 1.8 KB|
```

```csharp
// 2. Parameterised benchmark — test with different input sizes
[MemoryDiagnoser]
public class CollectionFilterBenchmarks
{
    private List<Order> _orders = null!;

    [Params(100, 1_000, 10_000)]   // benchmark runs three times with each N
    public int N;

    [GlobalSetup]
    public void Setup()
    {
        _orders = Enumerable.Range(1, N)
            .Select(i => new Order { Id = i, Total = i * 10m,
                                     Status = i % 2 == 0 ? OrderStatus.Pending : OrderStatus.Shipped })
            .ToList();
    }

    [Benchmark(Baseline = true)]
    public List<Order> LinqWhere()
    {
        return _orders.Where(o => o.Status == OrderStatus.Pending).ToList();
    }

    [Benchmark]
    public List<Order> ForLoop()
    {
        var result = new List<Order>(_orders.Count);
        foreach (var order in _orders)
            if (order.Status == OrderStatus.Pending)
                result.Add(order);
        return result;
    }
}
```

```csharp
// 3. Allocation benchmark — finding zero-allocation hot paths
[MemoryDiagnoser]
public class AllocationBenchmarks
{
    private readonly int[] _data = Enumerable.Range(1, 1000).ToArray();

    [Benchmark(Baseline = true)]
    public int SumWithLinq()
    {
        return _data.Sum();               // allocates enumerator
    }

    [Benchmark]
    public int SumWithSpan()
    {
        var span = _data.AsSpan();
        int sum = 0;
        foreach (var n in span) sum += n;  // zero allocation
        return sum;
    }
}
```

```csharp
// 4. Performance regression test in CI — lightweight check without BenchmarkDotNet
// For CI gates: use Stopwatch with a generous threshold to catch catastrophic regressions
// Not a replacement for proper benchmarks — just a smoke test

[Fact]
public async Task GetOrders_LargeDataset_CompletesUnder500ms()
{
    await SeedAsync(10_000); // seed 10k orders

    var stopwatch = Stopwatch.StartNew();
    var response  = await _client.GetAsync("/api/orders?page=1&pageSize=50");
    stopwatch.Stop();

    response.StatusCode.Should().Be(HttpStatusCode.OK);
    stopwatch.ElapsedMilliseconds.Should().BeLessThan(500,
        because: "paginated query of 10k orders should complete in < 500ms");
}
```

```csharp
// 5. NBomber load test — concurrent HTTP load against a running service
// dotnet add package NBomber
// dotnet add package NBomber.Http

[Fact]
public void PostPayment_Under100ConcurrentUsers_MeetsLatencySLA()
{
    var scenario = Scenario.Create("payment_scenario", async context =>
    {
        var payload  = new { Amount = 100m, Currency = "GBP", RecipientId = "rec-001" };
        var response = await _client.PostAsJsonAsync("/api/payments", payload);

        return response.IsSuccessStatusCode
            ? Response.Ok()
            : Response.Fail();
    })
    .WithLoadSimulations(
        Simulation.Inject(rate: 100, interval: TimeSpan.FromSeconds(1),
                          during: TimeSpan.FromSeconds(30))
    );

    var stats = NBomberRunner
        .RegisterScenarios(scenario)
        .Run();

    var scenarioStats = stats.ScenarioStats.First();
    scenarioStats.Ok.Request.RPS.Should().BeGreaterThan(90,
        because: "should sustain 90 req/s under 100 concurrent users");
    scenarioStats.Ok.Latency.P99.Should().BeLessThan(200,
        because: "P99 latency should be under 200ms");
    scenarioStats.Fail.Request.Count.Should().Be(0,
        because: "no requests should fail under nominal load");
}
```

```csharp
// 6. Entry point for BenchmarkDotNet — in Program.cs of benchmark project
// BenchmarkSwitcher lets you choose which benchmarks to run interactively
var summary = BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args);

// Or run a specific benchmark directly:
// BenchmarkRunner.Run<SerializationBenchmarks>();
```

---

## Real World Example

A data export service generates large CSV files from database queries. An initial implementation using LINQ and string concatenation took 8 seconds for 100,000 rows. A benchmark confirmed the bottleneck was string allocation. The team rewrote the hot path using `StringBuilder` and `Span<char>`, then used BenchmarkDotNet to validate the improvement and track it against future regressions.

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net80)]
public class CsvExportBenchmarks
{
    private List<ExportRow> _rows = null!;

    [GlobalSetup]
    public void Setup()
    {
        _rows = Enumerable.Range(1, 100_000)
            .Select(i => new ExportRow
            {
                Id      = i,
                Name    = $"Customer {i}",
                Total   = i * 9.99m,
                Country = "GB"
            }).ToList();
    }

    [Benchmark(Baseline = true)]
    public string StringConcatenation()
    {
        var result = "Id,Name,Total,Country\n";
        foreach (var row in _rows)
            result += $"{row.Id},{row.Name},{row.Total},{row.Country}\n";
        return result;
    }

    [Benchmark]
    public string StringBuilderApproach()
    {
        var sb = new StringBuilder(capacity: _rows.Count * 40);
        sb.AppendLine("Id,Name,Total,Country");
        foreach (var row in _rows)
            sb.Append(row.Id).Append(',')
              .Append(row.Name).Append(',')
              .Append(row.Total).Append(',')
              .AppendLine(row.Country);
        return sb.ToString();
    }

    [Benchmark]
    public async Task<string> StreamWriterApproach()
    {
        using var ms     = new MemoryStream();
        await using var writer = new StreamWriter(ms);
        await writer.WriteLineAsync("Id,Name,Total,Country");
        foreach (var row in _rows)
            await writer.WriteLineAsync(
                $"{row.Id},{row.Name},{row.Total},{row.Country}");
        await writer.FlushAsync();
        return Encoding.UTF8.GetString(ms.ToArray());
    }
}

// Typical results:
// | Method                | N       | Mean      | Alloc   |
// |---------------------- |-------- |----------:|--------:|
// | StringConcatenation   | 100,000 | 8,234 ms  | 4.2 GB  |  ← catastrophic
// | StringBuilderApproach | 100,000 |   142 ms  | 7.8 MB  |  ← 58x faster, 537x less alloc
// | StreamWriterApproach  | 100,000 |   180 ms  | 2.1 MB  |  ← good for streaming to file
```

*The allocation column tells the real story — string concatenation allocates 4.2GB for 100k rows because each `+=` creates a new string. This is the kind of result that turns a performance investigation from a hypothesis into an evidence-based decision.*

---

## Common Misconceptions

**"I can benchmark inside a `[Fact]` test using `Stopwatch`."**
`Stopwatch` in a test measures wall-clock time including JIT compilation, GC pauses, and OS scheduling jitter. The first call is always slower than subsequent calls. BenchmarkDotNet handles warmup, runs thousands of iterations, discards outliers, and reports statistically valid numbers. `Stopwatch` in tests is only useful as a regression smoke test with a generous threshold — not as a performance measurement tool.

**"BenchmarkDotNet can run inside the test project."**
It can, technically — but the results are meaningless because benchmarks must run in Release mode in a separate process. BenchmarkDotNet spawns child processes automatically when run via `dotnet run -c Release`. Running it in Debug or inside a test runner produces inflated timings with JIT compilation artifacts included.

**"Performance testing is only for high-traffic services."**
Any code with a tight loop, a large collection, repeated serialisation, or frequent database calls benefits from benchmarking. The question is whether the code is *on a hot path* — called many times per request or per batch job. A method called once at application startup doesn't need a benchmark.

---

## Gotchas

- **Always run benchmarks with `dotnet run -c Release`** — Debug mode disables JIT optimisations and produces results 3–10x slower than production. BenchmarkDotNet will warn you if it detects Debug mode.

- **Never use `[GlobalSetup]` to create objects that the benchmark is supposed to measure allocation for** — if you create the list in `GlobalSetup`, the allocation for creating it isn't attributed to the benchmark method. Only put setup in `GlobalSetup` that prepares inputs, not the objects being benchmarked.

- **P99 latency in load tests is more important than mean.** A mean of 50ms with a P99 of 2000ms means 1 in 100 users waits 2 seconds. Always assert on percentiles, not averages, in load test assertions.

- **Load tests need a stable environment.** Running NBomber against a local development server on a laptop gives meaningless results. Load tests should run against a dedicated environment (staging or a dedicated load test environment) that matches production resource allocation.

- **BenchmarkDotNet results are sensitive to machine state.** Benchmark results on a laptop with background processes running differ from results on a clean CI machine. Use relative comparisons (this method is 2x faster than that method) rather than absolute values for cross-machine assertions.

---

## Interview Angle

**What they're really testing:** Whether you know the difference between micro-benchmarks and load testing, and whether you understand why naive `Stopwatch` measurements are unreliable.

**Common question forms:**
- *"How do you performance test in .NET?"*
- *"How do you prevent performance regressions?"*
- *"What tools do you use for load testing?"*

**The depth signal:** A junior says "I use `Stopwatch` in a test." A senior knows BenchmarkDotNet specifically — why it spawns a separate process, what `[MemoryDiagnoser]` adds, why allocation matters as much as execution time. They distinguish micro-benchmarks (single method speed) from load tests (system throughput under concurrency), know P99 is more relevant than mean for user-facing latency, and have a CI strategy: smoke tests with generous `Stopwatch` thresholds for regression detection, full benchmarks run manually when investigating a specific bottleneck.

**Follow-up questions to expect:**
- *"What does `[MemoryDiagnoser]` do?"* — Reports bytes allocated per operation, not total heap size. Identifies methods that create unexpected allocations causing GC pressure.
- *"What's the difference between mean and P99 in load test results?"* — Mean tells you the average; P99 tells you what the slowest 1% of requests experience. For user-facing APIs, P99 is what defines the worst-case user experience.

---

## Related Topics

- [[dotnet/testing/testing-integration-tests.md]] — Lightweight Stopwatch regression tests live in integration tests; proper benchmarks live in a separate project.
- [[dotnet/testing/testing-unit-tests.md]] — Performance tests complement, not replace, correctness tests — always verify correctness first, then measure performance.
- [[dotnet/csharp/csharp-span-memory.md]] — `Span<T>` and `Memory<T>` are the primary tools for zero-allocation hot paths that benchmarks confirm.
- [[dotnet/csharp/csharp-garbage-collector.md]] — Understanding GC pressure explains why allocation benchmarks matter as much as execution time.

---

## Source

https://benchmarkdotnet.org/articles/overview.html

---
*Last updated: 2026-04-12*