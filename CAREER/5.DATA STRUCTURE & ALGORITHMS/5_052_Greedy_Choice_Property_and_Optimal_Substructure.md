---
id: "5.052"
studied_well: false
title: "Greedy Choice Property and Optimal Substructure"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Greedy Algorithms"
tags: [dsa, algorithms, greedy, optimal-substructure, greedy-choice, csharp, interviews]
priority: 2
prerequisites:
  - "[[5.059 — DP Fundamentals — Recognizing Problems, Memoization vs Tabulation]]"
  - "[[5.002 — Recursion and the Call Stack]]"
related:
  - "[[5.053 — Interval Scheduling — Activity Selection and Merging Overlapping Intervals]]"
  - "[[5.054 — Common Greedy Patterns — Jump Game, Gas Station, Task Scheduler]]"
  - "[[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Greedy Algorithms
**Previous:** [[5.049 — Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort]] | **Next:** [[5.055 — Backtracking Template — Choose, Explore, Unchoose]]

### Prerequisites
- [[5.059 — DP Fundamentals — Recognizing Problems, Memoization vs Tabulation]] — greedy and DP both require optimal substructure; the comparison between greedy (local choice, no reconsideration) and DP (explore all choices, cache results) is the core distinction.
- [[5.002 — Recursion and the Call Stack]] — greedy algorithms are naturally iterative, but proving optimal substructure often involves induction on the recursion tree.

### Where This Fits
A greedy algorithm builds a solution by making the locally optimal choice at each step, hoping it leads to a globally optimal solution. The Greedy Choice Property is the proof that this hope is justified — it says the first local choice is always part of some optimal solution, and Optimal Substructure says the remaining problem after that choice is an independent instance of the same type. Together, these two properties characterize every problem that a greedy algorithm can solve correctly. This note does not teach a specific algorithm — it teaches the recognition and proof framework that distinguishes greedy from dynamic programming, which is the most common decision a senior candidate must make when facing an optimization problem.

---

## Core Mental Model

A greedy algorithm is "short-sighted but correct": at each step, it commits to the best immediate option without exploring alternatives. This works only when the problem has two properties: (1) the Greedy Choice Property — making the locally optimal choice never excludes the globally optimal solution, and (2) Optimal Substructure — after making the greedy choice, the remaining subproblem is an independent instance of the same problem. If both hold, the greedy algorithm is optimal and O(n log n) or faster. If not, the problem requires DP (explore all choices) or backtracking (search with pruning).

### Classification

Greedy algorithms belong to the **optimization** paradigm. They sit between **direct computation** (closed-form formula, O(1)) and **dynamic programming** (systematic exploration, O(n × W)) on the spectrum of optimization strategies.

```mermaid
graph TD
    subgraph "Optimization Spectrum"
        DC[Direct Computation<br>O(1) or O(n)]
        G[Greedy<br>O(n log n)]
        DP[Dynamic Programming<br>O(n × W) or O(n²)]
        BT[Backtracking<br>O(2ⁿ) or O(n!)]
    end

    DC -->|closed form| G
    G -->|no greedy choice property| DP
    DP -->|no optimal substructure| BT
```

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|Greedy choice property|Local optimal → global optimal|Proved by exchange argument: any optimal solution can be transformed to include the greedy first choice without worsening the result|
|Optimal substructure|Remaining subproblem is independent|After removing the greedy choice, the rest is a smaller instance of the same problem class|
|Typical time|O(n log n)|Sorting (O(n log n)) then a single pass (O(n))|
|Typical space|O(1) or O(n)|Sort in-place where possible; output may need O(n)|

---

## Deep Mechanics

### How It Works

**The two-property proof framework:**

1. **Greedy Choice Property:** Show there exists an optimal solution that includes the greedy choice. Proof technique: take any optimal solution S. If it already contains the greedy choice (e.g., the activity with the earliest finish time), done. If not, replace the first element of S with the greedy choice and show the new solution S' is at least as good as S (feasibility preserved, objective value does not decrease).

