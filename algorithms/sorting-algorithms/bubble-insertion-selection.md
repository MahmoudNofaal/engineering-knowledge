# Bubble, Insertion & Selection Sort
> Three elementary O(n²) sorting algorithms that trade efficiency for simplicity, each with a distinct strategy.

---

## When To Use It
These algorithms are rarely used in production — use your language's built-in sort instead. The exception is insertion sort on small or nearly-sorted arrays, where its O(n) best-case and low overhead beat O(n log n) algorithms in practice. Timsort (Python, Java) uses insertion sort internally for small subarrays for exactly this reason. Know all three for interviews; use insertion sort if you ever need to implement sorting manually.

---

## Core Concept
All three are comparison-based, in-place, and O(n²) worst-case. The difference is *what they do each pass*:

- **Bubble sort** repeatedly swaps adjacent elements that are out of order. After each pass, the largest unsorted element bubbles to its correct position at the end. Slow, lots of swaps, no real advantage over the other two.
- **Selection sort** finds the minimum of the unsorted portion and swaps it to the front. Exactly n-1 swaps total — useful when writes are expensive. Otherwise unremarkable.
- **Insertion sort** takes one element at a time and inserts it into its correct position in the already-sorted left portion. Online algorithm — it can sort a stream of data as it arrives. O(n) on nearly-sorted input.

---

## The Code

**Bubble sort**
```python
def bubble_sort(items: list) -> list:
    n = len(items)
    for i in range(n):
        swapped = False
        for j in range(0, n - i - 1):         # last i elements already sorted
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
                swapped = True
        if not swapped:
            break                              # early exit if already sorted
    return items
```

**Selection sort**
```python
def selection_sort(items: list) -> list:
    n = len(items)
    for i in range(n):
        min_idx = i
        for j in range(i + 1, n):
            if items[j] < items[min_idx]:
                min_idx = j
        items[i], items[min_idx] = items[min_idx], items[i]  # at most n-1 swaps total
    return items
```

**Insertion sort**
```python
def insertion_sort(items: list) -> list:
    for i in range(1, len(items)):
        key = items[i]
        j = i - 1
        while j >= 0 and items[j] > key:  # shift right to make room
            items[j + 1] = items[j]
            j -= 1
        items[j + 1] = key                # insert in correct position
    return items
```

**Comparison of all three**
```python
import random, time

data = list(range(5000, 0, -1))  # worst case: reverse sorted

for fn in [bubble_sort, selection_sort, insertion_sort]:
    arr = data.copy()
    start = time.time()
    fn(arr)
    print(f"{fn.__name__}: {time.time() - start:.4f}s")
# All ~same on reverse sorted; insertion sort wins on nearly-sorted
```

---

## Gotchas

- **Bubble sort's early-exit optimization is often forgotten.** Without the `swapped` flag, bubble sort always runs O(n²) even on a sorted input. With it, best case is O(n). This distinction matters in interviews.
- **Selection sort is not stable.** Swapping the minimum to the front can move equal elements past each other. Bubble sort and insertion sort are stable. Stability matters when sorting by multiple keys.
- **Insertion sort's inner loop does shifts, not swaps.** Shifts move one element per iteration; a swap would move two. This is why insertion sort does fewer writes than bubble sort — important on write-expensive storage.
- **All three are in-place with O(1) extra space.** This is sometimes their only advantage over merge sort in memory-constrained environments.
- **"Nearly sorted" is insertion sort's sweet spot.** If an array has at most k elements out of place, insertion sort runs in O(nk). For k=1 or k=2, this is essentially O(n).

---

## Interview Angle

**What they're really testing:** Whether you understand why these algorithms exist and when (if ever) to prefer them — not whether you can implement them from memory.

**Common question form:** "Implement insertion sort," or "which sorting algorithm would you use for a nearly-sorted array of 100 elements, and why?"

**The depth signal:** A junior memorizes the implementations. A senior explains the trade-offs: insertion sort for small/nearly-sorted data, selection sort when minimizing writes matters, and that Timsort uses insertion sort internally on subarrays under ~64 elements precisely because the constant factors beat merge sort at small n. They also know that stable vs unstable is a real distinction with real consequences when sorting composite keys.

---

## Related Topics

- [[algorithms/merge-sort.md]] — The O(n log n) stable sort that supersedes these for large input.
- [[algorithms/sorting-in-practice.md]] — When and why built-in sorts use these algorithms internally.
- [[algorithms/complexity-analysis.md]] — Understanding why O(n²) is acceptable at small n but not at large n.

---

## Source

https://en.wikipedia.org/wiki/Insertion_sort

---

*Last updated: 2026-03-24*