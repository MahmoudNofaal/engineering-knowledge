# Quick Sort

> A divide-and-conquer sort that picks a pivot, partitions the array around it, and recursively sorts each partition — O(n log n) average, in-place.

---

## Quick Reference

| | |
|---|---|
| **What it is** | In-place D&C: partition around pivot, recurse on each side |
| **Use when** | General-purpose in-memory sorting; kth element (quick select) |
| **Avoid when** | Stable sort required; guaranteed worst-case needed (use merge sort / heapsort) |
| **C# version** | C# 1.0+; `Array.Sort` uses introsort (quicksort + heapsort hybrid) |
| **Namespace** | None — custom implementation; `Array.Sort` uses it internally |
| **Key types** | `int lo`, `int hi`, `int pivot`; `Random` for pivot randomisation |

---

## When To Use It

Use quicksort when average-case performance matters more than worst-case guarantees and stability is not required. It's faster than merge sort on arrays in practice because it's in-place — no merge buffer means better cache performance. Quick select (the partition step applied to find the kth element) is O(n) average — better than sorting at O(n log n) for single-element queries. Avoid quicksort when the input is nearly sorted and you can't randomise the pivot, or when stability is required.

---

## Core Concept

Pick a pivot element. Rearrange the array so everything less than the pivot is to its left, everything greater is to its right. The pivot is now in its final sorted position — no merging needed. Recurse on the left and right partitions.

The partition step is O(n). One element is placed permanently per call. Average case is O(n log n) because a random pivot splits the array roughly in half. Worst case is O(n²) when the pivot is always the minimum or maximum — sorted input with a naive last-element pivot. Randomising the pivot eliminates this in practice.

**Three-way partition** (Dutch National Flag) handles arrays with many duplicates: elements equal to the pivot are placed together in the middle, and only the lt and gt partitions recurse. Without it, O(n) duplicates degrade to O(n²).

---

## Algorithm History

| Year | Development |
|---|---|
| 1959 | Tony Hoare invents quicksort — publishes 1961 |
| 1975 | Robert Sedgewick's PhD thesis on quicksort optimisations |
| 1993 | Jon Bentley and Doug McIlroy publish "Engineering a Sort Function" — three-way partition |
| 1997 | Introsort invented by David Musser — quicksort + heapsort fallback |
| 1999 | Java adopts dual-pivot quicksort for primitive array sorting |
| 2009 | Vladimir Yaroslavskiy's dual-pivot quicksort adopted in Java 7 |

---

## Performance

| Case | Time | Space (stack) | Notes |
|---|---|---|---|
| Best case | O(n log n) | O(log n) | Even splits every time |
| Average case | O(n log n) | O(log n) | Randomised pivot |
| Worst case | O(n²) | O(n) | Sorted input, naive pivot |
| Three-way partition | O(n) best | O(log n) | O(n) for all-equal arrays |

**Allocation behaviour:** In-place — zero heap allocation beyond the partition's local variables. Stack depth is O(log n) for balanced splits, O(n) for degenerate splits. Introsort switches to heapsort when recursion depth exceeds 2 log n to cap worst-case stack.

**Benchmark notes:** Quicksort is typically 2–3× faster than merge sort on arrays because it operates in-place with better cache locality. For n < 16, insertion sort is faster — introsort uses insertion sort for small subarrays.

---

## The Code

**Scenario 1 — standard quicksort with randomised pivot**
```csharp
private static readonly Random _rng = new();

public static void QuickSort(int[] arr, int lo, int hi)
{
    if (lo >= hi) return;
    int pivot = Partition(arr, lo, hi);
    QuickSort(arr, lo, pivot - 1);
    QuickSort(arr, pivot + 1, hi);
}

private static int Partition(int[] arr, int lo, int hi)
{
    // Randomise pivot to avoid O(n²) on sorted/reverse-sorted input
    int pivotIdx = _rng.Next(lo, hi + 1);
    (arr[pivotIdx], arr[hi]) = (arr[hi], arr[pivotIdx]);

    int pivot = arr[hi];
    int i = lo - 1;                    // i = last element ≤ pivot
    for (int j = lo; j < hi; j++)
        if (arr[j] <= pivot)
            (arr[++i], arr[j]) = (arr[j], arr[++i - 1]); // swap
    (arr[i + 1], arr[hi]) = (arr[hi], arr[i + 1]);        // place pivot
    return i + 1;
}
```