2. **Optimal Substructure:** Show that after committing to the greedy choice, the remaining problem is a smaller instance of the same type. This is usually obvious — after picking one interval, you remove it and all overlapping intervals, and the remaining set is exactly the same problem on a reduced input.

**Step-by-step on Activity Selection (prove greedy choice property):**

Problem: Select the maximum number of non-overlapping intervals from [(1,4),(3,5),(0,6),(5,7),(3,9),(5,9),(6,10),(8,11),(8,12),(2,14),(12,16)].

Greedy choice: Pick the activity with the earliest finish time (1,4).

Proof by exchange:
- Let S be any optimal solution. Sort S by finish time.
- Let a₁ be the first activity in S. Its finish time is f(a₁).
- Let g be the greedy choice. Its finish time f(g) is the minimum of all activities — by definition. So f(g) ≤ f(a₁).
- Replace a₁ with g in S, creating S'. Is S' feasible? g finishes at or before a₁ starts, and a₂ starts at or after f(a₁) ≥ f(g). So g does not overlap with a₂. S' has the same size as S.
- Therefore S' is also optimal and contains g. The greedy choice is safe.

**Step-by-step on Coin Change (when the greedy is NOT optimal):**

Problem: Minimum coins to make 6 cents with denominations [1, 3, 4].

Greedy: pick largest ≤ remainder: 4 + 1 + 1 = 3 coins.

Optimal: 3 + 3 = 2 coins.

Why greedy fails: The greedy choice (4) is not part of any optimal solution for 6. The greedy choice property fails. The problem has optimal substructure (after picking one coin, the remainder is a smaller coin-change instance) but not the greedy choice property — so DP is required.

### Complexity Derivation

**Time:** Greedy algorithms are typically a sort (O(n log n)) followed by a single pass (O(n)). Total: O(n log n). The pass is O(n) because each element is examined once and either selected or discarded based on a simple feasibility check.

**Space:** O(1) if the input can be sorted in-place, or O(n) for the sorted copy if not.

### Why This Pattern Exists

The brute force for optimization problems is to enumerate all subsets or permutations: O(2ⁿ) or O(n!). Greedy algorithms avoid this by proving that the optimal solution can be built incrementally without backtracking. The insight is that for certain problems, the first decision does not require exploring alternatives — the best first step is objectively identifiable from the input alone. The exchange argument formalizes this: it shows that no matter what the optimal solution looks like, it can be "bent" to include the greedy choice without loss.

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
/// <summary>
/// Greedy algorithm skeleton. Not an implementation of a specific algorithm —
/// this is the structure that every greedy solution follows.
/// </summary>
public class GreedySkeleton
{
    /// <summary>
    /// Generic greedy: sort by a key, then make a single pass making irreversible choices.
    /// </summary>
    public List<T> SolveGreedy<T>(List<T> items, Func<T, int> sortKey, Func<T, bool> canSelect)
    {
        // Step 1: Sort by the greedy criterion
        var sorted = items.OrderBy(sortKey).ToList();

        // Step 2: Single pass, making local choices
        var result = new List<T>();
        foreach (var item in sorted)
        {
            if (canSelect(item))
            {
                result.Add(item);
                // The choice is irreversible — no backtracking
            }
        }

        return result;
    }

    /// <summary>
    /// Proves the greedy choice property via exchange argument:
    /// 1. Let S be any optimal solution.
    /// 2. Let g be the greedy choice.
    /// 3. Show S can be modified to include g without reducing optimality.
    /// </summary>
    public void ExchangeArgumentProof()
    {
        // Illustration purpose only — the proof is mathematical, not code.
        // See the Activity Selection trace in Section 3 for the canonical example.
    }
}
```

### The .NET Idiomatic Version

Greedy algorithms in C# typically use LINQ's `OrderBy` for sorting and a foreach loop for the linear pass. The `List<T>` and `Array.Sort` are the workhorses. There is no built-in "greedy" collection or algorithm — greedy is a design pattern, not a library feature.

```csharp
// Typical .NET greedy pattern:
var sorted = items.OrderBy(x => x.SomeProperty).ToArray();
// or:
Array.Sort(items, (a, b) => a.SomeProperty.CompareTo(b.SomeProperty));

