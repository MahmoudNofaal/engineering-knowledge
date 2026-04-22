# Merge Sort

> A divide-and-conquer sorting algorithm that splits an array in half, recursively sorts each half, and merges them back — guaranteed O(n log n), stable.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Divide-and-conquer: split, sort halves, merge |
| **Use when** | Stable sort required; sorting linked lists; external sort; guaranteed O(n log n) |
| **Avoid when** | Memory is constrained (O(n) extra space); in-place required |
| **C# version** | C# 1.0+; LINQ `OrderBy` uses a stable merge sort internally |
| **Namespace** | None — custom implementation |
| **Key types** | Recursive methods; `int lo`, `int hi`, `int mid` |

---

## When To Use It

Use merge sort when you need a guaranteed O(n log n) sort with stable ordering — equal elements preserve their original relative order. Classic use cases: sorting linked lists (no random access needed for merging), external sorting (data too large for memory), and any multi-key sort where stability matters. Its downside is O(n) extra space for the merge buffer. When stability is not required and in-place sorting is preferred, quicksort is faster in practice.

---

## Core Concept

Split the array in half — O(1). Recursively sort each half — T(n/2) each. Merge the two sorted halves back — O(n). The recurrence T(n) = 2T(n/2) + O(n) solves to O(n log n) by Master Theorem Case 2. The merge step is the real work: two pointers walk the halves, always picking the smaller element. Stability is preserved by using `<=` (left wins ties) in the merge comparison.

---

## Algorithm History

| Year | Development |
|---|---|
| 1945 | John von Neumann invents merge sort — first documented D&C sorting algorithm |
| 1948 | Used for early tape-based external sorting |
| 1970s | Formalised in Knuth's TAOCP Volume 3 |
| 1993 | Tim Peters creates Timsort (Python) — hybrid using merge sort for runs |
| 2009 | Java switches `Arrays.sort` for objects to Timsort (merge-sort based) |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Best case | O(n log n) | O(n) | Always the same — no adaptive behaviour |
| Average case | O(n log n) | O(n) | |
| Worst case | O(n log n) | O(n) | Guaranteed — unlike quicksort |
| Merge step | O(n) | O(n) | Requires a buffer of size n |
| Stack depth | O(log n) | O(log n) | Balanced splits, not O(n) |

**Allocation behaviour:** O(n) buffer for the merge step. Allocated once at the top level or per call depending on implementation. In bottom-up merge sort, allocate once for the entire sort.

**Benchmark notes:** Merge sort is ~2× slower than quicksort on arrays in practice due to worse cache behaviour (merge copies to/from a buffer). On linked lists, merge sort is competitive because it doesn't need random access. Timsort's advantage over pure merge sort is that it exploits existing sorted runs — O(n) best case for nearly-sorted input.

---

## The Code

**Scenario 1 — top-down merge sort**
```csharp
public static void MergeSort(int[] arr, int lo, int hi, int[] buffer)
{
    if (lo >= hi) return;
    int mid = lo + (hi - lo) / 2;
    MergeSort(arr, lo, mid, buffer);       // T(n/2)
    MergeSort(arr, mid + 1, hi, buffer);   // T(n/2)
    Merge(arr, lo, mid, hi, buffer);       // O(n)
}

private static void Merge(int[] arr, int lo, int mid, int hi, int[] buffer)
{
    Array.Copy(arr, lo, buffer, lo, hi - lo + 1); // copy segment to buffer
    int i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi)
        arr[k++] = buffer[i] <= buffer[j] ? buffer[i++] : buffer[j++]; // <= preserves stability
    while (i <= mid)  arr[k++] = buffer[i++];
    while (j <= hi)   arr[k++] = buffer[j++];
}
```

**Scenario 2 — merge sort on a linked list**
```csharp
public ListNode? SortList(ListNode? head)
{
    if (head?.Next == null) return head;

    // Find midpoint using fast/slow pointers
    ListNode slow = head, fast = head.Next;
    while (fast?.Next != null) { slow = slow.Next!; fast = fast.Next.Next; }
    ListNode mid = slow.Next!;
    slow.Next = null; // split into two lists

    return MergeLists(SortList(head), SortList(mid));
}

private ListNode? MergeLists(ListNode? l1, ListNode? l2)
{
    var dummy = new ListNode(0);
    var curr  = dummy;
    while (l1 != null && l2 != null)
    {
        if (l1.Val <= l2.Val) { curr.Next = l1; l1 = l1.Next; }
        else                  { curr.Next = l2; l2 = l2.Next; }
        curr = curr.Next;
    }
    curr.Next = l1 ?? l2;
    return dummy.Next;
}
```

**Scenario 3 — count inversions (piggyback on merge step)**
```csharp
public static long CountInversions(int[] arr, int lo, int hi, int[] buffer)
{
    if (lo >= hi) return 0;
    int mid  = lo + (hi - lo) / 2;
    long inv = CountInversions(arr, lo, mid, buffer) + CountInversions(arr, mid+1, hi, buffer);

    Array.Copy(arr, lo, buffer, lo, hi - lo + 1);
    int i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi)
    {
        if (buffer[i] <= buffer[j]) arr[k++] = buffer[i++];
        else { arr[k++] = buffer[j++]; inv += mid - i + 1; } // remaining left elements > buffer[j]
    }
    while (i <= mid)  arr[k++] = buffer[i++];
    while (j <= hi)   arr[k++] = buffer[j++];
    return inv;
}
```

