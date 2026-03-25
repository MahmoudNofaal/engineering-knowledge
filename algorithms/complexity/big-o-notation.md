# Big-O Notation
> A way to describe how an algorithm's time or space requirements grow as the input size grows.

---

## When To Use It
Use Big-O when comparing algorithms or data structures to decide which fits your constraints. It matters most when input size can grow large — sorting a list of 10 items? Doesn't matter. Sorting 10 million? It matters a lot. Don't over-optimize for Big-O when data is small and constant factors dominate in practice.

---

## Core Concept
Big-O describes the worst-case growth rate of an algorithm — not the exact runtime, just how it scales. If you double the input and the time doubles, that's O(n). If the time quadruples, that's O(n²). Constants and lower-order terms get dropped because at large scale, they become irrelevant. O(2n) and O(n + 500) are both just O(n). You care about the shape of the curve, not the exact values.

---

## The Code

**O(1) — Constant: access by index**
```csharp
public static int GetFirst(List<int> items)
{
    return items[0];  // always one operation, regardless of list size
}
```

**O(n) — Linear: single loop**
```csharp
public static int FindMax(List<int> items)
{
    int maxVal = items[0];
    foreach (var item in items)
    {
        if (item > maxVal)
            maxVal = item;
    }
    return maxVal;
}
```

**O(n²) — Quadratic: nested loops**
```csharp
public static bool HasDuplicate(List<int> items)
{
    for (int i = 0; i < items.Count; i++)
    {
        for (int j = 0; j < items.Count; j++)
        {
            if (i != j && items[i] == items[j])
                return true;
        }
    }
    return false;
}
```

**O(log n) — Logarithmic: binary search**
```csharp
public static int BinarySearch(List<int> items, int target)
{
    int lo = 0, hi = items.Count - 1;
    while (lo <= hi)
    {
        int mid = (lo + hi) / 2;
        if (items[mid] == target)
            return mid;
        else if (items[mid] < target)
            lo = mid + 1;  // discard left half
        else
            hi = mid - 1;  // discard right half
    }
    return -1;
}
```

**O(n log n) — Linearithmic: C#'s built-in sort**
```csharp
var items = new List<int> { 5, 2, 8, 1, 9 };
items.Sort();  // O(n log n) — the best possible for comparison-based sorting
```

---

## Gotchas

- **Dropping constants can mislead you in practice.** O(n) with a massive constant can be slower than O(n²) for small n. Big-O is about scale, not a guarantee of real-world speed.
- **Big-O is worst-case by default — but not always.** QuickSort is O(n²) worst-case but O(n log n) average. When someone says QuickSort is fast, they mean average-case. Know which case you're discussing.
- **Space complexity is just as real as time complexity.** Recursive solutions often look clean but carry O(n) stack space. A DFS on a deep tree can blow the stack before it blows the time limit.
- **Two separate loops is O(n), not O(n²).** Only nested loops multiply. Sequential loops add: O(n) + O(n) = O(2n) = O(n).
- **Hash map lookups are O(1) average, not guaranteed.** Worst-case with hash collisions is O(n). In interview answers, clarify "amortized O(1)."

---

## Interview Angle

**What they're really testing:** Whether you can reason about scalability trade-offs, not just recite a lookup table.

**Common question form:** "What's the time complexity of your solution?" or "Can you do better than O(n²)?" after you write a brute-force answer.

**The depth signal:** A junior says "it's O(n) because there's one loop." A senior explains *why* — "it's O(n) because each element is visited exactly once, and the hash map lookups inside are O(1) amortized, so the loop doesn't compound." Seniors also volunteer space complexity unprompted and know when an O(n log n) solution is optimal because comparison-based sorting has a proven lower bound of Ω(n log n).

---

## Related Topics

- [[algorithms/sorting-algorithms.md]] — Concrete examples of O(n log n) vs O(n²) sorting trade-offs in practice.
- [[algorithms/hash-maps.md]] — Understanding why hash map operations are O(1) amortized and when they degrade.
- [[algorithms/recursion-and-stack.md]] — Space complexity implications of recursive solutions vs iterative ones.

---

## Source

https://www.bigocheatsheet.com

---

*Last updated: 2026-03-24*