foreach (var item in items)
{
    if (Condition(item))
    {
        // Commit to the choice
        result.Add(item);
    }
}
```

### Classic Problem Patterns

- **Activity Selection / Interval Scheduling** — Select maximum non-overlapping intervals. Greedy: sort by end time, pick the earliest-finishing that does not conflict. Classic exchange argument proof.
- **Fractional Knapsack** — Maximize value with weight limit, items are divisible. Greedy: sort by value/weight ratio, take highest value density first. Optimal because you can always take a fraction.
- **Minimum Spanning Tree (Prim's / Kruskal's)** — Build cheapest connected subgraph. Prim's: pick the cheapest edge from the current set. Kruskal's: pick the cheapest edge that doesn't create a cycle. Both have greedy choice proofs.
- **Huffman Coding** — Minimum-length prefix-free encoding. Greedy: always combine the two least frequent symbols. Proof: exchange argument shows the two least frequent symbols can always be at the deepest level.
- **Gas Station / Jump Game** — Determine if traversal is possible. Greedy: at each station/gas, maintain the maximum reachable distance; if it drops below the current position, fail. Proof: if a solution exists, the greedy scan finds it.

### Template / Skeleton

```csharp
// Greedy Algorithm Template
// When to use: optimization problem where local choices seem intuitively correct
// Before coding: prove greedy choice property + optimal substructure
// Time: O(n log n) typical | Space: O(1) or O(n)

public List<T> GreedySolve<T>(List<T> input) where T : class
{
    // Step 1: Sort by greedy criterion
    input.Sort((a, b) => /* TODO: return comparison by the greedy key */ 0);

    var result = new List<T>();
    foreach (var item in input)
    {
        // TODO: Check feasibility constraint
        if (/* item can be selected */ true)
        {
            // Make the irrevocable choice
            result.Add(item);
            // TODO: Update state (e.g., track end time of last selected interval)
        }
    }

    return result;
}
```

---

## Gotchas and Edge Cases

### Greedy Without Proof

**Mistake:** Assuming an intuitive greedy choice is correct without proving it.

```csharp
// ❌ Wrong — Coin Change with [1, 3, 4], amount = 6
// Greedy picks 4, then 1, then 1. Optimal is 3 + 3.
var coins = new int[] { 4, 1, 1 };  // Greedy result: 3 coins
```

**Fix:** Verify the greedy choice property via an exchange argument. If it fails, switch to DP.

```csharp
// ✅ Correct — DP approach
int[] dp = new int[amount + 1];
Array.Fill(dp, amount + 1);
dp[0] = 0;
for (int i = 1; i <= amount; i++)
    foreach (int c in coins)
        if (c <= i) dp[i] = Math.Min(dp[i], dp[i - c] + 1);
