# Merge Sort
> A divide-and-conquer sorting algorithm that splits an array in half, recursively sorts each half, and merges them back in O(n log n).

---

## When To Use It
Use merge sort when you need a guaranteed O(n log n) sort with stable ordering — equal elements preserve their original relative order. It's the algorithm of choice for sorting linked lists (no random access needed), external sorting (data too large to fit in memory), and any context where stability is required. Its downside is O(n) extra space for the merge step.

---

## Core Concept
Merge sort is the clearest example of divide and conquer. Split the array in half — O(1). Recursively sort each half — T(n/2) each. Merge the two sorted halves — O(n). The recurrence T(n) = 2T(n/2) + O(n) solves to O(n log n) by the Master Theorem. The merge step is the real work: walk two pointers across both halves, always picking the smaller element. Because you only move forward, one merge pass is O(n). There are log n levels of recursion, giving O(n log n) total.

---

## The Code

**Standard top-down merge sort**
```csharp
public static List<int> MergeSort(List<int> items)
{
    if (items.Count <= 1)
        return items;

    int mid = items.Count / 2;
    var left = MergeSort(items.Take(mid).ToList());
    var right = MergeSort(items.Skip(mid).ToList());
    return Merge(left, right);
}

public static List<int> Merge(List<int> left, List<int> right)
{
    var result = new List<int>();
    int i = 0, j = 0;
    while (i < left.Count && j < right.Count)
    {
        if (left[i] <= right[j])   // <= preserves stability
        {
            result.Add(left[i]);
            i++;
        }
        else
        {
            result.Add(right[j]);
            j++;
        }
    }
    result.AddRange(left.Skip(i));       // append remaining elements
    result.AddRange(right.Skip(j));
    return result;
}
```

**In-place merge sort (avoids extra allocation)**
```csharp
public static void MergeSortInPlace(List<int> items, int left, int right)
{
    if (left >= right)
        return;
    int mid = (left + right) / 2;
    MergeSortInPlace(items, left, mid);
    MergeSortInPlace(items, mid + 1, right);
    MergeInPlace(items, left, mid, right);
}

public static void MergeInPlace(List<int> items, int left, int mid, int right)
{
    var temp = items.GetRange(left, right - left + 1);
    int i = 0, j = mid - left + 1, k = left;
    while (i <= mid - left && j <= right - left)
    {
        if (temp[i] <= temp[j])
        {
            items[k] = temp[i]; i++;
        }
        else
        {
            items[k] = temp[j]; j++;
        }
        k++;
    }
    while (i <= mid - left)
    {
        items[k] = temp[i]; i++; k++;
    }
    while (j <= right - left)
    {
        items[k] = temp[j]; j++; k++;
    }
}
```

**Merge sort on a linked list — O(n log n), O(log n) space**
```csharp
public class ListNode
{
    public int val;
    public ListNode next;
    public ListNode(int val = 0, ListNode next = null)
    {
        this.val = val;
        this.next = next;
    }
}

public static ListNode SortList(ListNode head)
{
    if (head == null || head.next == null)
        return head;
    
    ListNode slow = head, fast = head.next;
    while (fast != null && fast.next != null)         // find midpoint
    {
        slow = slow.next;
        fast = fast.next.next;
    }
    ListNode mid = slow.next;
    slow.next = null;                  // split into two lists
    
    ListNode left = SortList(head);
    ListNode right = SortList(mid);
    return MergeLists(left, right);
}

public static ListNode MergeLists(ListNode l1, ListNode l2)
{
    var dummy = new ListNode(0);
    ListNode curr = dummy;
    while (l1 != null && l2 != null)
    {
        if (l1.val <= l2.val)
        {
            curr.next = l1; l1 = l1.next;
        }
        else
        {
            curr.next = l2; l2 = l2.next;
        }
        curr = curr.next;
    }
    curr.next = l1 ?? l2;
    return dummy.next;
}
```

**Count inversions using merge sort — O(n log n)**
```csharp
public static long CountInversions(List<int> items)
{
    if (items.Count <= 1)
        return 0;
    int mid = items.Count / 2;
    var left = items.Take(mid).ToList();
    var right = items.Skip(mid).ToList();
    long count = CountInversions(left) + CountInversions(right);
    
    int i = 0, j = 0, k = 0;
    while (i < left.Count && j < right.Count)
    {
        if (left[i] <= right[j])
        {
            items[k] = left[i]; i++;
        }
        else
        {
            items[k] = right[j]; j++;
            count += left.Count - i;    // all remaining left elements are > right[j]
        }
        k++;
    }
    
    while (i < left.Count)
        items[k++] = left[i++];
    while (j < right.Count)
        items[k++] = right[j++];
    
    return count;
}
```

---

## Gotchas

- **The merge step requires O(n) extra space.** There is no practical in-place merge that maintains O(n log n) time — the space cost is fundamental. Interviewers sometimes ask about this; the honest answer is: true in-place merge sort sacrifices either time or simplicity.
- **Stability depends on the merge condition.** Using `<=` (left wins ties) preserves stability. Using `<` makes it unstable. This is a one-character difference with real consequences.
- **Recursive merge sort uses O(log n) stack space.** Not O(n). Each level of recursion is one frame, and there are log n levels. This is often confused with the O(n) merge buffer.
- **Bottom-up merge sort avoids recursion entirely.** Start with subarrays of size 1, merge into size 2, then 4, etc. Same O(n log n) time, O(1) stack space. Useful when stack depth is a concern.
- **Merge sort on linked lists uses O(log n) space, not O(n).** The merge step doesn't need a buffer — it rewires pointers. This makes merge sort uniquely well-suited for linked list sorting.

---

## Interview Angle

**What they're really testing:** Whether you understand divide and conquer deeply enough to derive the complexity from the recurrence, and whether you know when stability and guaranteed O(n log n) matter.

**Common question form:** Sort a linked list, count inversions in an array, implement merge sort from scratch.

**The depth signal:** A junior implements merge sort correctly on an array. A senior derives T(n) = 2T(n/2) + O(n) → O(n log n) via the Master Theorem without looking it up, explains why linked list merge sort uses O(log n) not O(n) space, and knows the inversion-count trick — that left-wins-remaining-left is a piggyback on the merge step that costs nothing extra. They also know Timsort uses merge sort for large runs and why.

---

## Related Topics

- [[algorithms/quick-sort.md]] — The O(n log n) average-case alternative; faster in practice but not stable and not guaranteed.
- [[algorithms/heap-sort.md]] — Also O(n log n) guaranteed, in-place, but not stable and poor cache performance.
- [[algorithms/sorting-in-practice.md]] — How merge sort fits into real-world sorting (Timsort).
- [[algorithms/complexity-analysis.md]] — Master Theorem used to derive merge sort's O(n log n) complexity.

---

## Source

https://en.wikipedia.org/wiki/Merge_sort

---

*Last updated: 2026-03-24*