**Scenario 2 — three-way partition (Dutch National Flag — handles duplicates)**
```csharp
public static void QuickSort3Way(int[] arr, int lo, int hi)
{
    if (lo >= hi) return;
    int pivot = arr[lo + _rng.Next(hi - lo + 1)];
    int lt = lo, gt = hi, i = lo;

    while (i <= gt)
    {
        if      (arr[i] < pivot)  (arr[lt++], arr[i++]) = (arr[i], arr[lt]);
        else if (arr[i] > pivot)  (arr[i],    arr[gt--]) = (arr[gt], arr[i]);
        else                       i++;
    }
    // arr[lo..lt-1] < pivot, arr[lt..gt] == pivot, arr[gt+1..hi] > pivot
    QuickSort3Way(arr, lo, lt - 1);
    QuickSort3Way(arr, gt + 1, hi);
}
```

**Scenario 3 — quick select: kth smallest in O(n) average**
```csharp
public static int QuickSelect(int[] arr, int lo, int hi, int k)
{
    if (lo == hi) return arr[lo];
    int pivot = Partition(arr, lo, hi);
    if      (k == pivot) return arr[k];
    else if (k < pivot)  return QuickSelect(arr, lo, pivot - 1, k);
    else                 return QuickSelect(arr, pivot + 1, hi, k);
}

// Find kth smallest (0-indexed k)
// QuickSelect(arr, 0, arr.Length - 1, k)
// Average O(n); worst case O(n²) — use median-of-medians for O(n) worst case
```

**Scenario 4 — what NOT to do: naive last-element pivot on sorted input**
```csharp
// BAD: always picking the last element as pivot on sorted arrays
// creates partitions of size (0, n-1) each time → O(n²) and O(n) stack depth
public static void QuickSortBad(int[] arr, int lo, int hi)
{
    if (lo >= hi) return;
    // Pivot = last element — disaster on sorted or reverse-sorted arrays
    int pivot = arr[hi];
    int i = lo - 1;
    for (int j = lo; j < hi; j++)
        if (arr[j] <= pivot) { i++; (arr[i], arr[j]) = (arr[j], arr[i]); }
    (arr[i + 1], arr[hi]) = (arr[hi], arr[i + 1]);
    int pivotIdx = i + 1;

    QuickSortBad(arr, lo, pivotIdx - 1); // always (0, n-1) on sorted input
    QuickSortBad(arr, pivotIdx + 1, hi); // always empty
}

// GOOD: randomise the pivot before partitioning
// int randIdx = _rng.Next(lo, hi + 1);
// (arr[randIdx], arr[hi]) = (arr[hi], arr[randIdx]); // swap to end, then partition
```

---

## Real World Example

The `TransactionRankingService` in a payment platform finds the top-K highest-value transactions from a daily batch without sorting the full dataset. Quick select (the partition step of quicksort applied k times) finds the kth largest in O(n) average — compared to O(n log n) if the full array were sorted first.

```csharp
public class TransactionRankingService
{
    public record Transaction(Guid Id, decimal Amount, DateTimeOffset Timestamp);

    // Returns the K largest transactions by amount — O(n) average via quick select.
    public List<Transaction> TopKByAmount(List<Transaction> transactions, int k)
    {
        if (k <= 0 || transactions.Count == 0) return new List<Transaction>();
        k = Math.Min(k, transactions.Count);

        var amounts = transactions.Select(t => t.Amount).ToArray();
        // Quick select to find the kth largest (0-indexed from the end)
        int kthSmallestIdx = amounts.Length - k;
        QuickSelectInPlace(amounts, 0, amounts.Length - 1, kthSmallestIdx);

        decimal threshold = amounts[kthSmallestIdx];
        return transactions
            .Where(t => t.Amount >= threshold)
            .OrderByDescending(t => t.Amount)
            .Take(k)
            .ToList();
    }

    private void QuickSelectInPlace(decimal[] arr, int lo, int hi, int k)
    {
        while (lo < hi)
        {
            int pivot = Partition(arr, lo, hi);
            if      (pivot == k) return;
            else if (pivot < k)  lo = pivot + 1;
            else                 hi = pivot - 1;
        }
    }

    private int Partition(decimal[] arr, int lo, int hi)
    {
        int randIdx = Random.Shared.Next(lo, hi + 1);
        (arr[randIdx], arr[hi]) = (arr[hi], arr[randIdx]);
        decimal pivot = arr[hi];
        int i = lo - 1;
        for (int j = lo; j < hi; j++)
            if (arr[j] <= pivot) { i++; (arr[i], arr[j]) = (arr[j], arr[i]); }
        (arr[i + 1], arr[hi]) = (arr[hi], arr[i + 1]);
        return i + 1;
    }
}
```

