# Bubble, Insertion & Selection Sort

> Three elementary O(n²) sorting algorithms — each with a distinct strategy — rarely used in production but important for understanding sorting fundamentals and for small or nearly-sorted arrays.

---

## Quick Reference

| Algorithm | Strategy | Stable | Best case | Use when |
|---|---|---|---|---|
| Bubble sort | Swap adjacent out-of-order pairs | Yes | O(n) with flag | Never in production |
| Insertion sort | Insert each element into sorted prefix | Yes | O(n) nearly sorted | Small n (< 32); nearly sorted |
| Selection sort | Find min, swap to front | No | O(n²) | Minimise writes |

---

## When To Use It

**Insertion sort** is the only one with real-world relevance: it's used internally by Timsort (Python, Java) and introsort (C#) for subarrays below ~16–32 elements, because its O(1) overhead beats the O(n log n) algorithms' constant factors at small n. It's also O(n) on nearly-sorted input — optimal for data that's "almost sorted."

**Bubble sort** and **selection sort** are primarily for teaching. Selection sort is occasionally useful when writes are very expensive (e.g., flash memory), because it makes exactly n-1 swaps regardless of input.

---

## Core Concept

All three are comparison-based, in-place, O(n²) worst case. They differ in what each pass accomplishes:

- **Bubble**: each pass floats the largest unsorted element to the end via adjacent swaps. With the swapped flag, it exits in O(n) if already sorted.
- **Insertion**: maintains a sorted prefix. Each new element is inserted into its correct position by shifting elements rightward — fewer writes than bubble sort, same comparisons.
- **Selection**: finds the minimum of the unsorted suffix and swaps it to the front. Exactly n-1 swaps regardless of input — minimises write count.

---

## Algorithm History

| Algorithm | Year | Development |
|---|---|---|
| Bubble sort | 1956 | Described by E.J. Isaac and R.C. Singleton |
| Insertion sort | 1945 | Implicit in early card-sorting machines |
| Selection sort | 1950s | First described in early computer science literature |
| Timsort (uses insertion) | 1993 | Tim Peters — Python's sort; uses insertion for small runs |

---

## Performance

| Algorithm | Best | Average | Worst | Space | Stable | Writes |
|---|---|---|---|---|---|---|
| Bubble | O(n) | O(n²) | O(n²) | O(1) | Yes | O(n²) |
| Insertion | O(n) | O(n²) | O(n²) | O(1) | Yes | O(n²) |
| Selection | O(n²) | O(n²) | O(n²) | O(1) | No | O(n) |

**Allocation behaviour:** All three are in-place — zero heap allocation beyond a few local variables.

**Benchmark notes:** At n < 32, insertion sort beats merge sort and quicksort due to lower overhead. Timsort uses a minimum run size of 32–64 elements and fills short runs with insertion sort before merging. For n > 50, all three O(n²) algorithms are significantly slower than O(n log n) alternatives.

---

## The Code

**Scenario 1 — bubble sort with early exit**
```csharp
public static void BubbleSort(int[] arr)
{
    int n = arr.Length;
    for (int i = 0; i < n - 1; i++)
    {
        bool swapped = false;
        for (int j = 0; j < n - i - 1; j++) // last i elements already sorted
        {
            if (arr[j] > arr[j + 1])
            {
                (arr[j], arr[j + 1]) = (arr[j + 1], arr[j]);
                swapped = true;
            }
        }
        if (!swapped) break; // already sorted — O(n) best case
    }
}
```

**Scenario 2 — insertion sort**
```csharp
public static void InsertionSort(int[] arr)
{
    for (int i = 1; i < arr.Length; i++)
    {
        int key = arr[i];
        int j   = i - 1;
        // Shift elements greater than key one position right
        while (j >= 0 && arr[j] > key)
        {
            arr[j + 1] = arr[j]; // shift right — not a swap (fewer writes than bubble)
            j--;
        }
        arr[j + 1] = key; // insert key into its correct position
    }
}
// On nearly-sorted data: inner while rarely executes → O(n) effective
```

**Scenario 3 — selection sort**
```csharp
public static void SelectionSort(int[] arr)
{
    int n = arr.Length;
    for (int i = 0; i < n - 1; i++)
    {
        int minIdx = i;
        for (int j = i + 1; j < n; j++)
            if (arr[j] < arr[minIdx]) minIdx = j;

        if (minIdx != i)
            (arr[i], arr[minIdx]) = (arr[minIdx], arr[i]); // at most n-1 swaps total
    }
}
// Exactly n-1 swaps regardless of input — minimum possible for a comparison-based sort
```

**Scenario 4 — what NOT to do: forgetting the swapped flag in bubble sort**
```csharp
// BAD: without the swapped flag, bubble sort always runs O(n²) — even on sorted input
public static void BubbleSortBad(int[] arr)
{
    int n = arr.Length;
    for (int i = 0; i < n - 1; i++)
        for (int j = 0; j < n - i - 1; j++)
            if (arr[j] > arr[j + 1])
                (arr[j], arr[j + 1]) = (arr[j + 1], arr[j]);
    // On a sorted array: does n(n-1)/2 comparisons, 0 swaps, returns correctly
    // but wastes all those comparisons — O(n²) when O(n) is achievable
}

// GOOD: the swapped flag enables O(n) early exit on sorted/nearly-sorted arrays
// See BubbleSort above. One boolean per outer loop — minimal overhead.
```

