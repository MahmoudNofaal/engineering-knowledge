# Common Complexities
> The seven growth classes that cover nearly every algorithm you'll encounter in practice, ordered from fastest to slowest.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Reference for the seven core complexity classes |
| **Use when** | Classifying an algorithm or choosing between approaches |
| **Avoid when** | Two solutions share a class — then benchmark, don't theorize |
| **Key hierarchy** | O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!) |
| **Practical cut-off** | O(n²) is typically the limit for n > 10,000 in real systems |
| **Rescue technique** | Memoization converts O(2ⁿ) recursion → O(n) or O(n²) |

---

## When To Use It

Use this as a decision framework when designing or reviewing algorithms. Knowing which complexity class your target solution falls into tells you whether your current approach has room to improve — or whether you've already hit the theoretical limit. This isn't a memorization exercise: understand *why* each class exists by identifying the structural property of the algorithm that produces it — halving the input, comparing all pairs, enumerating all subsets.

---

## Core Concept

Most algorithms you'll encounter fall into one of seven complexity classes forming a strict hierarchy: O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!). Moving up that hierarchy is expensive — an O(n²) solution that works at n=1,000 will fall apart at n=1,000,000. The practical skill is recognizing which class your code falls into by its structure: loops determine linear and quadratic behaviour; halving determines logarithmic; branching factor and recursion depth determine exponential; and permutation generation is the canonical factorial pattern.

The O(n log n) class has special significance: it's the provably optimal lower bound for comparison-based sorting. Any algorithm that sorts by comparing elements cannot beat this. Understanding why — the decision tree argument — is the kind of depth that separates a memorized answer from genuine understanding.

---

## Version History

| Class | Canonical Algorithm | Why It Exists |
|---|---|---|
| O(1) | Array index access | Fixed memory addressing — no input traversal |
| O(log n) | Binary search | Input halved each step → log₂(n) steps max |
| O(n) | Linear search | Must examine each element at least once |
| O(n log n) | Merge sort | O(log n) recursive levels × O(n) merge per level |
| O(n²) | Bubble sort | All pairs compared → n × (n-1)/2 comparisons |
| O(2ⁿ) | Fibonacci (naive) | Each call branches into 2 → tree doubles each level |
| O(n!) | Permutation gen | n choices for first element, n-1 for second, etc. |

*The O(n log n) lower bound for comparison-based sorting was proven by Ford and Johnson (1959) and formalized using decision tree arguments. It's one of the few tight lower bounds in algorithm theory.*

---

## Performance

| Class | n = 10 | n = 100 | n = 10,000 | n = 1,000,000 | Usable at scale? |
|---|---|---|---|---|---|
| O(1) | 1 | 1 | 1 | 1 | ✅ Always |
| O(log n) | 3 | 7 | 13 | 20 | ✅ Always |
| O(n) | 10 | 100 | 10,000 | 1,000,000 | ✅ Always |
| O(n log n) | 33 | 664 | 130,000 | ~20,000,000 | ✅ Yes |
| O(n²) | 100 | 10,000 | 10⁸ | 10¹² | ⚠️ n < ~10,000 |
| O(2ⁿ) | 1,024 | 10³⁰ | 10³⁰⁰⁰ | ☠️ | ❌ n < ~25 |
| O(n!) | 3.6M | 9.3×10¹⁵⁷ | ☠️ | ☠️ | ❌ n < ~12 |

**Allocation behaviour:** Complexity class describes operations, but space has its own classification. An O(n log n) sort can be O(1) space (in-place heapsort) or O(n) space (merge sort with auxiliary array). Always consider both dimensions separately.

**Benchmark notes:** The crossover point where better-Big-O wins varies by implementation. Insertion sort (O(n²)) beats merge sort (O(n log n)) for n < ~20 due to cache locality and zero allocation overhead. .NET's `Array.Sort` uses insertion sort for partitions smaller than 16 elements for exactly this reason. Never swap algorithms based on Big-O alone without benchmarking.

---

## The Code

**O(1) — Constant: cost independent of input size**
```csharp
public static int GetLast(List<int> items) => items[items.Count - 1];

// Dictionary lookup is O(1) amortized — hash computed in constant time
public static bool IsAdmin(Dictionary<string, Role> users, string userId)
    => users.TryGetValue(userId, out var role) && role == Role.Admin;
```

**O(log n) — Logarithmic: input is halved each step**
```csharp
// The signature: search space cuts in half every iteration → log₂(n) max iterations
public static int BinarySearch(List<int> sorted, int target)
{
    int lo = 0, hi = sorted.Count - 1;
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;  // avoids overflow vs (lo + hi) / 2
        if (sorted[mid] == target) return mid;
        if (sorted[mid] < target) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}
// n=1,000,000 → at most 20 iterations
```

**O(n) — Linear: must touch each element once**
```csharp
public static int LinearSearch(List<int> items, int target)
{
    for (int i = 0; i < items.Count; i++)
        if (items[i] == target) return i;
    return -1;
}

// All of these are O(n): LINQ .Where(), .Sum(), .Count(), .Any()
var total = orders.Sum(o => o.Amount);     // one pass over all orders
var hasLate = orders.Any(o => o.IsLate);   // O(n) worst case
```

