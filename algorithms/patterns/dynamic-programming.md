# Dynamic Programming

> A technique for solving problems with overlapping subproblems by storing and reusing previously computed results instead of recomputing them.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Recursion + memoization / bottom-up table filling |
| **Use when** | Overlapping subproblems + optimal substructure |
| **Avoid when** | Subproblems are independent (use divide-and-conquer instead) |
| **C# version** | C# 1.0+ (arrays/dictionaries for tables); records help in C# 9+ |
| **Namespace** | None — pure algorithmic pattern |
| **Key types** | `int[]`, `int[,]`, `Dictionary<(int,int), int>` for memo |

---

## When To Use It

Use DP when a problem has two properties: **optimal substructure** (the optimal solution contains optimal solutions to subproblems) and **overlapping subproblems** (the same subproblems recur multiple times). The signal is a recursive solution whose call tree has repeated nodes — draw the recursion tree and look for duplicate subtrees. If subproblems are independent, use divide-and-conquer instead. Classic domains: shortest/longest paths, counting ways, string matching, knapsack-style allocation.

Don't use DP when you need to enumerate all solutions (use backtracking). DP counts or optimises; backtracking lists.

---

## Core Concept

DP is just recursion with memory. The naive recursive solution recomputes the same subproblems exponentially. Memoization (top-down DP) caches the result of each subproblem the first time it's computed. Tabulation (bottom-up DP) fills a table iteratively from base cases upward, eliminating recursion entirely.

The hardest part of DP is defining the state: what information do you need to fully describe a subproblem? Once the state is clear, the recurrence (how to combine smaller states into larger ones) usually follows. The rest is implementation.

**DP thinking process:**
1. Define what `dp[i]` (or `dp[i][j]`) means — in plain English, one sentence.
2. Write the recurrence: `dp[i] = f(dp[i-1], dp[i-2], ...)`.
3. Identify base cases.
4. Determine traversal order (which smaller states must be computed before larger ones).
5. Optimize space if the recurrence only looks back a fixed number of states.

---

## Algorithm History

| Year | Development |
|---|---|
| 1953 | Richard Bellman coins "dynamic programming" — the name was chosen to sound impressive to funders, not for technical meaning |
| 1957 | Bellman publishes the optimality principle (optimal substructure) |
| 1960s | Applied to operations research, economics, control theory |
| 1970s | String algorithms: LCS, edit distance formalized as DP |
| 1990s | Becomes a core competitive programming and interview topic |
| 2010s | Bitmask DP, interval DP, and digit DP codified as sub-patterns |

*Bellman explicitly said the name "dynamic programming" was marketing — the word "dynamic" conveyed process-over-time, and "programming" meant planning (not coding). He wanted to hide that it was mathematical research from a DOD sponsor who disliked mathematics.*

---

## Performance

| Problem | Time | Space | Optimized Space |
|---|---|---|---|
| Fibonacci | O(n) | O(n) table | O(1) — keep last two values |
| Coin change | O(n × k) | O(n) | O(n) — no improvement |
| 0/1 Knapsack | O(n × W) | O(n × W) | O(W) — roll previous row |
| LCS / Edit distance | O(m × n) | O(m × n) | O(min(m,n)) — roll row |
| LIS (DP) | O(n²) | O(n) | — |
| LIS (patience sort) | O(n log n) | O(n) | — |

**Allocation behaviour:** Top-down memoization allocates a dictionary on the heap — O(n) or O(m×n) entries. Bottom-up tabulation allocates an array upfront and fills it in-place. Space-optimised bottom-up (rolling array) reduces 2D DP to O(n) but requires careful index management.

**Benchmark notes:** Top-down memoization has higher constant factors due to dictionary lookups and function call overhead. Bottom-up tabulation has better cache performance (sequential array access). For n < 1,000 the difference is negligible; at n > 100,000 bottom-up is consistently 2–5× faster.

---

## The Code

**Scenario 1 — Fibonacci: memoization → tabulation → space-optimised**
```csharp
// Top-down: memoization
private Dictionary<int, long> _memo = new();
public long FibMemo(int n)
{
    if (n <= 1) return n;
    if (_memo.TryGetValue(n, out long cached)) return cached;
    return _memo[n] = FibMemo(n - 1) + FibMemo(n - 2);
}

// Bottom-up: tabulation
public long FibTab(int n)
{
    if (n <= 1) return n;
    var dp = new long[n + 1];
    dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i - 1] + dp[i - 2];
    return dp[n];
}

// Space-optimised: O(1)
public long FibOpt(int n)
{
    if (n <= 1) return n;
    long a = 0, b = 1;
    for (int i = 2; i <= n; i++)
        (a, b) = (b, a + b);
    return b;
}
```