---

## Real World Example

The `TimsortRunExtender` shows how insertion sort is used inside Timsort to extend short natural runs to the minimum run size before merging. A "run" is a maximal ascending (or descending) sequence found in the input. If a run is shorter than `minRun` (typically 32), insertion sort extends it — exploiting insertion sort's O(n) performance on nearly-sorted data.

```csharp
public class TimsortRunExtender
{
    // Mimics Timsort's binary insertion sort for run extension.
    // Inserts arr[left..right] into arr[0..left-1] (already sorted).
    // Binary search finds the insertion point in O(log n); shift is still O(n).
    public static void BinaryInsertionSort(int[] arr, int left, int right)
    {
        for (int i = left + 1; i <= right; i++)
        {
            int key = arr[i];

            // Binary search for insertion point in arr[left..i-1]
            int lo = left, hi = i;
            while (lo < hi)
            {
                int mid = lo + (hi - lo) / 2;
                if (arr[mid] <= key) lo = mid + 1;
                else                 hi = mid;
            }

            // Shift arr[lo..i-1] right by one
            Array.Copy(arr, lo, arr, lo + 1, i - lo);
            arr[lo] = key; // insert
        }
    }

    // Identify a natural run starting at index start
    // Returns the end index of the run (inclusive)
    public static int FindNaturalRun(int[] arr, int start, int end)
    {
        if (start >= end) return start;
        int runEnd = start + 1;
        if (arr[runEnd] < arr[start])
        {
            // Descending run — extend and reverse
            while (runEnd < end && arr[runEnd + 1] < arr[runEnd]) runEnd++;
            Array.Reverse(arr, start, runEnd - start + 1);
        }
        else
        {
            // Ascending run
            while (runEnd < end && arr[runEnd + 1] >= arr[runEnd]) runEnd++;
        }
        return runEnd;
    }
}
```

*The key insight: Timsort never uses bubble or selection sort — it uses insertion sort for small runs because insertion sort has O(nk) performance when elements are at most k positions from their sorted position. On nearly-sorted data, k is small, making it practically O(n). This is why Timsort is O(n) on sorted input.*

---

## Common Misconceptions

**"Bubble sort is fine for small arrays"**
Insertion sort is always better than bubble sort for small arrays. Both are O(n²), but insertion sort makes fewer comparisons on average and does shifts instead of swaps — fewer memory writes, better cache behaviour. Timsort uses insertion sort internally, never bubble sort.

**"Selection sort is stable"**
No. Swapping the minimum to the front can move equal elements past each other. Example: [3a, 3b, 1] → swap 1 and 3a → [1, 3b, 3a] — the two 3s are now out of their original relative order.

**"These algorithms are only for teaching — no real-world relevance"**
Insertion sort is real-world relevant: it's used in Timsort and introsort for subarrays < 32 elements, which is a significant fraction of sorts in practice. Selection sort's O(n) write guarantee matters on write-expensive storage.

---

## Gotchas

- **Bubble sort without the `swapped` flag is always O(n²).** One boolean per outer pass enables O(n) best case. The flag is the entire point of "optimised" bubble sort.
- **Selection sort is not stable.** Equal elements can be reordered. Bubble sort and insertion sort are stable.
- **Insertion sort shifts, not swaps.** The inner loop copies `arr[j]` to `arr[j+1]` — not a full swap (which would require two writes). This is why insertion sort has fewer writes than bubble sort.
- **For n < 32, insertion sort often beats merge sort.** The O(n log n) algorithms have constant-factor overhead that dominates at small n. This is why introsort and Timsort switch to insertion sort for small subarrays.
- **Binary insertion sort reduces comparisons to O(n log n) but not writes.** Binary search finds the insertion point in O(log n), but shifting elements is still O(n) per insertion — overall O(n²) time. Used in Timsort where the constant matters.

---

## Interview Angle

**What they're really testing:** Whether you know which O(n²) algorithm is actually used in practice (insertion sort), why, and the difference between bubble's swapping and insertion's shifting.

**Common question forms:** "Implement insertion sort." "Which sorting algorithm would you use for a nearly-sorted array of 20 elements, and why?" "Which sort minimises writes?"

**The depth signal:** A junior recites all three implementations. A senior explains the trade-offs: insertion sort for nearly-sorted/small n (Timsort/introsort use it), selection sort for write-minimisation, bubble sort for nothing practical. They know Timsort uses insertion sort internally and why — O(nk) performance on k-nearly-sorted data.

**Follow-up questions to expect:**
- "Why does Timsort use insertion sort instead of merge sort for small subarrays?" → Merge sort's overhead (function calls, buffer allocation) dominates over the O(n log n) benefit at n < 32. Insertion sort's constant factor wins.
- "Is bubble sort ever better than insertion sort?" → No. Insertion sort dominates bubble sort on all inputs.

---

## Related Topics

- [[algorithms/sorting-algorithms/merge-sort.md]] — The O(n log n) stable sort Timsort uses for large runs.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — How insertion sort fits inside Timsort and introsort.
- [[algorithms/complexity/common-complexities.md]] — Why O(n²) is acceptable at small n but not at large n.

---

## Source

https://en.wikipedia.org/wiki/Insertion_sort

---

*Last updated: 2026-04-21*