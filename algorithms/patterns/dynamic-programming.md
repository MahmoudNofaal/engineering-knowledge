# Dynamic Programming
> A technique for solving problems with overlapping subproblems by storing and reusing previously computed results instead of recomputing them.

---

## When To Use It
Use DP when a problem has two properties: **optimal substructure** (the optimal solution contains optimal solutions to subproblems) and **overlapping subproblems** (the same subproblems are solved multiple times). The signal is a recursive solution whose call tree has repeated nodes. If subproblems are independent, use divide and conquer instead. Classic domains: shortest/longest paths, counting ways, string matching, knapsack-style allocation.

---

## Core Concept
DP is just recursion with memory. The naive recursive solution recomputes the same subproblems exponentially. Memoization (top-down DP) caches the result of each subproblem the first time it's computed. Tabulation (bottom-up DP) fills a table iteratively from base cases upward, eliminating recursion entirely.

The hardest part of DP is defining the state: what information do you need to fully describe a subproblem? Once the state is clear, the recurrence (how to combine smaller states into larger ones) usually follows. The rest is implementation.

DP thinking process:
1. Define what dp[i] (or dp[i][j]) represents — in plain English.
2. Write the recurrence: dp[i] = f(dp[i-1], dp[i-2], ...).
3. Identify base cases.
4. Decide traversal order (which smaller states must be ready before larger ones).
5. Optimize space if the recurrence only looks back a fixed number of states.

---

## The Code

**Fibonacci — memoization vs tabulation**
```csharp
// Top-down: memoization
private Dictionary<int, long> memo = new Dictionary<int, long>();

public long FibMemo(int n)
{
    if (n <= 1)
        return n;
    if (memo.ContainsKey(n))
        return memo[n];
    memo[n] = FibMemo(n - 1) + FibMemo(n - 2);
    return memo[n];
}

// Bottom-up: tabulation
public long FibTab(int n)
{
    if (n <= 1)
        return n;
    var dp = new long[n + 1];
    dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i - 1] + dp[i - 2];
    return dp[n];
}

// Space-optimized: only need last two values
public long FibOpt(int n)
{
    if (n <= 1)
        return n;
    long a = 0, b = 1;
    for (int i = 2; i <= n; i++)
    {
        long temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}
```

**Longest increasing subsequence — O(n²) and O(n log n)**
```csharp
// O(n²) DP
public int LIS(int[] nums)
{
    // dp[i] = length of LIS ending at index i
    var dp = new int[nums.Length];
    for (int i = 0; i < nums.Length; i++)
        dp[i] = 1;
    for (int i = 1; i < nums.Length; i++)
    {
        for (int j = 0; j < i; j++)
        {
            if (nums[j] < nums[i])
                dp[i] = Math.Max(dp[i], dp[j] + 1);
        }
    }
    return dp.Max();
}

// O(n log n) with patience sorting
public int LISFast(int[] nums)
{
    var tails = new List<int>();  // tails[i] = smallest tail of any IS of length i+1
    foreach (int num in nums)
    {
        int pos = tails.BinarySearch(num);
        if (pos < 0) pos = ~pos;  // BinarySearch returns negative index if not found
        if (pos == tails.Count)
            tails.Add(num);
        else
            tails[pos] = num;  // replace to keep tails as small as possible
    }
    return tails.Count;
}
```

**0/1 Knapsack**
```csharp
public int Knapsack(int[] weights, int[] values, int capacity)
{
    int n = weights.Length;
    // dp[i,w] = max value using first i items with capacity w
    var dp = new int[n + 1, capacity + 1];
    for (int i = 1; i <= n; i++)
    {
        for (int w = 0; w <= capacity; w++)
        {
            dp[i, w] = dp[i - 1, w];  // don't take item i
            if (weights[i - 1] <= w)
                dp[i, w] = Math.Max(dp[i, w],
                                    dp[i - 1, w - weights[i - 1]] + values[i - 1]);  // take it
        }
    }
    return dp[n, capacity];
}
```

**Longest common subsequence**
```csharp
public int LCS(string s1, string s2)
{
    int m = s1.Length, n = s2.Length;
    // dp[i,j] = LCS length of s1[0..i) and s2[0..j)
    var dp = new int[m + 1, n + 1];
    for (int i = 1; i <= m; i++)
    {
        for (int j = 1; j <= n; j++)
        {
            if (s1[i - 1] == s2[j - 1])
                dp[i, j] = dp[i - 1, j - 1] + 1;
            else
                dp[i, j] = Math.Max(dp[i - 1, j], dp[i, j - 1]);
        }
    }
    return dp[m, n];
}
```

**Coin change — minimum coins**
```csharp
public int CoinChange(int[] coins, int amount)
{
    // dp[i] = minimum coins to make amount i
    var dp = new int[amount + 1];
    for (int i = 0; i <= amount; i++)
        dp[i] = int.MaxValue;
    dp[0] = 0;
    for (int i = 1; i <= amount; i++)
    {
        foreach (int coin in coins)
        {
            if (coin <= i && dp[i - coin] != int.MaxValue)
                dp[i] = Math.Min(dp[i], dp[i - coin] + 1);
        }
    }
    return dp[amount] != int.MaxValue ? dp[amount] : -1;
}
```

---

## Gotchas

- **Defining the state wrong breaks everything.** If dp[i] is ambiguous or doesn't carry enough information, the recurrence can't be written. Spend time on the state definition before writing any code.
- **Traversal order must match dependency order.** dp[i] depends on dp[i-1] — so fill left to right. dp[i][j] depends on dp[i-1][j-1] — fill top-to-bottom, left-to-right. Getting this wrong means you read uncomputed values.
- **Space optimization is only valid when you only look back a fixed number of states.** You can reduce a 1D DP from O(n) to O(1) only if dp[i] depends on dp[i-1] and dp[i-2] — not on dp[i-k] for arbitrary k. For 2D DP, you can often reduce from O(mn) to O(n) by keeping only the previous row.
- **`float('inf')` as the initial "impossible" value is the right idiom.** For minimization problems, initialize dp to inf and update downward. For maximization, initialize to -inf or 0 depending on the problem.
- **Memoization with `@lru_cache` hides stack depth.** A deeply recursive memoized solution still uses O(n) stack space. For large inputs, tabulation avoids stack overflow entirely.

---

## Interview Angle

**What they're really testing:** Whether you can identify overlapping subproblems, define a clean state, write the recurrence, and implement it without bugs — under pressure.

**Common question form:** Coin change, climbing stairs, longest increasing subsequence, edit distance, word break, unique paths, partition equal subset sum, house robber.

**The depth signal:** A junior writes the recursive solution. A senior adds memoization, then converts to tabulation, then identifies space optimization. The real signal: a senior defines dp[i] in plain English before writing a line of code, derives the recurrence from the definition, and can articulate why the traversal order is correct. They also know when to reach for O(n log n) LIS (patience sorting) instead of the O(n²) DP.

---

## Related Topics

- [[algorithms/divide-and-conquer.md]] — The distinction between D&C (independent subproblems) and DP (overlapping) is foundational.
- [[algorithms/recursion-to-iteration.md]] — Converting top-down memoization to bottom-up tabulation is a core DP skill.
- [[algorithms/common-patterns-map.md]] — DP appears across multiple problem categories; this map shows where.

---

## Source

https://en.wikipedia.org/wiki/Dynamic_programming

---

*Last updated: 2026-03-24*