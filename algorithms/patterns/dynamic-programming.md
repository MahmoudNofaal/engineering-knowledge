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
```python
# Top-down: memoization
from functools import lru_cache

@lru_cache(maxsize=None)
def fib_memo(n: int) -> int:
    if n <= 1:
        return n
    return fib_memo(n - 1) + fib_memo(n - 2)

# Bottom-up: tabulation
def fib_tab(n: int) -> int:
    if n <= 1:
        return n
    dp = [0] * (n + 1)
    dp[1] = 1
    for i in range(2, n + 1):
        dp[i] = dp[i-1] + dp[i-2]
    return dp[n]

# Space-optimized: only need last two values
def fib_opt(n: int) -> int:
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b
```

**Longest increasing subsequence — O(n²) and O(n log n)**
```python
# O(n²) DP
def lis(nums: list) -> int:
    # dp[i] = length of LIS ending at index i
    dp = [1] * len(nums)
    for i in range(1, len(nums)):
        for j in range(i):
            if nums[j] < nums[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)

# O(n log n) with patience sorting
import bisect

def lis_fast(nums: list) -> int:
    tails = []    # tails[i] = smallest tail of any IS of length i+1
    for num in nums:
        pos = bisect.bisect_left(tails, num)
        if pos == len(tails):
            tails.append(num)
        else:
            tails[pos] = num    # replace to keep tails as small as possible
    return len(tails)
```

**0/1 Knapsack**
```python
def knapsack(weights: list, values: list, capacity: int) -> int:
    n = len(weights)
    # dp[i][w] = max value using first i items with capacity w
    dp = [[0] * (capacity + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        for w in range(capacity + 1):
            dp[i][w] = dp[i-1][w]              # don't take item i
            if weights[i-1] <= w:
                dp[i][w] = max(dp[i][w],
                               dp[i-1][w - weights[i-1]] + values[i-1])  # take it
    return dp[n][capacity]
```

**Longest common subsequence**
```python
def lcs(s1: str, s2: str) -> int:
    m, n = len(s1), len(s2)
    # dp[i][j] = LCS length of s1[:i] and s2[:j]
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if s1[i-1] == s2[j-1]:
                dp[i][j] = dp[i-1][j-1] + 1
            else:
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
    return dp[m][n]
```

**Coin change — minimum coins**
```python
def coin_change(coins: list, amount: int) -> int:
    # dp[i] = minimum coins to make amount i
    dp = [float('inf')] * (amount + 1)
    dp[0] = 0
    for i in range(1, amount + 1):
        for coin in coins:
            if coin <= i:
                dp[i] = min(dp[i], dp[i - coin] + 1)
    return dp[amount] if dp[amount] != float('inf') else -1
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