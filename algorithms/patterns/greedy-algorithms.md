# Greedy Algorithms
> An approach that builds a solution by always making the locally optimal choice at each step, with the hope (and proof) that local optima lead to a global optimum.

---

## When To Use It
Use greedy when you can prove that the local optimal choice never needs to be reversed — the choice is safe. Common signals: interval scheduling, minimum spanning trees, Huffman coding, activity selection. Greedy fails when a locally good choice forecloses a globally better path — that's when you need DP. The hard part of greedy problems is proving correctness, not implementing the algorithm.

---

## Core Concept
Greedy differs from DP in commitment: greedy makes a choice and never revisits it; DP explores all options and picks the best. Greedy works when the problem has the **greedy choice property** — the globally optimal solution can be constructed by making the locally optimal choice at each step. It also requires **optimal substructure** — the same property DP requires.

The standard proof technique is exchange argument: assume there's an optimal solution that differs from the greedy solution. Show that you can exchange the differing part with the greedy choice without making the solution worse. This proves the greedy choice is always at least as good.

---

## The Code

**Activity selection — maximize non-overlapping intervals**
```csharp
public int ActivitySelection(List<(int, int)> intervals)
{
    // Sort by end time — finish earliest to leave most room for future activities
    intervals.Sort((a, b) => a.Item2.CompareTo(b.Item2));
    int count = 0;
    int lastEnd = int.MinValue;
    foreach (var (start, end) in intervals)
    {
        if (start >= lastEnd)    // no overlap with last selected activity
        {
            count++;
            lastEnd = end;
        }
    }
    return count;
}
```

**Merge intervals**
```csharp
public List<(int, int)> MergeIntervals(List<(int, int)> intervals)
{
    intervals.Sort((a, b) => a.Item1.CompareTo(b.Item1));
    var merged = new List<(int, int)> { intervals[0] };
    for (int i = 1; i < intervals.Count; i++)
    {
        var (start, end) = intervals[i];
        var (lastStart, lastEnd) = merged[merged.Count - 1];
        if (start <= lastEnd)
        {
            merged[merged.Count - 1] = (lastStart, Math.Max(lastEnd, end));
        }
        else
        {
            merged.Add((start, end));
        }
    }
    return merged;
}
```

**Jump game — can you reach the end?**
```csharp
public bool CanJump(int[] nums)
{
    int reach = 0;
    for (int i = 0; i < nums.Length; i++)
    {
        if (i > reach)
            return false;        // can't reach this index
        reach = Math.Max(reach, i + nums[i]);
    }
    return true;
}
```

**Jump game II — minimum jumps to reach end**
```csharp
public int Jump(int[] nums)
{
    int jumps = 0, currentEnd = 0, farthest = 0;
    for (int i = 0; i < nums.Length - 1; i++)
    {
        farthest = Math.Max(farthest, i + nums[i]);
        if (i == currentEnd)          // exhausted current jump range
        {
            jumps++;
            currentEnd = farthest;    // expand to the farthest reachable
        }
    }
    return jumps;
}
```

**Task scheduler — minimum time with cooldown**
```csharp
public int LeastInterval(char[] tasks, int n)
{
    var counts = new Dictionary<char, int>();
    foreach (char task in tasks)
    {
        if (counts.ContainsKey(task))
            counts[task]++;
        else
            counts[task] = 1;
    }
    int maxCount = 0;
    foreach (var count in counts.Values)
        maxCount = Math.Max(maxCount, count);
    
    // number of tasks with the maximum frequency
    int maxCountTasks = 0;
    foreach (var count in counts.Values)
    {
        if (count == maxCount)
            maxCountTasks++;
    }
    // fit tasks into (max_count-1) chunks of size (n+1), plus the last row
    int intervals = (maxCount - 1) * (n + 1) + maxCountTasks;
    return Math.Max(intervals, tasks.Length); // can't be less than total tasks
}
```

**Fractional knapsack — greedily take highest value/weight ratio**
```csharp
public double FractionalKnapsack(List<(double, double)> items, double capacity)
{
    // items = [(value, weight), ...]
    items.Sort((a, b) => (b.Item1 / b.Item2).CompareTo(a.Item1 / a.Item2));  // sort by value density
    double total = 0.0;
    foreach (var (value, weight) in items)
    {
        if (capacity >= weight)
        {
            total += value;
            capacity -= weight;
        }
        else
        {
            total += value * (capacity / weight);  // take fraction
            break;
        }
    }
    return total;
}
```

---

## Gotchas

- **Greedy fails on 0/1 knapsack.** You can't take a fraction, so the highest value-density item isn't always the right choice. A later combination of items may be better. This is the canonical example of where greedy fails and DP is needed.
- **Sort order determines correctness.** Activity selection sorted by end time is correct. Sorted by start time or duration — it's wrong. The sort is not a heuristic; it's mathematically justified by the exchange argument.
- **Greedy correctness requires a proof, not intuition.** A solution that "feels greedy" can be subtly wrong. The exchange argument is the standard proof: assume the optimal differs from greedy at step k, swap the differing choice, show the solution doesn't worsen.
- **The jump game II greedy is non-obvious.** The key insight is tracking the farthest reachable position within the current jump range — not the farthest reachable position overall. When you exhaust the current range, you must take a jump regardless of where you land.
- **Greedy for graphs requires careful handling.** Dijkstra is greedy (always settle the closest unsettled node) but only works for non-negative weights. Prim's and Kruskal's MST algorithms are greedy and provably correct by exchange argument.

---

## Interview Angle

**What they're really testing:** Whether you can identify that a problem is greedy (not DP), choose the right greedy criterion, and justify it — not just implement it.

**Common question form:** Meeting rooms, non-overlapping intervals, jump game, task scheduler, assign cookies, gas station.

**The depth signal:** A junior implements activity selection by sorting and scanning. A senior knows *why* sorting by end time is the correct criterion — the exchange argument — and can articulate why sorting by start time or duration fails. They also know the boundary: fractional knapsack is greedy; 0/1 knapsack is DP. That distinction, explained cleanly, is a strong signal.

---

## Related Topics

- [[algorithms/dynamic-programming.md]] — The alternative when greedy fails; both require optimal substructure.
- [[algorithms/sorting-in-practice.md]] — Greedy problems almost always start with a sort.
- [[algorithms/graph.md]] — Dijkstra and MST algorithms (Prim, Kruskal) are greedy algorithms on graphs.

---

## Source

https://en.wikipedia.org/wiki/Greedy_algorithm

---

*Last updated: 2026-03-24*