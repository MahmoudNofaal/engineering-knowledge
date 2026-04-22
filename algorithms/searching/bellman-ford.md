# Bellman-Ford Algorithm

> A shortest-path algorithm that handles negative edge weights and detects negative cycles — O(VE) time, slower than Dijkstra but correct where Dijkstra fails.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Relax all edges V-1 times; detect negative cycles on the Vth pass |
| **Use when** | Weighted graph with negative edges; detect negative cycles |
| **Avoid when** | All weights non-negative (use Dijkstra — much faster) |
| **C# version** | C# 1.0+ (pure iteration, no special data structures) |
| **Namespace** | None — uses arrays/dictionaries |
| **Key types** | `int[]` or `Dictionary<int,int>` for distances, edge list as `(int u, int v, int w)[]` |

---

## When To Use It

Use Bellman-Ford when edge weights can be negative — currency exchange arbitrage detection, financial network analysis, certain game graphs. It's also the only standard single-source algorithm that can detect negative cycles (a cycle whose total weight is negative, making the shortest path undefined). When all weights are non-negative, Dijkstra is dramatically faster: O((V+E) log V) vs O(VE).

---

## Core Concept

Bellman-Ford relaxes all edges V-1 times. After k relaxations, the algorithm has found the shortest paths using at most k edges. After V-1 relaxations (the maximum number of edges in any simple path), all shortest paths are found — assuming no negative cycles.

A Vth relaxation pass is then run: if any distance still decreases, a negative cycle is reachable, since the path length would keep decreasing indefinitely.

The edge list representation (not adjacency list) is natural for Bellman-Ford — the algorithm iterates over all edges, not over adjacency lists per vertex.

---

## Algorithm History

| Year | Development |
|---|---|
| 1955 | Alfonso Shimbel describes the algorithm |
| 1957 | Richard Bellman publishes his formulation |
| 1958 | Lester Ford Jr. publishes independently |
| 1959 | Edward Moore rediscovers it — sometimes called "Bellman-Ford-Moore" |
| 1970s | SPFA (Shortest Path Faster Algorithm) developed as a practical optimisation |

---

## Performance

| Variant | Time | Space | Notes |
|---|---|---|---|
| Standard Bellman-Ford | O(VE) | O(V) | |
| SPFA (queue-based optimisation) | O(E) average | O(V) | O(VE) worst case |
| Dijkstra (comparison) | O((V+E) log V) | O(V) | Only for non-negative weights |

**Allocation behaviour:** Distance array O(V). Edge list is usually provided — no extra allocation for the algorithm itself.

**Benchmark notes:** For V=100, E=500: Bellman-Ford does 100 × 500 = 50,000 operations. Dijkstra does ~(100 + 500) × log(100) ≈ 4,000 operations — 12× faster. At V=1000, E=10,000: 10M vs 133K — 75× faster. Use Bellman-Ford only when negative weights are present.

---

## The Code

**Scenario 1 — standard Bellman-Ford**
```csharp
public Dictionary<int, int> BellmanFord(
    int[] vertices,
    (int U, int V, int W)[] edges,
    int source)
{
    var dist = vertices.ToDictionary(v => v, _ => int.MaxValue);
    dist[source] = 0;

    // Relax all edges V-1 times
    for (int i = 0; i < vertices.Length - 1; i++)
    {
        bool updated = false;
        foreach (var (u, v, w) in edges)
        {
            if (dist[u] != int.MaxValue && dist[u] + w < dist[v])
            {
                dist[v] = dist[u] + w;
                updated = true;
            }
        }
        if (!updated) break; // early termination: no more relaxation possible
    }
    return dist;
}
```

**Scenario 2 — detect negative cycles**
```csharp
public bool HasNegativeCycle(
    int[] vertices,
    (int U, int V, int W)[] edges,
    int source)
{
    var dist = vertices.ToDictionary(v => v, _ => int.MaxValue);
    dist[source] = 0;

    for (int i = 0; i < vertices.Length - 1; i++)
        foreach (var (u, v, w) in edges)
            if (dist[u] != int.MaxValue && dist[u] + w < dist[v])
                dist[v] = dist[u] + w;

    // Vth pass: any further relaxation means a negative cycle is reachable
    foreach (var (u, v, w) in edges)
        if (dist[u] != int.MaxValue && dist[u] + w < dist[v])
            return true; // negative cycle detected

    return false;
}
```

