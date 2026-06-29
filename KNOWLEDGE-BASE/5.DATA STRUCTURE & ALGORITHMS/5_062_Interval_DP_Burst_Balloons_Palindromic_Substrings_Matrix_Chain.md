---
id: "5.062"
studied_well: false
title: "Interval DP — Burst Balloons, Palindromic Substrings, Matrix Chain"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Dynamic Programming"
tags: [dsa, algorithms, dynamic-programming, interval-dp, burst-balloons, matrix-chain, palindrome, csharp, interviews]
priority: 3
prerequisites:
  - "[[5.061 — 2D Dynamic Programming]]"
  - "[[5.059 — DP Fundamentals — Recognizing Problems, Memoization vs Tabulation]]"
related:
  - "[[5.002 — Recursion and the Call Stack]]"
  - "[[5.060 — 1D Dynamic Programming]]"
  - "[[5.024 — Binary Search Tree — Operations and Validation]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Dynamic Programming
**Previous:** [[5.061 — 2D Dynamic Programming]] | **Next:** [[5.063 — DP on Trees and Graphs]]

### Prerequisites
- [[5.061 — 2D Dynamic Programming]] — interval DP is a 2D DP on sub-intervals; the 2D DP pattern is the foundation.
- [[5.059 — DP Fundamentals — Recognizing Problems, Memoization vs Tabulation]] — recurrence derivation and memoization patterns are needed.

### Where This Fits
Interval DP solves problems where the optimal solution for a range [i, j] depends on optimal solutions for its sub-intervals divided at a split point k. The canonical problems are Matrix Chain Multiplication (optimal parenthesization), Burst Balloons (LeetCode 312, hard), and Palindromic Substrings (LeetCode 5, Longest Palindromic Substring). These appear in ~3% of hard DP interviews and test the ability to define DP[i][j] over intervals and choose the right split strategy.

### Key Insight

The recurrence follows the pattern: DP[i][j] = min/max over k in (i, j) of DP[i][k] + DP[k][j] + cost(i, j, k). The base case is DP[i][i] = 0 (single element) or DP[i][i+1] = some boundary value. The DP table is filled by interval length (len from 2 to n), not by row (i from 0 to n).

### Longest Palindromic Substring

```csharp
public string LongestPalindrome(string s)
{
    int n = s.Length;
    bool[,] dp = new bool[n, n];
    int start = 0, maxLen = 1;

    for (int i = 0; i < n; i++)
        dp[i, i] = true;

    for (int len = 2; len <= n; len++)
    {
        for (int i = 0; i <= n - len; i++)
        {
            int j = i + len - 1;
            if (s[i] == s[j] && (len == 2 || dp[i + 1, j - 1]))
            {
                dp[i, j] = true;
                if (len > maxLen) { maxLen = len; start = i; }
            }
        }
    }

    return s.Substring(start, maxLen);
}
```

### Burst Balloons

```csharp
public int MaxCoins(int[] nums)
{
    int n = nums.Length;
    int[] extended = new int[n + 2];
    extended[0] = extended[n + 1] = 1;
    Array.Copy(nums, 0, extended, 1, n);

    int[,] dp = new int[n + 2, n + 2];

    for (int len = 1; len <= n; len++)
    {
        for (int i = 1; i <= n - len + 1; i++)
        {
            int j = i + len - 1;
            for (int k = i; k <= j; k++)
            {
                int coins = extended[i - 1] * extended[k] * extended[j + 1]
                          + dp[i, k - 1] + dp[k + 1, j];
                dp[i, j] = Math.Max(dp[i, j], coins);
            }
        }
    }

    return dp[1, n];
}
```

### Gotchas

- **Filling order** — Always fill by interval length, not by start index. DP[i][j] depends on DP[i+1][j-1] (shorter intervals).
- **Boundary conditions** — For burst balloons, inserting 1 at both ends simplifies the boundary: no special-case multiplication.
- **Split point choice** — In Matrix Chain, k splits the interval [i, j] into [i, k] and [k, j] (k is the split between two matrices). In Burst Balloons, k is the last balloon to burst in [i, j].
- **Empty sub-intervals** — DP[i][i-1] = 0 for empty intervals. Ensure the recurrence handles this.
- **Integer overflow** — Balloon product for large arrays may overflow int32. Use long and cast at the end.

