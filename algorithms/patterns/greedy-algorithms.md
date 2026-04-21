# Greedy Algorithms

> An approach that builds a solution by always making the locally optimal choice at each step, with the proof (not just the hope) that local optima lead to a global optimum.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Irrevocable locally-optimal choices that produce a global optimum |
| **Use when** | Interval scheduling, fractional knapsack, Huffman, MST, provably safe local choice |
| **Avoid when** | Local optimum doesn't guarantee global (use DP instead) |
| **C# version** | C# 1.0+ (typically requires `Array.Sort` with custom comparator) |
| **Namespace** | None — pattern uses standard sorting and iteration |
| **Key types** | `List<(int start, int end)>`, `PriorityQueue<T,P>` for Huffman |

---

## When To Use It

Use greedy when you can prove that the local optimal choice never needs to be reversed — the choice is safe. Common signals: interval scheduling, minimum spanning trees, Huffman coding, activity selection. Greedy fails when a locally good choice forecloses a globally better path — that's when you need DP. The hard part of greedy problems is proving correctness, not implementing the algorithm.

---

## Core Concept

Greedy differs from DP in commitment: greedy makes a choice and never revisits it; DP explores all options and picks the best. Greedy works when the problem has the **greedy choice property** — the globally optimal solution can be constructed by making the locally optimal choice at each step — and **optimal substructure** — solving subproblems optimally gives an optimal overall solution.

The standard proof technique is the **exchange argument**: assume an optimal solution differs from the greedy solution at step k. Show that you can swap the differing choice with the greedy choice without making the solution worse. This proves the greedy choice is always at least as good.

---

## Algorithm History

| Year | Development |
|---|---|
| 1956 | Kruskal's MST algorithm — one of the earliest formal greedy algorithms |
| 1959 | Dijkstra's shortest path — greedy with a priority queue |
| 1961 | Huffman coding — provably optimal prefix-free code via greedy merging |
| 1971 | Edmonds' matroid theory formalizes when greedy is optimal |
| 1979 | Activity selection problem formalized by Cormen et al. |

*Matroid theory (Edmonds, 1971) is the mathematical foundation that explains precisely when greedy works — a problem has an optimal greedy solution if and only if it can be formulated over a matroid.*

---

## Performance

| Algorithm | Time | Space | Notes |
|---|---|---|---|
| Activity selection | O(n log n) | O(1) | Dominated by sort |
| Merge intervals | O(n log n) | O(n) | Output array |
| Jump game (can reach?) | O(n) | O(1) | One pass, no sort needed |
| Jump game II (min jumps) | O(n) | O(1) | One pass |
| Fractional knapsack | O(n log n) | O(1) | Sort by value density |
| Task scheduler | O(n log n) | O(k) | k = distinct task types |
| Huffman coding | O(n log n) | O(n) | Priority queue of n symbols |

**Allocation behaviour:** Most greedy algorithms sort in-place and then iterate — O(1) extra space beyond the sort's stack. Exceptions: merge intervals outputs a new list (O(n)); Huffman builds a tree (O(n) nodes).

**Benchmark notes:** Greedy is almost always faster than DP for the same problem when greedy is applicable — O(n log n) vs O(n²) or O(n × W). The entire value of recognising a greedy opportunity is replacing a DP table with a sort.

---

## The Code

**Scenario 1 — activity selection (maximum non-overlapping intervals)**
```csharp
public int ActivitySelection(List<(int Start, int End)> intervals)
{
    // Sort by end time — finish earliest to leave most room for future activities
    intervals.Sort((a, b) => a.End.CompareTo(b.End));
    int count = 0, lastEnd = int.MinValue;
    foreach (var (start, end) in intervals)
    {
        if (start >= lastEnd) // no overlap with last selected
        {
            count++;
            lastEnd = end;
        }
    }
    return count;
}
```

**Scenario 2 — jump game II (minimum jumps to reach end)**
```csharp
public int Jump(int[] nums)
{
    int jumps = 0, currentEnd = 0, farthest = 0;
    for (int i = 0; i < nums.Length - 1; i++)
    {
        farthest = Math.Max(farthest, i + nums[i]);
        if (i == currentEnd) // exhausted current jump range — must jump now
        {
            jumps++;
            currentEnd = farthest; // expand to the farthest reachable
        }
    }
    return jumps;
}
```

**Scenario 3 — fractional knapsack (take highest value-density items first)**
```csharp
public double FractionalKnapsack(List<(double Value, double Weight)> items, double capacity)
{
    // Sort by value per unit weight descending
    items.Sort((a, b) => (b.Value / b.Weight).CompareTo(a.Value / a.Weight));
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
            total += value * (capacity / weight); // take the fraction
            break;
        }
    }
    return total;
}
```

**Scenario 4 — what NOT to do: applying greedy to 0/1 knapsack**
```csharp
// BAD: greedy by value-density fails for 0/1 knapsack
// Items: [(value=60, weight=10), (value=100, weight=20), (value=120, weight=30)]
// Capacity: 50
// Greedy picks: item1 (density 6) + item2 (density 5) = value 160, weight 30 → then item3 doesn't fit
// Optimal: item2 + item3 = value 220, weight 50 → greedy gave wrong answer
public double KnapsackGreedyBad(List<(int Value, int Weight)> items, int capacity)
{
    items.Sort((a, b) => (b.Value / (double)b.Weight).CompareTo(a.Value / (double)a.Weight));
    double total = 0;
    foreach (var (value, weight) in items)
        if (capacity >= weight) { total += value; capacity -= weight; } // can't take fraction
    return total; // WRONG for 0/1 knapsack
}

// GOOD: use DP for 0/1 knapsack
public int KnapsackDP(List<(int Value, int Weight)> items, int capacity)
{
    var dp = new int[capacity + 1];
    foreach (var (value, weight) in items)
        for (int w = capacity; w >= weight; w--) // iterate backwards to prevent reuse
            dp[w] = Math.Max(dp[w], dp[w - weight] + value);
    return dp[capacity];
}
```

