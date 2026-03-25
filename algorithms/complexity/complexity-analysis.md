# Complexity Analysis
> The process of measuring how an algorithm's resource usage — time and space — scales with input size.

---

## When To Use It
Apply complexity analysis whenever you're choosing between two approaches or reviewing code that will run on non-trivial input sizes. It's how you justify technical decisions beyond "it feels faster." Skip deep analysis for throwaway scripts, config parsing, or one-time migrations where input is bounded and small.

---

## Core Concept
Complexity analysis is the discipline behind Big-O notation. You're asking: as n grows, what happens to the cost of this algorithm? You analyze it by counting the operations that scale with input — loops, recursive calls, comparisons — and ignoring the ones that don't. You do this separately for time (how many operations) and space (how much memory). The goal isn't a precise number; it's a growth class that lets you compare algorithms without benchmarking them.

There are three cases to know: best-case (Ω), average-case (Θ), and worst-case (O). In practice, worst-case is what you defend against in production.

---

## The Code

**Identifying the dominant term — only the fastest-growing part survives**
```csharp
public static void Example(List<int> items)
{
    // O(1) — constant work
    Console.WriteLine(items[0]);

    // O(n) — linear scan
    foreach (var item in items)
    {
        Console.WriteLine(item);
    }

    // O(n²) — nested scan
    foreach (var i in items)
    {
        foreach (var j in items)
        {
            Console.WriteLine($"{i} {j}");
        }
    }

    // Total: O(1) + O(n) + O(n²) → simplified to O(n²)
    // The quadratic term dominates; everything else is irrelevant at scale.
}
```

**Analyzing recursive complexity with a recurrence relation**
```csharp
public static List<int> MergeSort(List<int> items)
{
    if (items.Count <= 1)
        return items;

    int mid = items.Count / 2;
    var left = MergeSort(items.Take(mid).ToList());      // T(n/2)
    var right = MergeSort(items.Skip(mid).ToList());     // T(n/2)

    return Merge(left, right);                            // O(n) merge step
}

// Recurrence: T(n) = 2T(n/2) + O(n)
// Solving via Master Theorem → O(n log n)
```

**Space complexity: iterative vs recursive**
```csharp
// O(1) space — no call stack growth
public static int SumIterative(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++)
    {
        total += i;
    }
    return total;
}

// O(n) space — n frames on the call stack
public static int SumRecursive(int n)
{
    if (n == 0)
        return 0;
    return n + SumRecursive(n - 1);
}
```

**Amortized analysis — cost averaged over many operations**
```csharp
var items = new List<int>();
for (int i = 0; i < n; i++)
{
    items.Add(i);
    // Most appends are O(1).
    // Occasionally the list doubles in size → O(n) copy.
    // Amortized over all n appends: O(1) per operation.
}
```

---

## Gotchas

- **Ignoring space complexity is a production bug waiting to happen.** A solution with O(1) time improvement but O(n) extra memory can OOM a service under load. Always state both.
- **Amortized ≠ average-case.** Amortized is a guarantee over a sequence of operations (e.g., dynamic array append). Average-case is a probabilistic statement over input distributions (e.g., QuickSort). They sound similar but mean different things.
- **Recursive depth counts as space.** Python's default recursion limit is 1000. A recursive DFS on a graph with 10,000 nodes hits a stack overflow before it hits a time limit.
- **The Master Theorem only applies to divide-and-conquer recurrences of a specific form.** If the subproblems aren't equal-sized or the combination step doesn't fit the pattern, you need a different approach.
- **Input characteristics change the case.** An already-sorted array is QuickSort's worst case but insertion sort's best case. Never analyze complexity without stating which case you're describing.

---

## Interview Angle

**What they're really testing:** Whether you can analyze code you've never seen before, not just memorize the complexity of known algorithms.

**Common question form:** "Walk me through the time and space complexity of your solution" — asked after you write code, not before.

**The depth signal:** A junior gives the answer ("it's O(n log n)"). A senior derives it — identifies the recurrence relation, applies the Master Theorem or expansion, and separately states space complexity including the call stack. Seniors also flag when worst-case and average-case diverge and explain which one matters for the given use case.

---

## Related Topics

- [[algorithms/big-o-notation.md]] — The notation system used to express complexity analysis results.
- [[algorithms/sorting-algorithms.md]] — Classic case study for comparing time and space complexity across approaches.
- [[algorithms/recursion-and-stack.md]] — Where space complexity analysis gets non-obvious due to call stack growth.

---

## Source

https://www.cs.cornell.edu/courses/cs3110/2012sp/lectures/lec19-master/lec19.html

---

*Last updated: 2026-03-24*