**Scenario 3 — currency arbitrage detection**
```csharp
// Model currency exchange as a graph: negative log of exchange rate as edge weight.
// A negative cycle = arbitrage opportunity (profit by cycling through currencies).
public bool HasArbitrageOpportunity(string[] currencies, double[,] rates)
{
    int n = currencies.Length;
    var edges = new List<(int U, int V, double W)>();
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            if (i != j && rates[i, j] > 0)
                edges.Add((i, j, -Math.Log(rates[i, j]))); // negative log for min-path = max-product

    var dist = new double[n];
    Array.Fill(dist, double.MaxValue);
    dist[0] = 0;

    for (int k = 0; k < n - 1; k++)
        foreach (var (u, v, w) in edges)
            if (dist[u] != double.MaxValue && dist[u] + w < dist[v])
                dist[v] = dist[u] + w;

    // Vth pass for negative cycle
    foreach (var (u, v, w) in edges)
        if (dist[u] != double.MaxValue && dist[u] + w < dist[v])
            return true; // negative cycle = arbitrage exists

    return false;
}
```

**Scenario 4 — what NOT to do: using Dijkstra with negative weights**
```csharp
// BAD: Dijkstra with negative weights — gives WRONG answers silently
// Example: A→B (weight 4), A→C (weight 3), C→B (weight -2)
// Dijkstra settles B at 4 first, then never re-processes it even though A→C→B = 1
// Correct answer: 1. Dijkstra returns: 4.
public void DijkstraWrongForNegative()
{
    // Never use Dijkstra when any edge weight can be negative.
    // Dijkstra's "settled = final" invariant assumes all future paths are ≥ 0.
    // A negative edge can always produce a shorter path to a settled node.
}

// GOOD: use Bellman-Ford for negative weights
// Always check for negative weights before choosing the algorithm.
public bool HasNegativeWeight((int U, int V, int W)[] edges)
    => edges.Any(e => e.W < 0);
```

---

## Real World Example

The `FxArbitrageDetector` at a financial trading firm monitors currency exchange rates and detects arbitrage opportunities — sequences of currency conversions that return more than the starting amount. This is the negative-cycle detection problem on a directed weighted graph.

```csharp
public class FxArbitrageDetector
{
    public record ArbitrageResult(bool HasOpportunity, List<string>? CyclePath);

    public ArbitrageResult Detect(string[] currencies, Dictionary<(string From, string To), double> rates)
    {
        int n = currencies.Length;
        var idx = currencies.Select((c, i) => (c, i)).ToDictionary(x => x.c, x => x.i);
        var edges = rates.Select(kv =>
            (idx[kv.Key.From], idx[kv.Key.To], -Math.Log(kv.Value))).ToArray();

        var dist = new double[n];
        var prev = new int[n];
        Array.Fill(dist, double.MaxValue);
        Array.Fill(prev, -1);
        dist[0] = 0;

        int lastRelaxed = -1;
        for (int i = 0; i < n - 1; i++)
        {
            lastRelaxed = -1;
            foreach (var (u, v, w) in edges)
                if (dist[u] != double.MaxValue && dist[u] + w < dist[v])
                {
                    dist[v] = dist[u] + w;
                    prev[v] = u;
                    lastRelaxed = v;
                }
        }

        // Vth pass: find a node still being relaxed
        foreach (var (u, v, w) in edges)
            if (dist[u] != double.MaxValue && dist[u] + w < dist[v])
                lastRelaxed = v;

        if (lastRelaxed == -1) return new ArbitrageResult(false, null);

        // Trace back V steps to guarantee we're in the cycle
        int cycleNode = lastRelaxed;
        for (int i = 0; i < n; i++) cycleNode = prev[cycleNode];

        // Extract the cycle
        var cycle = new List<string>();
        for (int v = cycleNode; ; v = prev[v])
        {
            cycle.Add(currencies[v]);
            if (v == cycleNode && cycle.Count > 1) break;
        }
        cycle.Reverse();
        return new ArbitrageResult(true, cycle);
    }
}
```

