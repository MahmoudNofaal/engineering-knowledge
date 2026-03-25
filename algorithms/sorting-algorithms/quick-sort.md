# Quick Sort
> A divide-and-conquer sort that picks a pivot, partitions the array around it, and recursively sorts each partition — O(n log n) average.

---

## When To Use It
Quick sort is the default choice for general-purpose in-memory sorting when average-case performance matters more than worst-case guarantees. It's faster in practice than merge sort for arrays due to better cache locality and no extra allocation. Avoid it when you need stable sort, guaranteed O(n log n) worst-case, or are sorting data with many duplicates (use three-way partition instead).

---

## Core Concept
Pick a pivot element. Rearrange the array so everything less than the pivot is to its left, everything greater is to its right. The pivot is now in its final sorted position. Recurse on the left and right partitions. The key insight is that the partition step is O(n) and places one element permanently — no merging needed. Average case is O(n log n) because a random pivot splits the array roughly in half. Worst case is O(n²) when the pivot is always the smallest or largest element (sorted input with a naive pivot choice). Randomizing the pivot eliminates this in practice.

---

## The Code

**Standard quick sort with randomized pivot**
```csharp
public static void QuickSort(List<int> items, int lo, int hi)
{
    if (lo >= hi)
        return;
    int pivotIdx = Partition(items, lo, hi);
    QuickSort(items, lo, pivotIdx - 1);
    QuickSort(items, pivotIdx + 1, hi);
}

public static int Partition(List<int> items, int lo, int hi)
{
    // swap a random element to the end as pivot
    Random rand = new Random();
    int randIdx = rand.Next(lo, hi + 1);
    int temp = items[randIdx];
    items[randIdx] = items[hi];
    items[hi] = temp;
    
    int pivot = items[hi];
    int i = lo - 1;                    // i tracks the last element ≤ pivot
    for (int j = lo; j < hi; j++)
    {
        if (items[j] <= pivot)
        {
            i++;
            temp = items[i];
            items[i] = items[j];
            items[j] = temp;
        }
    }
    temp = items[i + 1];
    items[i + 1] = items[hi];
    items[hi] = temp;  // place pivot
    return i + 1;
}

// Usage
var arr = new List<int> { 3, 6, 8, 10, 1, 2, 1 };
QuickSort(arr, 0, arr.Count - 1);
```

**Three-way partition (Dutch National Flag) — handles duplicates efficiently**
```csharp
public static void QuickSort3Way(List<int> items, int lo, int hi)
{
    if (lo >= hi)
        return;
    int pivot = items[lo];
    int lt = lo, gt = hi;   // items[lo..lt-1] < pivot, items[gt+1..hi] > pivot
    int i = lo;
    
    while (i <= gt)
    {
        if (items[i] < pivot)
        {
            int temp = items[lt];
            items[lt] = items[i];
            items[i] = temp;
            lt++; i++;
        }
        else if (items[i] > pivot)
        {
            int temp = items[gt];
            items[gt] = items[i];
            items[i] = temp;
            gt--;            // don't increment i — new items[i] unchecked
        }
        else
        {
            i++;
        }
    }
    QuickSort3Way(items, lo, lt - 1);
    QuickSort3Way(items, gt + 1, hi);
}
```

**Quick select — kth smallest in O(n) average**
```csharp
public static int QuickSelect(List<int> items, int lo, int hi, int k)
{
    if (lo == hi)
        return items[lo];
    int pivotIdx = Partition(items, lo, hi);
    if (k == pivotIdx)
        return items[k];
    else if (k < pivotIdx)
        return QuickSelect(items, lo, pivotIdx - 1, k);
    else
        return QuickSelect(items, pivotIdx + 1, hi, k);
}

// Find kth smallest (0-indexed)
var arr = new List<int> { 3, 1, 4, 1, 5, 9, 2, 6 };
Console.WriteLine(QuickSelect(arr, 0, arr.Count - 1, 3));  // 4th smallest
```

---

## Gotchas

- **Naive pivot (always first or last element) is O(n²) on sorted input.** Sorted or reverse-sorted arrays are the common case in production data. Always randomize the pivot or use median-of-three.
- **Quick sort is not stable.** Equal elements can be reordered during partitioning. If stability matters, use merge sort.
- **Worst-case O(n²) still exists with randomized pivot — just astronomically unlikely.** If you need a hard O(n log n) guarantee, use merge sort or heap sort. Introsort (used by C++ `std::sort`) switches to heap sort after detecting recursion depth exceeding log n, giving the best of both.
- **Stack overflow risk on deeply skewed partitions.** Each recursive call uses stack space. A bad partition sequence of depth n crashes the call stack. Always recurse on the smaller partition first to limit stack depth to O(log n).
- **Three-way partition is crucial for arrays with many duplicates.** Standard partition degrades to O(n²) on an array of all identical elements. Three-way partition handles this in O(n).

---

## Interview Angle

**What they're really testing:** Whether you know the difference between average and worst case, why pivot choice matters, and whether you can implement partition correctly under pressure.

**Common question form:** Implement quick sort, find the kth largest/smallest element (quick select), partition an array by a condition (Dutch National Flag).

**The depth signal:** A junior implements basic quick sort. A senior knows why randomized pivot matters, can implement three-way partition for duplicates, and recognizes quick select as a O(n) average algorithm for kth-element problems — better than sorting at O(n log n). They also know introsort exists and why C++'s `std::sort` is hybrid.

---

## Related Topics

- [[algorithms/merge-sort.md]] — Stable, guaranteed O(n log n), but O(n) space. The alternative when worst-case matters.
- [[algorithms/heap-sort.md]] — In-place, guaranteed O(n log n). Slower in practice than quick sort but no O(n²) risk.
- [[algorithms/sorting-in-practice.md]] — How quick sort fits into real-world hybrid sorts (introsort, pdqsort).

---

## Source

https://en.wikipedia.org/wiki/Quicksort

---

*Last updated: 2026-03-24*