**Scenario 4 — what NOT to do: using < instead of <= in merge (breaks stability)**
```csharp
// BAD: < in merge comparison — right element wins ties, breaking stability
// Elements with equal values from the RIGHT half appear before equal elements from LEFT
private static void MergeUnstable(int[] arr, int lo, int mid, int hi, int[] buf)
{
    Array.Copy(arr, lo, buf, lo, hi - lo + 1);
    int i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi)
        arr[k++] = buf[i] < buf[j] ? buf[i++] : buf[j++]; // BUG: < not <=, right wins ties
}

// GOOD: <= ensures left element wins ties — original relative order preserved
private static void MergeStable(int[] arr, int lo, int mid, int hi, int[] buf)
{
    Array.Copy(arr, lo, buf, lo, hi - lo + 1);
    int i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi)
        arr[k++] = buf[i] <= buf[j] ? buf[i++] : buf[j++]; // <= preserves stability
}
```

---

## Real World Example

The `AuditLogMergeService` in a distributed system collects sorted audit log chunks from multiple nodes and merges them into one chronologically ordered master log for compliance reporting. Each node emits a pre-sorted chunk; the service performs a k-way merge using a divide-and-conquer merge tree.

```csharp
public class AuditLogMergeService
{
    public record AuditEntry(DateTimeOffset Timestamp, string NodeId, string Event)
        : IComparable<AuditEntry>
    {
        public int CompareTo(AuditEntry? other) =>
            other == null ? 1 : Timestamp.CompareTo(other.Timestamp);
    }

    // D&C k-way merge: split list of sorted chunks, recurse, merge pairs.
    // Time: O(n log k) where n = total entries, k = number of chunks.
    public List<AuditEntry> MergeChunks(List<List<AuditEntry>> chunks)
    {
        if (chunks.Count == 0) return new List<AuditEntry>();
        return MergeRange(chunks, 0, chunks.Count - 1);
    }

    private List<AuditEntry> MergeRange(List<List<AuditEntry>> chunks, int lo, int hi)
    {
        if (lo == hi) return chunks[lo];
        int mid   = lo + (hi - lo) / 2;
        var left  = MergeRange(chunks, lo, mid);
        var right = MergeRange(chunks, mid + 1, hi);
        return MergeSorted(left, right);
    }

    private List<AuditEntry> MergeSorted(List<AuditEntry> a, List<AuditEntry> b)
    {
        var result = new List<AuditEntry>(a.Count + b.Count);
        int i = 0, j = 0;
        while (i < a.Count && j < b.Count)
        {
            // <= preserves stability: equal timestamps from left chunk come first
            if (a[i].Timestamp <= b[j].Timestamp) result.Add(a[i++]);
            else                                   result.Add(b[j++]);
        }
        result.AddRange(a.Skip(i));
        result.AddRange(b.Skip(j));
        return result;
    }
}
```

*The key insight: divide-and-conquer merge reduces k-way merge from O(n × k) (merge one at a time, naively) to O(n log k) by processing chunks in pairs up a binary tree. The stability guarantee ensures that within the same timestamp, entries from earlier-indexed nodes maintain their relative order — important for reproducible compliance reports.*

---

## Common Misconceptions

**"Merge sort is always O(n log n) so it's always the best choice"**
Quicksort is O(n log n) average and is 2–3× faster in practice on arrays due to better cache behaviour (in-place vs merge sort's copy step). Merge sort's guarantee is its advantage — use it when worst-case matters or stability is required. For general-purpose array sorting, prefer introsort (C#'s default).

**"The merge step requires a new array each time"**
A single buffer of size n allocated once is sufficient. Pass it as a parameter and copy the relevant segment into it before each merge. Re-allocating per call makes merge sort O(n log n) in allocations as well as time.

**"Linked list merge sort uses O(n) space"**
No — it uses O(log n) stack space (the recursion depth) and O(1) additional memory. The merge step rewires pointers without copying values. This is why merge sort is the preferred algorithm for sorting linked lists.

---

## Gotchas

- **Stability depends on `<=` in the merge comparison.** One character difference. Always document or test the stability requirement.
- **Recursive merge sort uses O(log n) stack space**, not O(n). Each level of recursion is one frame, and there are log n levels for balanced splits.
- **Bottom-up merge sort avoids recursion entirely.** Start with subarrays of size 1, merge to size 2, size 4, etc. Same O(n log n), O(1) stack. Useful when recursion depth is a concern.
- **`Array.Sort` in C# is unstable.** It uses an introsort (quicksort + heapsort hybrid). Use LINQ `OrderBy` for stable sorting — it uses a stable merge sort.

---

## Interview Angle

**What they're really testing:** Whether you understand D&C deeply enough to derive O(n log n) from the recurrence, and whether you know when stability and guaranteed worst-case matter.

**Common question forms:** Sort a linked list. Count inversions. Implement merge sort from scratch.

**The depth signal:** A senior derives T(n) = 2T(n/2) + O(n) → O(n log n) via Master Theorem, explains why linked list merge sort uses O(log n) not O(n) space, and knows the inversion-count trick. They also know `Array.Sort` is unstable and LINQ `OrderBy` is stable.

---

## Related Topics

- [[algorithms/sorting-algorithms/quick-sort.md]] — Faster in practice on arrays; unstable and not guaranteed O(n log n).
- [[algorithms/patterns/divide-and-conquer.md]] — Merge sort is the canonical D&C algorithm.
- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — How merge sort fits into Timsort.

---

## Source

https://en.wikipedia.org/wiki/Merge_sort

---

*Last updated: 2026-04-21*