**O(n log n) — Linearithmic: optimal for comparison-based sorting**
```csharp
// Built-in sort uses IntroSort (hybrid quicksort/heapsort/insertion sort)
var items = new List<int> { 3, 1, 4, 1, 5, 9, 2, 6 };
items.Sort();  // O(n log n) time, O(log n) space

// Manual merge sort to see why it's O(n log n)
// log n recursive levels × O(n) work to merge at each level = O(n log n)
public static List<int> MergeSort(List<int> items)
{
    if (items.Count <= 1) return items;
    int mid = items.Count / 2;
    var left = MergeSort(items.Take(mid).ToList());
    var right = MergeSort(items.Skip(mid).ToList());
    return Merge(left, right);  // O(n) merge step
}
```

**O(n²) — Quadratic: all pairs**
```csharp
// Every pair of elements is compared — nested loops are the signature pattern
public static void BubbleSort(List<int> items)
{
    int n = items.Count;
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n - i - 1; j++)
            if (items[j] > items[j + 1])
                (items[j], items[j + 1]) = (items[j + 1], items[j]);
}

// O(n²) even without explicit nesting — hidden inner loop
var result = new List<int>();
foreach (var item in items)
    if (!result.Contains(item))   // Contains is O(n) on List<T>
        result.Add(item);
// Fix: use HashSet<int> to make Contains O(1)
```

**O(2ⁿ) — Exponential: each call branches into two**
```csharp
// Naive Fibonacci — the classic O(2ⁿ) mistake
public static int FibNaive(int n)
{
    if (n <= 1) return n;
    return FibNaive(n - 1) + FibNaive(n - 2);  // two recursive calls each time
}
// FibNaive(50) never finishes in practice

// Fixed with memoization → O(n) time, O(n) space
public static int FibMemo(int n, Dictionary<int, int>? memo = null)
{
    memo ??= new Dictionary<int, int>();
    if (n <= 1) return n;
    if (memo.TryGetValue(n, out int cached)) return cached;
    memo[n] = FibMemo(n - 1, memo) + FibMemo(n - 2, memo);
    return memo[n];
}
// FibMemo(10000) runs instantly
```

**O(n!) — Factorial: generating all orderings**
```csharp
// Generating all permutations — n! grows faster than any polynomial or exponential
public static List<List<int>> AllPermutations(List<int> items)
{
    var result = new List<List<int>>();
    Permute(items, 0, result);
    return result;
}

private static void Permute(List<int> items, int start, List<List<int>> result)
{
    if (start == items.Count - 1)
    {
        result.Add(new List<int>(items));
        return;
    }
    for (int i = start; i < items.Count; i++)
    {
        (items[start], items[i]) = (items[i], items[start]);
        Permute(items, start + 1, result);
        (items[start], items[i]) = (items[i], items[start]);  // backtrack
    }
}
// n=10 → 3,628,800 permutations
// n=15 → 1,307,674,368,000 permutations — no chance in real time
```

---

## Real World Example

A feature flag evaluation engine initially checked if a user qualified for each feature by scanning through all user attributes for each flag. With 200 active flags and 50 user attributes, every request triggered 200 × 50 = 10,000 comparisons — O(flags × attributes), which is O(n²) if both grow. The fix was pre-building an attribute index at request startup and using direct lookups.

```csharp
// BAD: O(flags × attributes) — nested scanning
public class NaiveFlagEvaluator
{
    public Dictionary<string, bool> EvaluateAll(
        List<FeatureFlag> flags,
        List<UserAttribute> attributes)
    {
        var result = new Dictionary<string, bool>();

        foreach (var flag in flags)             // O(n)
        {
            bool qualified = true;
            foreach (var rule in flag.Rules)    // O(m) per flag
            {
                // attributes.FirstOrDefault is O(k) — third nested loop hidden here
                var attr = attributes.FirstOrDefault(a => a.Key == rule.Key);
                if (attr == null || !rule.Matches(attr.Value))
                {
                    qualified = false;
                    break;
                }
            }
            result[flag.Name] = qualified;
        }

        return result;
    }
}

// GOOD: O(attributes) to build index + O(flags × rules) for evaluation
// Since rules << attributes, this is effectively O(n + m) not O(n × m)
public class IndexedFlagEvaluator
{
    public Dictionary<string, bool> EvaluateAll(
        List<FeatureFlag> flags,
        List<UserAttribute> attributes)
    {
        // Build attribute index once — O(k)
        var attrIndex = attributes.ToDictionary(a => a.Key, a => a.Value);

        var result = new Dictionary<string, bool>();

        foreach (var flag in flags)
        {
            bool qualified = flag.Rules.All(rule =>
                attrIndex.TryGetValue(rule.Key, out var val) && rule.Matches(val));

            result[flag.Name] = qualified;
        }

        return result;
    }
}
```