```

**Consequence:** Wrong answer — the greedy result is suboptimal. This is the most common greedy mistake in interviews.

### Greedy When Sorting Is Required But Not Applied

**Mistake:** Processing elements in input order when the greedy criterion requires sorted order.

```csharp
// ❌ Wrong — interval scheduling on unsorted intervals
foreach (var interval in intervals)
{
    if (interval.Start >= lastEnd)
    {
        count++;
        lastEnd = interval.End;
    }
}
```

**Fix:** Sort by the greedy criterion first.

```csharp
// ✅ Correct
Array.Sort(intervals, (a, b) => a.End.CompareTo(b.End));
foreach (var interval in intervals)
{
    if (interval.Start >= lastEnd)
    {
        count++;
        lastEnd = interval.End;
    }
}
```

**Consequence:** Wrong answer — you may select intervals that are not the earliest-finishing, missing the optimal count.

### Optimal Substructure Violation

**Mistake:** Assuming the subproblem is independent when it is not.

```csharp
// ❌ Wrong — Weighted Interval Scheduling cannot be solved greedily
// The greedy choice (earliest finish) may exclude a high-weight interval that starts later
```

**Fix:** Recognize that weighted interval scheduling has optimal substructure (after choosing an interval, remaining intervals are those starting after it ends) but does NOT have the greedy choice property — the earliest-finishing interval may not be in any optimal solution if a later interval has higher weight. Use DP.

**Consequence:** Wrong answer for weighted variants. Greedy only works when all intervals have equal weight.

### Fractional vs. 0/1 Knapsack Confusion

**Mistake:** Using the fractional knapsack greedy (value/weight ratio) for 0/1 knapsack.

```csharp
// ❌ Wrong — 0/1 knapsack: items are indivisible, greedy fails
// Items: (val=60, wt=10), (val=100, wt=20), (val=120, wt=30), capacity=50
// Greedy by ratio picks: 60/10 + 120/30 = 180 at weight 40, cannot fit 100/20
// Optimal: 100 + 120 = 220
```

**Fix:** For 0/1 knapsack (items indivisible), use DP. For fractional knapsack (items divisible), greedy works.

**Consequence:** Wrong answer for 0/1 knapsack. The greedy is only correct when items can be taken fractionally.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Time (Best)|Time (Average)|Time (Worst)|Space|Notes|
|---|---|---|---|---|---|
|Activity Selection (greedy)|O(n log n)|O(n log n)|O(n log n)|O(1)|Sort by end time + single pass|
|Fractional Knapsack|O(n log n)|O(n log n)|O(n log n)|O(1)|Sort by value/weight ratio|
|MST (Kruskal's)|O(E log E)|O(E log E)|O(E log E)|O(V)|Sort edges + Union-Find|
|Huffman Coding|O(n log n)|O(n log n)|O(n log n)|O(n)|Priority queue insertions|
|Gas Station (greedy)|O(n)|O(n)|O(n)|O(1)|Single linear pass, no sort|

**Derivation for the non-obvious entries:** Gas station is O(n) because no sorting is needed — the greedy check (total gas ≥ total cost AND a scan for the starting point) is a single pass. The start index is found by tracking the accumulated deficit and resetting on failure.

### Comparison with Alternatives

|Approach|Time|Space|Best When|
|---|---|---|---|
|Greedy|O(n log n)|O(1)|Greedy choice property AND optimal substructure both hold|
|Dynamic Programming|O(n × W) or O(n²)|O(n × W) or O(n²)|Only optimal substructure holds; choices interact|
|Backtracking|O(2ⁿ) or O(n!)|O(n)|Neither property holds; exhaustive search required|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class GreedyBenchmark
{
    private int[][] _intervals = null!;

    [Params(1_000, 10_000, 100_000)]
    public int N { get; set; }

    [GlobalSetup]
    public void Setup()
    {
        var rng = new Random(42);
        _intervals = new int[N][];
        for (int i = 0; i < N; i++)
        {
            int start = rng.Next(0, 1_000_000);
            int end = start + rng.Next(1, 1000);
            _intervals[i] = [start, end];
        }
    }

    [Benchmark(Baseline = true)]
    public int BruteForce_ActivitySelection()
    {
        // O(n²) DP for comparison — LIS-like approach
        var sorted = _intervals.OrderBy(x => x[0]).ThenBy(x => x[1]).ToArray();
        int n = sorted.Length;
        int[] dp = new int[n];
        int max = 0;

        for (int i = 0; i < n; i++)
        {
            dp[i] = 1;
            for (int j = 0; j < i; j++)
            {
                if (sorted[j][1] <= sorted[i][0])
                    dp[i] = Math.Max(dp[i], dp[j] + 1);
            }
            max = Math.Max(max, dp[i]);
        }
        return max;
    }

    [Benchmark]
    public int Greedy_ActivitySelection()
    {
        var sorted = _intervals.OrderBy(x => x[1]).ToArray();
        int count = 0, lastEnd = -1;

        foreach (var interval in sorted)
        {
            if (interval[0] >= lastEnd)
            {
                count++;
                lastEnd = interval[1];
            }
        }
        return count;
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|BruteForce|1,000|~2 ms|150 KB|
|Greedy|1,000|~50 μs|50 KB|
|BruteForce|10,000|~200 ms|12 MB|
|Greedy|10,000|~600 μs|500 KB|
|BruteForce|100,000|~20 s|1.2 GB|
|Greedy|100,000|~7 ms|5 MB|

**Interpretation:** The greedy O(n log n) approach is orders of magnitude faster than the O(n²) DP for large n. At N = 100,000, the DP degrades to ~20 seconds while the greedy solves in milliseconds. The sorting is the dominant cost in the greedy approach; the linear pass is negligible.

---

## Interview Arsenal

### Question Bank

1. What are the two properties a problem must have for a greedy algorithm to be correct?
2. Explain the exchange argument proof for the greedy choice property.
3. Prove (or disprove) that the greedy algorithm for Coin Change is optimal for US denominations [1, 5, 10, 25].
4. Given an optimization problem, how do you decide whether to use greedy or DP?
5. The activity selection problem is solvable by greedy. The weighted interval scheduling problem is not. Why?
6. What happens when the optimal substructure property holds but the greedy choice property does not?
7. How does Prim's algorithm for MST demonstrate the greedy choice property?
8. Design a greedy algorithm for the "minimum number of platforms required for a train schedule" problem.
9. In a production system, when would you prefer a greedy algorithm over an exact DP solution?

### Spoken Answers

**Q: What are the two properties a problem must have for a greedy algorithm to be correct?**

> **Average answer:** The greedy choice property and optimal substructure.

> **Great answer:** The two properties are the greedy choice property and optimal substructure. The greedy choice property means that the first locally optimal choice is always part of some globally optimal solution — you never need to reconsider it. I prove this with an exchange argument: take any optimal solution, show it can be modified to include the greedy first choice without worsening the result, then argue by induction that the same applies at every step. Optimal substructure means that after making the greedy choice, the remaining problem is an independent, smaller instance of the same type — the same algorithm can be applied recursively. If both properties hold, the greedy algorithm produces an optimal solution in O(n log n) or better. If only optimal substructure holds (as in weighted interval scheduling or 0/1 knapsack), DP is needed. If neither holds, you need backtracking or approximation.

**Q: Prove the greedy choice property for activity selection.**

> **Average answer:** Sort by finish time, always pick the earliest finishing activity. The proof is that swapping the first chosen activity with the earliest finishing one doesn't increase the total count.

> **Great answer:** Let me walk through the exchange argument formally. Let S = {a₁, a₂, ..., aₖ} be an optimal solution sorted by finish time. Let g be the activity with the globally earliest finish time. I claim there exists an optimal solution containing g. Since g has the earliest finish time of all activities, its finish time f(g) ≤ f(a₁). Now construct S' by replacing a₁ with g. Is S' feasible? We know a₁ starts at or after f(a₁) ≥ f(g), so g finishes at or before a₁ starts. The next activity a₂ starts at or after f(a₁) ≥ f(g), so g does not overlap with a₂ either. All other activities remain unchanged. So S' is feasible and has the same cardinality k. Therefore S' is also optimal and contains g. By induction, the greedy choice at each step maintains optimality — after selecting g, the remaining problem is exactly the same problem on activities that start after f(g), and the same exchange argument applies.

**Q: How do you decide between greedy and DP for an optimization problem?**

> **Average answer:** Greedy is faster, DP is slower but always correct. Use DP if greedy fails.

> **Great answer:** I make the decision by testing the two properties. First, I check for optimal substructure: does the problem decompose into independent subproblems? If not, it is not an optimization problem solvable by either greedy or DP. If yes, I then check the greedy choice property: is the first local decision always safe? I try to construct a counterexample — if I find one where the greedy choice leads to a suboptimal result (like coin change with [1,3,4], amount 6 picking 4 first), then greedy fails and I use DP. If I cannot construct such a counterexample and the problem follows a known greedy pattern (interval scheduling, fractional knapsack, MST), I code greedy. The key is that I always attempt the greedy proof in my head before writing code — if I cannot convince myself of the exchange argument, I default to DP. In an interview, I verbalize this: "I think this might be greedy, but let me verify by checking a counterexample."

### Trick Question

**"A greedy algorithm always produces the optimal solution if at each step you choose the maximum or minimum of something."**

Why it is a trap: This confuses the shape of the decision (take the max/min) with the correctness condition. Many problems have a "take the max/min" intuition but fail the greedy choice property — for example, the coin change problem with US denominations actually IS optimal for most amounts but fails for non-standard denominations; the 0/1 knapsack fails even though taking the highest value/weight ratio seems intuitively correct.

Correct answer: The correct greedy criterion depends on the specific problem. The proof must show that the first greedy choice is always part of some optimal solution — this is not guaranteed by simply "taking the maximum." The exchange argument must hold. Without it, the greedy algorithm may produce a suboptimal result regardless of whether the choice is maximum, minimum, or something else.

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|Intervals with equal weight; maximize count|Activity Selection (greedy by end time)|Earliest-finishing leaves most room for others|
|Items divisible; maximize value per weight|Fractional Knapsack (greedy by ratio)|Can always take more of the best ratio|
|Graph connectivity with edge costs|MST (Kruskal's/Prim's)|Minimum cost edges are always safe if no cycle formed|
|Frequency distribution; minimize encoding length|Huffman Coding|Merge least frequent — exchange argument proves deepest level|
|Single-pass feasibility with cumulative sums|Gas Station / Jump Game|Total sum determines feasibility; local deficit resets candidate start|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Optimization problem] --> B{Does it have<br>optimal substructure?}
    B -->|No| C[Not greedy or DP<br>— use backtracking]
    B -->|Yes| D{Does it have<br>greedy choice property?}
    D -->|Yes| E[Greedy algorithm<br>O(n log n) or O(n)]
    D -->|I need to check| F[Try to construct<br>a counterexample]
    F -->|Counterexample found| G[Use dynamic programming]
    F -->|No counterexample found| H[Attempt exchange argument]
    H -->|Proof works| E
    H -->|Proof fails| G
```