*The key insight: quick select's iterative version (replace recursion with a loop that narrows lo/hi) eliminates all stack frames — O(1) space versus O(log n) recursive. On a 1M transaction batch, this avoids a full O(n log n) sort when only the top 10 are needed.*

---

## Common Misconceptions

**"Quicksort is always O(n log n)"**
Average case is O(n log n). Worst case is O(n²) — happens with naive pivot selection on sorted or reverse-sorted input. Randomised pivot makes O(n²) astronomically unlikely but not impossible. Introsort (C#'s `Array.Sort`) switches to heapsort after detecting O(log n) recursion depth, guaranteeing O(n log n) worst case.

**"Quicksort is faster than merge sort because of its complexity"**
Same asymptotic complexity. Quicksort is faster in practice because it's in-place — no merge buffer means fewer cache misses. The difference is the constant factor, not the Big-O class. On linked lists, merge sort is faster because quicksort needs random access for partitioning.

**"Three-way partition is just an optimisation"**
For arrays with many duplicates, it's the difference between O(n) and O(n²). On an array of all identical elements, standard quicksort degrades to O(n²) — every element is placed on the same side of the pivot. Three-way partition handles this in O(n). It's not optional for production-quality implementations.

---

## Gotchas

- **Always randomise the pivot.** Sorted or reverse-sorted input is the common real-world case. Without randomisation, sorted input is always O(n²).
- **Recurse on the smaller partition first.** This limits stack depth to O(log n) regardless of pivot quality. Without this, a sequence of bad pivots can overflow the stack.
- **Three-way partition is required for arrays with many duplicates.** Standard partition degrades to O(n²) on all-equal arrays.
- **Quick select modifies the array in-place.** If the original order must be preserved, copy the array first.
- **`Array.Sort` in C# is introsort** — quicksort + heapsort fallback + insertion sort for small subarrays. It is not stable. For stable sorting, use LINQ `OrderBy`.

---

## Interview Angle

**What they're really testing:** Pivot choice, partition correctness, and quick select as a O(n) kth-element algorithm.

**Common question forms:** Implement quicksort. Find the kth largest element. Sort colours (Dutch National Flag — three-way partition). Partition array by a condition.

**The depth signal:** A senior knows why randomised pivot matters, implements three-way partition for duplicates, uses quick select for kth-element problems (O(n) average vs O(n log n) sort), and knows introsort uses quicksort + heapsort fallback.

**Follow-up questions to expect:**
- "What's the worst case?" → O(n²) with naive pivot on sorted input. Randomised pivot makes it O(n log n) with overwhelming probability.
- "How does introsort fix the worst case?" → Tracks recursion depth; switches to heapsort when depth exceeds 2 log n.

---

## Related Topics

- [[algorithms/sorting-algorithms/merge-sort.md]] — Stable, guaranteed O(n log n), O(n) space — use when stability matters.
- [[algorithms/sorting-algorithms/heap-sort.md]] — In-place, guaranteed O(n log n) — introsort's fallback.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — How quicksort fits into introsort and real-world sorting.
- [[algorithms/patterns/divide-and-conquer.md]] — Quicksort is D&C with a partition step instead of a merge step.

---

## Source

https://en.wikipedia.org/wiki/Quicksort

---

*Last updated: 2026-04-21*