*The key insight: any time you're searching a collection inside a loop, ask "can I build an index first?" Converting inner O(n) lookups to O(1) dictionary lookups is one of the highest-value optimizations in production systems.*

---

## Common Misconceptions

**"O(n log n) is close to O(n) so it's basically the same"**
At n=1,000,000, O(n) is one million operations; O(n log n) is twenty million. That's a 20× difference — meaningful on tight latency budgets. And the gap grows: at n=10⁹, O(n) is a billion operations and O(n log n) is thirty billion. They're different complexity classes for a reason.

**"Memoization only fixes Fibonacci — it's not a general technique"**
Memoization converts any O(2ⁿ) recursion with *overlapping subproblems* to polynomial complexity. This covers all dynamic programming problems: shortest path (Dijkstra, Floyd-Warshall), knapsack, edit distance, longest common subsequence. The structural requirement is overlapping subproblems — if each subproblem is unique, memoization adds overhead without benefit.

```csharp
// Overlapping subproblems = memoization works
// fib(5) calls fib(4) and fib(3)
// fib(4) calls fib(3) and fib(2) — fib(3) called twice! → cache it

// Non-overlapping (merge sort) = memoization doesn't help
// Each recursive call operates on a different subarray — no repeated subproblems
```

**"O(n log n) is the fastest you can sort"**
Only for *comparison-based* sorting. Counting sort, radix sort, and bucket sort sidestep element comparisons entirely and achieve O(n + k) where k is the range of values. They work only when input has special structure (bounded integers, known alphabet). For general data, the O(n log n) lower bound holds — it's a proven information-theoretic result, not a practical limitation.

---

## Gotchas

- **O(n log n) is the provable floor for comparison-based sorting — you cannot do better.** The proof: a comparison-based sort on n elements must distinguish between n! possible orderings. A binary decision tree needs at least log₂(n!) ≈ n log n leaves. This is a mathematical certainty, not a benchmark result.

- **O(2ⁿ) explodes faster than intuition suggests.** At n=30, that's over a billion operations. At n=60, more operations than atoms in the observable universe. Naive recursion on overlapping subproblems is almost always fixable with memoization — converting O(2ⁿ) to O(n) or O(n²).

- **O(n²) is a hidden danger in nested data operations.** A loop over a list that calls `.Contains()`, `.Find()`, or `.Where()` on another list inside it is O(n²) even though it looks like "one loop." The inner LINQ operation is itself O(n). Use a `Dictionary` or `HashSet` to fix it.

- **O(log n) requires a sorted or structured input.** Binary search is O(log n) only because the data is sorted. Apply it to unsorted data and it doesn't run slower — it produces wrong answers. The precondition is part of the complexity analysis.

- **"Polynomial time" is the boundary between tractable and hard.** P-class problems (O(nᵏ) for any fixed k) are considered tractable. NP-complete problems have no known polynomial solutions. Exponential and factorial complexity signals you need DP, greedy approximation, or a fundamentally different problem formulation — not just a better implementation.

- **Two different n values complicate analysis.** When an algorithm operates on two inputs of size n and m, the complexity is O(n × m) for nested loops or O(n + m) for sequential — not simply O(n²) or O(n). State both variables when the inputs are independent.

---

## Interview Angle

**What they're really testing:** Whether you can look at unfamiliar code and immediately classify its complexity — and whether you know the theoretical limits of what's achievable for a given problem type.

**Common question forms:**
- "Can you optimize this?" (where the current solution is O(n²) and the expected answer involves a hash map or sort)
- "What's the best complexity achievable for this problem?"
- "Why can't we sort faster than O(n log n)?"

**The depth signal:** A junior knows the classes by name and can label examples. A senior knows the *structural reason* each class exists — "this is O(log n) because we halve the search space each step; that's log₂(n) maximum steps" — and knows the theoretical lower bounds: "comparison-based sorting can't beat O(n log n) because the decision tree for n elements has n! leaves, requiring at least log(n!) ≈ n log n decisions." That reasoning distinguishes understanding from memorization.

**Follow-up questions to expect:**
- "Is there a way to get O(n) for sorting?" (the counting/radix sort follow-up)
- "How does the complexity change if the input is partially sorted?" (best-case vs worst-case)
- "What's the space complexity trade-off?" (e.g., merge sort O(n) space vs heapsort O(1))

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation, simplification rules, and the three cases (best/average/worst).
- [[algorithms/complexity/complexity-analysis.md]] — How to derive the complexity class of code you haven't seen before.
- [[algorithms/complexity/amortized-analysis.md]] — How O(1) amortized differs from O(1) guaranteed (critical for List<T>, Dictionary).
- [[algorithms/complexity/master-theorem.md]] — Systematic tool for solving divide-and-conquer recurrences.
- [[algorithms/patterns/dynamic-programming.md]] — The primary technique for converting O(2ⁿ) recursive solutions to O(n) or O(n²).
- [[algorithms/sorting-algorithms/merge-sort.md]] — Concrete walkthrough of why merge sort is O(n log n).

---

## Source

https://www.bigocheatsheet.com

---

*Last updated: 2026-04-12*