### Recognition Checklist

Indicators that greedy is the right choice:

- [ ] The problem asks for a minimum or maximum of something (count, weight, cost)
- [ ] You can construct a counterexample where making a seemingly good local choice fails — if you cannot, greedy might apply
- [ ] The problem would be significantly harder without sorting the input
- [ ] The problem is well-known to be greedy (interval scheduling, MST, Huffman)
- [ ] The problem says "you may assume a greedy algorithm exists" or tests basic greedy intuition

Counter-indicators — do NOT apply here:

- [ ] Each item has a weight/value and the goal is to maximize value with weight limit (0/1 knapsack — use DP)
- [ ] Intervals have weights (weighted interval scheduling — use DP)
- [ ] The problem has overlapping subproblems that interact (use DP)
- [ ] The problem explicitly says "revisit" or "reconsider" choices

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|O(n log n) or O(n) time — fastest of all optimization techniques|May produce wrong answer if greedy choice property is not proven|
|O(1) extra space — no DP table or recursion stack|Only works on a narrow class of problems with both properties|
|Simple, linear control flow — easy to write and debug|Cannot handle weighted variants or interacting subproblems|

---

## Self-Check

### Conceptual Questions

1. What are the two properties required for a greedy algorithm to be correct?
2. Walk through the exchange argument that proves the greedy choice property for interval scheduling.
3. Why does the coin change problem with denominations [1, 3, 4] fail the greedy choice property?
4. The fractional knapsack has the greedy choice property. The 0/1 knapsack does not. Why?
5. What distinguishes optimal substructure from the greedy choice property?
6. In .NET, how would you implement the sorting step of a greedy algorithm with minimal allocations?
7. What invariant does Kruskal's algorithm maintain during its greedy edge selection?
8. How does the gas station problem prove its greedy solution is correct without sorting?
9. In a system that processes live event streams, would you use a greedy algorithm or DP for real-time scheduling decisions? Why?
10. Explain the apparent contradiction: the greedy algorithm for interval scheduling is optimal, but adding weights (weighted interval scheduling) makes greedy fail — what changed?

