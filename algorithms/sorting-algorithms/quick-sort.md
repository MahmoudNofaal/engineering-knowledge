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
```python
import random

def quick_sort(items: list, lo: int, hi: int) -> None:
    if lo >= hi:
        return
    pivot_idx = partition(items, lo, hi)
    quick_sort(items, lo, pivot_idx - 1)
    quick_sort(items, pivot_idx + 1, hi)

def partition(items: list, lo: int, hi: int) -> int:
    # swap a random element to the end as pivot
    rand_idx = random.randint(lo, hi)
    items[rand_idx], items[hi] = items[hi], items[rand_idx]
    pivot = items[hi]
    i = lo - 1                    # i tracks the last element ≤ pivot
    for j in range(lo, hi):
        if items[j] <= pivot:
            i += 1
            items[i], items[j] = items[j], items[i]
    items[i + 1], items[hi] = items[hi], items[i + 1]  # place pivot
    return i + 1

# Usage
arr = [3, 6, 8, 10, 1, 2, 1]
quick_sort(arr, 0, len(arr) - 1)
```

**Three-way partition (Dutch National Flag) — handles duplicates efficiently**
```python
def quick_sort_3way(items: list, lo: int, hi: int) -> None:
    if lo >= hi:
        return
    pivot = items[lo]
    lt, gt = lo, hi   # items[lo..lt-1] < pivot, items[gt+1..hi] > pivot
    i = lo
    while i <= gt:
        if items[i] < pivot:
            items[lt], items[i] = items[i], items[lt]
            lt += 1; i += 1
        elif items[i] > pivot:
            items[gt], items[i] = items[i], items[gt]
            gt -= 1            # don't increment i — new items[i] unchecked
        else:
            i += 1
    quick_sort_3way(items, lo, lt - 1)
    quick_sort_3way(items, gt + 1, hi)
```

**Quick select — kth smallest in O(n) average**
```python
def quick_select(items: list, lo: int, hi: int, k: int) -> int:
    if lo == hi:
        return items[lo]
    pivot_idx = partition(items, lo, hi)
    if k == pivot_idx:
        return items[k]
    elif k < pivot_idx:
        return quick_select(items, lo, pivot_idx - 1, k)
    else:
        return quick_select(items, pivot_idx + 1, hi, k)

# Find kth smallest (0-indexed)
arr = [3, 1, 4, 1, 5, 9, 2, 6]
print(quick_select(arr, 0, len(arr) - 1, 3))  # 4th smallest
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