**Scenario 2 — coin change (minimum coins)**
```csharp
public int CoinChange(int[] coins, int amount)
{
    // dp[i] = minimum coins to make amount i
    var dp = new int[amount + 1];
    Array.Fill(dp, amount + 1); // "infinity" — more than any valid answer
    dp[0] = 0;

    for (int i = 1; i <= amount; i++)
        foreach (int coin in coins)
            if (coin <= i && dp[i - coin] + 1 < dp[i])
                dp[i] = dp[i - coin] + 1;

    return dp[amount] > amount ? -1 : dp[amount];
}
```

**Scenario 3 — 2D DP: longest common subsequence**
```csharp
public int LCS(string s1, string s2)
{
    int m = s1.Length, n = s2.Length;
    // dp[i,j] = LCS of s1[0..i) and s2[0..j)
    var dp = new int[m + 1, n + 1];
    for (int i = 1; i <= m; i++)
        for (int j = 1; j <= n; j++)
            dp[i, j] = s1[i - 1] == s2[j - 1]
                ? dp[i - 1, j - 1] + 1
                : Math.Max(dp[i - 1, j], dp[i, j - 1]);
    return dp[m, n];
}
```

**Scenario 4 — what NOT to do: naive recursion with overlapping subproblems**
```csharp
// BAD: O(2^n) — recomputes the same subproblems exponentially
public int CoinChangeBad(int[] coins, int amount)
{
    if (amount == 0) return 0;
    if (amount < 0) return -1;
    int best = int.MaxValue;
    foreach (int coin in coins)
    {
        int sub = CoinChangeBad(coins, amount - coin); // recomputed every call
        if (sub >= 0 && sub + 1 < best)
            best = sub + 1;
    }
    return best == int.MaxValue ? -1 : best;
}

// GOOD: O(n × k) — each subproblem computed exactly once
public int CoinChangeGood(int[] coins, int amount)
{
    var dp = new int[amount + 1];
    Array.Fill(dp, amount + 1);
    dp[0] = 0;
    for (int i = 1; i <= amount; i++)
        foreach (int coin in coins)
            if (coin <= i)
                dp[i] = Math.Min(dp[i], dp[i - coin] + 1);
    return dp[amount] > amount ? -1 : dp[amount];
}
```

---

## Real World Example

The `ShippingCalculatorService` at a logistics company determines the minimum number of boxes needed to pack an order, given a set of available box sizes and a total volume. This is a variant of coin change — minimise number of boxes (coins) to reach total volume (amount). Orders were previously calculated with a greedy algorithm that failed on certain size combinations, causing mis-packs.

```csharp
public class ShippingCalculatorService
{
    private readonly int[] _boxVolumes; // e.g. [1, 5, 11, 25] litres

    public ShippingCalculatorService(int[] availableBoxVolumes)
    {
        _boxVolumes = availableBoxVolumes;
        Array.Sort(_boxVolumes); // ascending for early-termination
    }

    // Returns the minimum number of boxes to pack exactly totalVolume litres.
    // Returns -1 if impossible with available box sizes.
    public int MinBoxes(int totalVolume)
    {
        var dp = new int[totalVolume + 1];
        Array.Fill(dp, totalVolume + 1); // sentinel: more boxes than possible
        dp[0] = 0;

        for (int v = 1; v <= totalVolume; v++)
        {
            foreach (int boxVol in _boxVolumes)
            {
                if (boxVol > v) break; // sorted — no smaller box can help
                if (dp[v - boxVol] + 1 < dp[v])
                    dp[v] = dp[v - boxVol] + 1;
            }
        }

        return dp[totalVolume] > totalVolume ? -1 : dp[totalVolume];
    }

    // Returns the actual box selection, not just the count.
    public List<int> BoxSelection(int totalVolume)
    {
        var dp = new int[totalVolume + 1];
        var from = new int[totalVolume + 1]; // which box size we used to reach v
        Array.Fill(dp, totalVolume + 1);
        Array.Fill(from, -1);
        dp[0] = 0;

        for (int v = 1; v <= totalVolume; v++)
        {
            foreach (int boxVol in _boxVolumes)
            {
                if (boxVol > v) break;
                if (dp[v - boxVol] + 1 < dp[v])
                {
                    dp[v] = dp[v - boxVol] + 1;
                    from[v] = boxVol; // remember which box we picked
                }
            }
        }

        if (dp[totalVolume] > totalVolume) return new List<int>(); // impossible

        // Reconstruct the selection by backtracking through `from`
        var result = new List<int>();
        int remaining = totalVolume;
        while (remaining > 0)
        {
            result.Add(from[remaining]);
            remaining -= from[remaining];
        }
        return result;
    }
}
```