<details>
<summary>Answers</summary>

1. The greedy choice property (locally optimal choice is always part of some globally optimal solution) and optimal substructure (the remaining problem after a greedy choice is an independent instance of the same type).
2. Let S = {a₁, a₂, ..., aₖ} be optimal, sorted by finish time. Let g have the globally earliest finish time f(g) ≤ f(a₁). Replace a₁ with g: g finishes by f(g) ≤ f(a₁) ≤ start of a₂, so g does not overlap with a₂. S' = {g, a₂, ..., aₖ} is feasible and same size — thus optimal and contains g.
3. For amount 6, greedy picks 4 first (largest ≤ 6). But the optimal solution is 3+3 (2 coins). The greedy choice 4 is not part of any optimal solution, violating the greedy choice property.
4. In fractional knapsack, you can take a fraction of the best ratio item, so the greedy choice is always optimal — you just reduce the capacity proportionally. In 0/1 knapsack, taking the best ratio item may block two slightly worse items that together give higher total value (e.g., best ratio uses weight W, but two other items together fit in W with more value).
5. Optimal substructure is about decomposition — can the remaining problem be solved independently? Greedy choice property is about the first step — is the locally optimal first choice globally safe? A problem can have one without the other (e.g., 0/1 knapsack has optimal substructure but no greedy choice property).
6. Use `Array.Sort` with a custom `Comparison<T>` to sort in-place, avoiding LINQ allocations: `Array.Sort(input, (a, b) => a.SomeKey.CompareTo(b.SomeKey))`.
7. Kruskal's maintains the invariant that the selected edges form a forest (no cycles). Each new edge is safe if its endpoints are in different trees — Union-Find tracks this.
8. The gas station greedy doesn't need sorting because the problem has a known invariant: if total gas ≥ total cost, there exists a unique valid starting station. The greedy scan tracks accumulated deficit; when it drops below 0, the current start is invalid, and the next candidate is the next station. This is O(n) because each station is visited at most twice.
9. Greedy is preferred for real-time scheduling because it makes decisions in O(n) with no backtracking. DP would require multiple passes and state storage — not suitable for live streams with tight latency bounds.
10. Adding weights changes the objective from "maximize count" to "maximize total weight." The exchange argument fails because replacing a high-weight interval with the earliest-finishing (but possibly low-weight) interval reduces total weight. The objective is no longer aligned with "finish early."

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement the activity selection greedy algorithm without using LINQ — sort in-place using `Array.Sort` and a custom comparer.

