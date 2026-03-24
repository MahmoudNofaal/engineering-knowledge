# Heap Sort
> A comparison-based sort that builds a max-heap from the array and repeatedly extracts the maximum to produce a sorted result — O(n log n) guaranteed, in-place.

---

## When To Use It
Use heap sort when you need guaranteed O(n log n) worst-case with O(1) extra space and don't require stability. It's the right choice in memory-constrained environments where merge sort's O(n) buffer is unacceptable and where quick sort's O(n²) worst case is unacceptable. In practice, heap sort is rarely used directly — introsort (C++ `std::sort`) falls back to it as a safeguard but prefers quick sort for cache performance.

---

## Core Concept
Heap sort has two phases. First, build a max-heap from the array in O(n) using heapify — the largest element is now at index 0. Second, repeatedly swap the root (max) with the last unsorted element, shrink the heap by one, and sift the new root down to restore the heap property. After n-1 swaps, the array is sorted. Each sift-down is O(log n), and there are n of them, giving O(n log n). The entire sort happens in-place within the original array — no extra buffer needed.

---

## The Code

**Heap sort — full implementation**
```python
def heap_sort(items: list) -> None:
    n = len(items)

    # Phase 1: build max-heap in O(n)
    # start from last non-leaf node and sift down each
    for i in range(n // 2 - 1, -1, -1):
        sift_down(items, n, i)

    # Phase 2: extract max n-1 times
    for end in range(n - 1, 0, -1):
        items[0], items[end] = items[end], items[0]  # move max to sorted region
        sift_down(items, end, 0)                     # restore heap on reduced range

def sift_down(items: list, heap_size: int, root: int) -> None:
    largest = root
    left  = 2 * root + 1
    right = 2 * root + 2

    if left < heap_size and items[left] > items[largest]:
        largest = left
    if right < heap_size and items[right] > items[largest]:
        largest = right

    if largest != root:
        items[root], items[largest] = items[largest], items[root]
        sift_down(items, heap_size, largest)   # recurse down
```

**Usage**
```python
arr = [12, 11, 13, 5, 6, 7]
heap_sort(arr)
print(arr)  # [5, 6, 7, 11, 12, 13]
```

**Step-by-step visualization**
```python
def heap_sort_verbose(items: list) -> None:
    n = len(items)
    for i in range(n // 2 - 1, -1, -1):
        sift_down(items, n, i)
    print(f"Max-heap built: {items}")

    for end in range(n - 1, 0, -1):
        items[0], items[end] = items[end], items[0]
        print(f"Extracted max {items[end]}, array: {items}")
        sift_down(items, end, 0)
```

---

## Gotchas

- **`heapify` builds the heap in O(n), not O(n log n).** The build phase starts from the last non-leaf (index n//2 - 1) and sifts down. This bottom-up approach is provably O(n) because lower nodes require fewer sift-down steps. Calling `heappush` n times would be O(n log n) — slower.
- **Heap sort is not stable.** The swap-to-end step in phase 2 can move equal elements past each other. There's no known practical way to make heap sort stable without extra space.
- **Cache performance is heap sort's real weakness.** Sift-down jumps between parent and child indices that are far apart in memory — index 0 to 2n+1 for large heaps. Quick sort accesses adjacent memory. In benchmarks, quick sort often beats heap sort by 2-3× despite identical Big-O.
- **The sorted region grows from the right.** Elements are placed at the end of the array as maxima are extracted. This is opposite to selection sort's direction but similar in structure.
- **Off-by-one on the build loop is a common implementation bug.** The last non-leaf is at index `n // 2 - 1`, not `n // 2`. Starting one index too high skips a node; starting too low wastes one no-op iteration but doesn't break correctness.

---

## Interview Angle

**What they're really testing:** Whether you can connect heaps as a data structure to heap sort as an algorithm — and whether you understand the two-phase structure without confusing it with a simple repeated-extract-min approach.

**Common question form:** "Implement heap sort," or "what sorting algorithm gives O(n log n) guaranteed with O(1) space?"

**The depth signal:** A junior knows heap sort is O(n log n). A senior explains *why* the build phase is O(n) despite calling sift-down n/2 times — most nodes are near the leaves and sift down very few levels, so the total work sums to O(n) by the geometric series argument. They also know why introsort uses heap sort as a fallback but not as a first choice, citing cache locality as the key factor.

---

## Related Topics

- [[algorithms/heap.md]] — The data structure heap sort is built on; sift-down is the core shared operation.
- [[algorithms/merge-sort.md]] — Also O(n log n) guaranteed, but stable and O(n) space instead of O(1).
- [[algorithms/quick-sort.md]] — Faster in practice; introsort uses quick sort first and heap sort as a fallback.
- [[algorithms/sorting-in-practice.md]] — Where heap sort fits in hybrid real-world sorting algorithms.

---

## Source

https://en.wikipedia.org/wiki/Heapsort

---

*Last updated: 2026-03-24*