*The key insight: converting exchange rates to negative logarithms transforms the "maximum product path" problem into a "minimum sum path" problem — standard for shortest-path algorithms. A negative-weight cycle in this transformed graph corresponds directly to a profitable arbitrage cycle in the original rates.*

---

## Common Misconceptions

**"Bellman-Ford is just slow Dijkstra"**
They solve different problems. Dijkstra cannot handle negative weights at all — it gives wrong answers. Bellman-Ford handles negative weights and detects negative cycles. They're not interchangeable; the choice is determined by whether negative weights are present.

**"V-1 iterations is always required"**
Not necessarily. Adding early termination (`if no edge was relaxed this pass: break`) can exit after far fewer iterations on sparse or nearly-optimised graphs. In practice, many real-world graphs converge in O(E/V) passes on average.

**"A negative edge weight means Bellman-Ford is needed"**
Only if the negative edge is reachable from the source and relevant to the query. If you're certain the graph has no negative cycles and Dijkstra gives correct answers on your specific input, Dijkstra is fine. In practice, always run Bellman-Ford if any edge weight could be negative.

---

## Gotchas

- **Guard against `int.MaxValue + w` overflow.** When `dist[u] == int.MaxValue` and `w` is negative, `dist[u] + w` wraps around to a large positive number — appearing falsely shorter. Always check `if (dist[u] != int.MaxValue)` before relaxing.
- **V iterations, not V-1, for negative cycle detection.** The Vth pass is the detection step. Running only V-1 passes finds shortest paths; the extra pass detects cycles.
- **Bellman-Ford requires an edge list, not an adjacency list.** The algorithm iterates over all E edges per pass. An adjacency list requires a nested loop to produce the same iteration. An explicit edge list `(u, v, w)[]` is cleaner.
- **Disconnected graphs: unreachable nodes keep `dist = int.MaxValue`.** Check before using distance values.
- **SPFA is not always faster.** SPFA (queue-based Bellman-Ford) has O(VE) worst case despite O(E) average. On adversarial graphs, SPFA degrades. Prefer standard Bellman-Ford when worst-case matters.

---

## Interview Angle

**What they're really testing:** Whether you know when Dijkstra fails and why, and whether you can correctly implement the negative-cycle detection pass.

**Common question forms:**
- "Find the cheapest flight within K stops" (variant of Bellman-Ford with K relaxation passes).
- "Detect arbitrage in a currency exchange network."
- "Is there a negative cycle in this graph?"

**The depth signal:** A junior knows Bellman-Ford handles negative weights. A senior explains why Dijkstra fails (settled-node invariant breaks), implements the V-1 relaxation passes correctly with the early termination optimisation, and knows the Vth-pass negative cycle detection. They also know SPFA as a queue-based optimisation and its worst-case caveat.

**Follow-up questions to expect:**
- "Why does Dijkstra fail with negative weights?" → Once a node is settled, Dijkstra never revisits it. A negative edge later in the graph could produce a shorter path to a settled node, but Dijkstra won't find it.
- "Why V-1 passes?" → Any simple path in a V-node graph has at most V-1 edges. After k passes, Bellman-Ford has found all shortest paths using ≤ k edges. V-1 passes cover all simple paths.

---

## Related Topics

- [[algorithms/searching/dijkstra.md]] — The faster alternative for non-negative weights.
- [[algorithms/datastructures/graph.md]] — Graph representations and the broader shortest-path landscape.
- [[algorithms/patterns/dynamic-programming.md]] — Bellman-Ford is a DP algorithm: `dist[v] = min over all edges (u,v) of dist[u] + w`.

---

## Source

https://en.wikipedia.org/wiki/Bellman%E2%80%93Ford_algorithm

---

*Last updated: 2026-04-21*