```csharp
public int MaxActivities(int[][] intervals)
{
    // Your implementation here
}
```

<details> <summary>Solution</summary>

```csharp
public int MaxActivities(int[][] intervals)
{
    if (intervals.Length == 0) return 0;

    Array.Sort(intervals, (a, b) => a[1].CompareTo(b[1]));

    int count = 1;
    int lastEnd = intervals[0][1];

    for (int i = 1; i < intervals.Length; i++)
    {
        if (intervals[i][0] >= lastEnd)
        {
            count++;
            lastEnd = intervals[i][1];
        }
    }

    return count;
}
```

**Complexity:** Time O(n log n) | Space O(1) **Key insight:** Sorting by end time maximizes remaining capacity. The greedy selects the earliest-finishing non-conflicting interval at each step.

</details>

---

**Challenge 2 — Trace the execution**

Given intervals [(1,4),(3,5),(0,6),(5,7),(3,9),(5,9),(6,10),(8,11),(8,12),(2,14),(12,16)], trace the greedy activity selection algorithm. Show the sorted order and each decision.

<details> <summary>Solution</summary>

Sorted by end time:
(1,4),(3,5),(0,6),(5,7),(3,9),(5,9),(6,10),(8,11),(8,12),(12,16),(2,14)

```
lastEnd = -∞
(1,4): start=1 ≥ lastEnd → select, lastEnd=4
(3,5): start=3 < 4 → skip
(0,6): start=0 < 4 → skip
(5,7): start=5 ≥ 4 → select, lastEnd=7
(3,9): start=3 < 7 → skip
(5,9): start=5 < 7 → skip
(6,10): start=6 < 7 → skip
(8,11): start=8 ≥ 7 → select, lastEnd=11
(8,12): start=8 < 11 → skip
(12,16): start=12 ≥ 11 → select, lastEnd=16
(2,14): start=2 < 16 → skip

Result: 4 activities — (1,4), (5,7), (8,11), (12,16)
```