---

## Real World Example

The `JobSchedulerService` in a cloud task execution platform assigns tasks to worker slots to maximise throughput. Each task has a deadline (must complete by slot d) and a profit. Scheduling to maximise profit is the classic job sequencing with deadlines problem — a greedy algorithm that always picks the highest-profit unscheduled task and places it in the latest available slot before its deadline.

```csharp
public class JobSchedulerService
{
    public record Job(string Id, int Deadline, int Profit);

    // Returns the maximum achievable profit and the selected job schedule.
    // Each job takes exactly one unit of time. Slots are numbered 1..maxDeadline.
    public (int MaxProfit, List<Job> Schedule) OptimalSchedule(List<Job> jobs)
    {
        // Greedy choice: always process the highest-profit job first,
        // assign it to the latest available slot before its deadline.
        jobs = jobs.OrderByDescending(j => j.Profit).ToList();

        int maxSlot = jobs.Max(j => j.Deadline);
        var slots   = new Job?[maxSlot + 1]; // slots[i] = job assigned to time slot i
        int totalProfit = 0;

        foreach (var job in jobs)
        {
            // Find the latest available slot at or before the deadline
            for (int slot = Math.Min(job.Deadline, maxSlot); slot >= 1; slot--)
            {
                if (slots[slot] == null)
                {
                    slots[slot]  = job;
                    totalProfit += job.Profit;
                    break;
                }
            }
        }

        var schedule = slots
            .Where(j => j != null)
            .Cast<Job>()
            .ToList();

        return (totalProfit, schedule);
    }
}
```

*The key insight: by processing jobs highest-profit-first and placing each in the latest available slot, we guarantee that lower-profit jobs are displaced only when a higher-profit job absolutely needs that slot — and that every selected job meets its deadline. The exchange argument proves no rearrangement of selected jobs improves profit.*

---

## Common Misconceptions

**"If greedy gives the right answer on my examples, it's correct"**
Greedy correctness requires a proof, not test cases. The canonical counterexample is coin change with {1, 5, 11} denominations and amount 15: greedy picks 11+1+1+1+1 = 5 coins; optimal is 5+5+5 = 3 coins. Always ask: "can I construct an exchange argument?" before claiming greedy works.

**"Sort order is a heuristic that usually works"**
The sort order is mathematically justified — it's not a heuristic. Activity selection sorted by end time is provably correct via the exchange argument. Sorted by start time or duration it produces wrong answers. The sort is not interchangeable.

**"Greedy and DP have the same time complexity"**
Greedy is almost always faster. DP for 0/1 knapsack is O(n × W); greedy for fractional knapsack is O(n log n). Greedy for interval scheduling is O(n log n); DP for the same problem would be O(n²). Recognising that a problem is greedily solvable is worth looking for precisely because it eliminates the DP table.

---

## Gotchas

- **Greedy fails on 0/1 knapsack.** You can't take a fraction, so the highest value-density item isn't always the right choice. A later combination of items may be better. This is the canonical example of where greedy fails and DP is needed.

- **The jump game II greedy is non-obvious.** Track the farthest reachable position within the current jump range — not the farthest reachable position overall. When you exhaust the current range (i == currentEnd), you must take a jump. Forgetting the currentEnd tracker is the most common bug.

- **Interval scheduling vs interval partitioning are different problems.** Activity selection (maximum non-overlapping) is greedy by end time. Interval partitioning (minimum number of "rooms" to hold all intervals) is greedy by start time with a min-heap tracking end times. Using end-time sort for partitioning gives wrong answers.

- **Huffman coding requires a min-heap, not a sorted array.** After each merge, the combined node is inserted back and re-sorted. A static sort at the start doesn't work because the merged nodes introduce new values that need to be reordered.

- **Dijkstra is greedy — and fails with negative edge weights.** Dijkstra's greedy invariant (settling the closest unsettled node is final) breaks when negative edges can later produce a shorter path to an already-settled node. The greedy choice property only holds for non-negative weights.

---

## Interview Angle

**What they're really testing:** Whether you can identify that a problem is greedy (not DP), choose the correct greedy criterion, and justify it — not just implement it.

**Common question forms:**
- "Meeting rooms / non-overlapping intervals."
- "Jump game I and II."
- "Task scheduler with cooldown."
- "Assign cookies / gas station."
- "Minimum number of arrows to burst balloons."

**The depth signal:** A junior implements activity selection by sorting and scanning. A senior knows why sorting by end time is the correct criterion — the exchange argument — and can articulate why sorting by start time or duration fails. They also know the boundary: fractional knapsack is greedy; 0/1 knapsack is DP. That distinction, explained with a concrete counterexample, is a strong signal.

**Follow-up questions to expect:**
- "Can you prove this greedy is correct?" → Exchange argument: assume optimal differs from greedy at step k, swap the choice, show the solution doesn't worsen.
- "When would you use DP instead?" → When the greedy choice can foreclose a better global path.

---

## Related Topics

- [[algorithms/patterns/dynamic-programming.md]] — The alternative when greedy fails; both require optimal substructure.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — Greedy problems almost always start with a sort.
- [[algorithms/datastructures/heap.md]] — Huffman coding, Dijkstra, and task scheduler all require a priority queue.

---

## Source

https://en.wikipedia.org/wiki/Greedy_algorithm

---

*Last updated: 2026-04-21*