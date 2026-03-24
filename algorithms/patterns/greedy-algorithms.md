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
```python
def activity_selection(intervals: list) -> int:
    # Sort by end time — finish earliest to leave most room for future activities
    intervals.sort(key=lambda x: x[1])
    count = 0
    last_end = float('-inf')
    for start, end in intervals:
        if start >= last_end:          # no overlap with last selected activity
            count += 1
            last_end = end
    return count
```

**Merge intervals**
```python
def merge_intervals(intervals: list) -> list:
    intervals.sort(key=lambda x: x[0])
    merged = [intervals[0]]
    for start, end in intervals[1:]:
        if start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)   # extend current interval
        else:
            merged.append([start, end])
    return merged
```

**Jump game — can you reach the end?**
```python
def can_jump(nums: list) -> bool:
    reach = 0
    for i, jump in enumerate(nums):
        if i > reach:
            return False       # can't reach this index
        reach = max(reach, i + jump)
    return True
```

**Jump game II — minimum jumps to reach end**
```python
def jump(nums: list) -> int:
    jumps = current_end = farthest = 0
    for i in range(len(nums) - 1):
        farthest = max(farthest, i + nums[i])
        if i == current_end:           # exhausted current jump range
            jumps += 1
            current_end = farthest     # expand to the farthest reachable
    return jumps
```

**Task scheduler — minimum time with cooldown**
```python
from collections import Counter

def least_interval(tasks: list, n: int) -> int:
    counts = Counter(tasks)
    max_count = max(counts.values())
    # number of tasks with the maximum frequency
    max_count_tasks = sum(1 for c in counts.values() if c == max_count)
    # fit tasks into (max_count-1) chunks of size (n+1), plus the last row
    intervals = (max_count - 1) * (n + 1) + max_count_tasks
    return max(intervals, len(tasks))  # can't be less than total tasks
```

**Fractional knapsack — greedily take highest value/weight ratio**
```python
def fractional_knapsack(items: list, capacity: int) -> float:
    # items = [(value, weight), ...]
    items.sort(key=lambda x: x[0] / x[1], reverse=True)  # sort by value density
    total = 0.0
    for value, weight in items:
        if capacity >= weight:
            total += value
            capacity -= weight
        else:
            total += value * (capacity / weight)  # take fraction
            break
    return total
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