**Why:** Each greedy choice maximizes remaining room, and the exchange argument proves this produces the maximum possible count.

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This greedy algorithm for the coin change problem with US denominations
// [1, 5, 10, 25] has a subtle bug for certain edge-case amounts.
public int CoinChangeGreedy(int amount)
{
    int[] coins = [25, 10, 5, 1];
    int count = 0;
    foreach (int coin in coins)
    {
        count += amount / coin;
        amount %= coin;
    }
    return count;
}
```

<details> <summary>Solution</summary>

**Bug:** The algorithm is actually correct for US denominations — no bug in terms of correctness. However, the bug is that the function assumes greedy is always optimal for these denominations (it is), but if the problem were to use [1, 3, 4], the same greedy would fail. The real bug is applying greedy without verifying the greedy choice property.

For the US denominations case: the code is correct. For a trickier case, suppose the input denominations vary at runtime:

```csharp
// ✅ Correct — dynamic programming for arbitrary denominations
public int CoinChangeDP(int[] coins, int amount)
{
    int[] dp = new int[amount + 1];
    Array.Fill(dp, amount + 1);
    dp[0] = 0;

    for (int i = 1; i <= amount; i++)
    {
        foreach (int c in coins)
        {
            if (c <= i)
                dp[i] = Math.Min(dp[i], dp[i - c] + 1);
        }
    }

    return dp[amount] > amount ? -1 : dp[amount];
}
```

**Test case that exposes the greedy assumption:** Coins = [1, 3, 4], amount = 6 → greedy returns 3 (4+1+1), DP returns 2 (3+3).

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** You have n children with greed factors g[i] and m cookies with sizes s[j]. Each child needs a cookie at least as large as their greed factor. Each child gets at most one cookie. Maximize the number of content children. Which pattern applies? Write the solution.

<details> <summary>Solution</summary>

**Pattern:** Greedy assignment — sort both arrays, assign the smallest cookie that satisfies each child's greed. This is a classic matching greedy that allocates scarce resources.

```csharp
public int FindContentChildren(int[] g, int[] s)
{
    Array.Sort(g);
    Array.Sort(s);

    int child = 0, cookie = 0;

    while (child < g.Length && cookie < s.Length)
    {
        if (s[cookie] >= g[child])
            child++;   // This child is content
        cookie++;      // This cookie is used (either assigned or too small)
    }

    return child;
}
```

**Complexity:** Time O(n log n + m log m) | Space O(1) **Key insight:** Sorting ensures we never waste a large cookie on a small greed — matching the smallest feasible cookie to each child leaves larger cookies for greedier children.

</details>

---

**Challenge 5 — Optimize**

```csharp
// This correct greedy for activity selection creates an allocation in the sort step.
// Optimize it to use zero extra memory via in-place sorting.
public int ActivitySelection(int[][] intervals)
{
    var sorted = intervals.OrderBy(x => x[1]).ToArray();  // Allocates!
    int count = 0, end = -1;
    foreach (var iv in sorted)
    {
        if (iv[0] >= end) { count++; end = iv[1]; }
    }
    return count;
}
```

<details> <summary>Solution</summary>

**Insight:** Use `Array.Sort` with a custom comparer to sort in-place — O(n log n) time, O(1) extra space.

```csharp
// ✅ Correct — in-place sort, zero extra memory
public int ActivitySelection(int[][] intervals)
{
    Array.Sort(intervals, (a, b) => a[1].CompareTo(b[1]));

    int count = 0, end = -1;
    foreach (var iv in intervals)
    {
        if (iv[0] >= end)
        {
            count++;
            end = iv[1];
        }
    }
    return count;
}
```

**Complexity:** Time O(n log n) | Space O(1) — same time, but eliminates the O(n) allocation for the sorted copy.

</details>