*The key insight: `from[v]` stores which box size was used to achieve the minimum at volume `v`, enabling path reconstruction without storing the full DP table. This is the standard "reconstruct the solution, not just the value" DP pattern.*

---

## Common Misconceptions

**"Memoization is always faster than tabulation"**
Not true. Memoization has function-call overhead per subproblem and dictionary lookup cost. Tabulation fills an array sequentially — much better cache behaviour. For large n, bottom-up tabulation is consistently 2–5× faster. Use memoization when the state space is sparse (many subproblems are never reached) or when the recurrence is complex to express iteratively.

**"DP and greedy both use optimal substructure — they're interchangeable"**
Greedy makes one irrevocable locally-optimal choice per step. DP explores all choices and picks the globally optimal one by combining subproblem results. Problems with optimal substructure might be solvable by greedy (if the greedy choice property also holds) or might require DP. Coin change with denominations {1, 5, 11, 25} fails greedy but is solved correctly by DP — try amount=15 with {1, 5, 11} to see greedy give 5 coins vs DP's 3.

**"Space-optimised DP means I only keep the previous row"**
Only valid when `dp[i]` depends exclusively on `dp[i-1]` (and maybe `dp[i-2]`). For 2D DP, rolling to the previous row works when `dp[i][j]` depends only on `dp[i-1][j]` and `dp[i][j-1]`. If it depends on `dp[i-2][j]` or arbitrary earlier rows, you can't roll — keep the full table.

---

## Gotchas

- **Defining the state wrong breaks everything.** If `dp[i]` is ambiguous or doesn't carry enough information, the recurrence can't be written correctly. Spend 2 minutes on the state definition before writing any code. Write it in one English sentence: "dp[i] = the minimum number of coins to make amount i."

- **Traversal order must match dependency order.** `dp[i]` depends on `dp[i-1]` — fill left to right. `dp[i][j]` depends on `dp[i-1][j-1]` — fill top-to-bottom, left-to-right. Getting this wrong means you read values that haven't been computed yet, and the bug is silent.

- **Initialise with the correct sentinel value.** For minimization problems, initialise unreachable states with `int.MaxValue` or `amount + 1` — never 0 (that looks like "reachable with 0 cost"). For maximization, initialise with `int.MinValue` or -1. Sentinel choice is where most DP bugs originate.

- **`int.MaxValue + 1` overflows silently.** When using `int.MaxValue` as a sentinel and then doing `dp[i - coin] + 1`, you get a negative number. Use `amount + 1` or check `dp[i - coin] != int.MaxValue` before adding.

- **Memoization with recursion still uses O(n) stack space.** A deeply recursive memoized solution can still overflow the stack for large n. For `n > 10,000`, convert to bottom-up tabulation to eliminate stack depth entirely.

---

## Interview Angle

**What they're really testing:** Whether you can identify overlapping subproblems, define a clean state, write the recurrence, and implement it without bugs — under pressure.

**Common question forms:**
- "Climbing stairs / minimum cost climbing stairs."
- "Coin change — minimum coins / number of ways."
- "Longest increasing subsequence."
- "Edit distance / word break / decode ways."
- "House robber / partition equal subset sum."

**The depth signal:** A junior writes the recursive solution. A senior adds memoization, then converts to tabulation, then identifies space optimization. The real signal: a senior defines `dp[i]` in plain English before writing a line of code, derives the recurrence from the definition, and can articulate why the traversal order is correct. They also know when to reach for O(n log n) LIS (patience sorting) instead of the O(n²) DP solution.

**Follow-up questions to expect:**
- "Can you do this with O(1) space?" → Depends on whether the recurrence only looks back a fixed number of states.
- "When would you use backtracking instead of DP?" → When you need to enumerate all solutions, not just count or optimise.

---

## Related Topics

- [[algorithms/patterns/divide-and-conquer.md]] — D&C has independent subproblems; DP has overlapping ones. The distinction is foundational.
- [[algorithms/patterns/greedy-algorithms.md]] — Greedy works when the locally-optimal choice is globally safe; DP is the fallback when it isn't.
- [[algorithms/patterns/backtracking.md]] — Backtracking lists all solutions; DP counts or optimises. "Count ways" → DP, "list all ways" → backtracking.
- [[algorithms/problem-solving-frameworks/recursion-to-iteration.md]] — Converting top-down memoization to bottom-up tabulation is a core DP skill.

---

## Source

https://en.wikipedia.org/wiki/Dynamic_programming

---

*Last updated: 2026-04-21*