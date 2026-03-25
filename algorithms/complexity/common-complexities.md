# Common Complexities
> A reference for the growth classes that appear most often in real algorithms, ordered from fastest to slowest.

---

## When To Use It
Use this as a decision framework when designing or reviewing algorithms. Knowing which complexity class your target solution falls into tells you whether your current approach has room to improve — or whether you've already hit the theoretical limit. Don't memorize this list; understand why each class exists.

---

## Core Concept
Most algorithms you'll encounter fall into one of seven complexity classes. They form a hierarchy: O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!). Moving up that hierarchy is expensive — an O(n²) solution that works at n=1,000 will fall apart at n=1,000,000. The practical skill is recognizing which class your code falls into by its structure: loops, recursion depth, branching factor, and whether you're halving or doubling the problem each step.

---

## The Code

**O(1) — Constant**
```csharp
public static int GetLast(List<int> items)
{
    return items[items.Count - 1];  // index access, no matter the size
}
```

**O(log n) — Logarithmic**
```csharp
// Input is halved each iteration — classic log n shape
public static int BinarySearch(List<int> items, int target)
{
    int lo = 0, hi = items.Count - 1;
    while (lo <= hi)
    {
        int mid = (lo + hi) / 2;
        if (items[mid] == target)
            return mid;
        else if (items[mid] < target)
            lo = mid + 1;
        else
            hi = mid - 1;
    }
    return -1;
}
```

**O(n) — Linear**
```csharp
public static int LinearSearch(List<int> items, int target)
{
    for (int i = 0; i < items.Count; i++)
    {
        if (items[i] == target)
            return i;
    }
    return -1;
}
```

**O(n log n) — Linearithmic**
```csharp
// The best achievable for comparison-based sorting
var items = new List<int> { 3, 1, 4, 1, 5, 9, 2, 6 };
items.Sort();  // C#'s IntroSort: O(n log n) time, O(log n) space
```

**O(n²) — Quadratic**
```csharp
// Every pair of elements is compared — nested loops
public static void BubbleSort(List<int> items)
{
    int n = items.Count;
    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n - i - 1; j++)
        {
            if (items[j] > items[j + 1])
            {
                int temp = items[j];
                items[j] = items[j + 1];
                items[j + 1] = temp;
            }
        }
    }
}
```

**O(2ⁿ) — Exponential**
```csharp
// Each call branches into two — tree doubles every level
public static int FibonacciNaive(int n)
{
    if (n <= 1)
        return n;
    return FibonacciNaive(n - 1) + FibonacciNaive(n - 2);
}
```

**O(n!) — Factorial**
```csharp
// Generating all orderings — grows faster than anything else
public static List<List<int>> AllPermutations(List<int> items)
{
    var result = new List<List<int>>();
    GeneratePermutations(items, 0, result);
    return result;
}

private static void GeneratePermutations(List<int> items, int start, List<List<int>> result)
{
    if (start == items.Count - 1)
    {
        result.Add(new List<int>(items));
        return;
    }
    
    for (int i = start; i < items.Count; i++)
    {
        // Swap
        int temp = items[start];
        items[start] = items[i];
        items[i] = temp;
        
        GeneratePermutations(items, start + 1, result);
        
        // Swap back
        temp = items[start];
        items[start] = items[i];
        items[i] = temp;
    }
}
// n=10 → 3,628,800 permutations
// n=15 → 1,307,674,368,000 permutations
```

---

## Gotchas

- **O(n log n) is the floor for comparison-based sorting — you cannot do better.** Any algorithm that sorts by comparing elements cannot beat this. Counting sort and radix sort sidestep comparisons entirely, which is why they achieve O(n).
- **O(2ⁿ) explodes faster than it looks.** At n=30, that's over a billion operations. Naive recursion on overlapping subproblems (Fibonacci, subset generation) is almost always fixable with memoization — bringing it down to O(n).
- **O(n²) is a hidden danger in nested data structures.** A loop over a list that calls `.index()` or `in` on another list inside it is O(n²) even though it looks like one loop. The inner operation is itself O(n).
- **O(log n) requires a sorted or structured input.** Binary search is O(log n) only because the data is sorted. Apply it to unsorted data and it simply doesn't work — it's not slower, it's wrong.
- **Polynomial (O(nᵏ)) is the boundary between "feasible" and "hard."** Problems solvable in polynomial time are considered tractable. Exponential and factorial complexity almost always signals that you need dynamic programming, greedy approximation, or a different problem formulation.

---

## Interview Angle

**What they're really testing:** Whether you can look at unfamiliar code and immediately classify its complexity — and whether you know the theoretical limits of what's achievable.

**Common question form:** "Can you optimize this?" — where the current solution is O(n²) and the expected answer involves recognizing a hash map or sorting step that brings it to O(n) or O(n log n).

**The depth signal:** A junior knows the classes by name and associates them with common examples. A senior knows *why* a class is a lower bound — e.g., "comparison-based sorting can't beat O(n log n) because the decision tree for n elements has n! leaves, requiring at least log(n!) ≈ n log n decisions." That kind of reasoning shows understanding, not memorization.

---

## Related Topics

- [[algorithms/big-o-notation.md]] — The notation and rules for expressing and simplifying complexity.
- [[algorithms/complexity-analysis.md]] — How to derive the complexity class of code you haven't seen before.
- [[algorithms/sorting-algorithms.md]] — Concrete algorithms spanning O(n log n) to O(n²) with real trade-offs.
- [[algorithms/dynamic-programming.md]] — The primary technique for converting O(2ⁿ) recursive solutions to O(n) or O(n²).

---

## Source

https://www.bigocheatsheet.com

---

*Last updated: 2026-03-24*