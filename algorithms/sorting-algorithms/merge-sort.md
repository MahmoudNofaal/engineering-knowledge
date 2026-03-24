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
```python
def merge_sort(items: list) -> list:
    if len(items) <= 1:
        return items

    mid = len(items) // 2
    left  = merge_sort(items[:mid])
    right = merge_sort(items[mid:])
    return merge(left, right)

def merge(left: list, right: list) -> list:
    result = []
    i = j = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:   # <= preserves stability
            result.append(left[i])
            i += 1
        else:
            result.append(right[j])
            j += 1
    result.extend(left[i:])       # append remaining elements
    result.extend(right[j:])
    return result
```

**In-place merge sort (avoids extra allocation)**
```python
def merge_sort_inplace(items: list, left: int, right: int) -> None:
    if left >= right:
        return
    mid = (left + right) // 2
    merge_sort_inplace(items, left,    mid)
    merge_sort_inplace(items, mid + 1, right)
    merge_inplace(items, left, mid, right)

def merge_inplace(items: list, left: int, mid: int, right: int) -> None:
    temp = items[left:right + 1]
    i, j, k = 0, mid - left + 1, left
    while i <= mid - left and j <= right - left:
        if temp[i] <= temp[j]:
            items[k] = temp[i]; i += 1
        else:
            items[k] = temp[j]; j += 1
        k += 1
    while i <= mid - left:
        items[k] = temp[i]; i += 1; k += 1
    while j <= right - left:
        items[k] = temp[j]; j += 1; k += 1
```

**Merge sort on a linked list — O(n log n), O(log n) space**
```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

def sort_list(head: ListNode) -> ListNode:
    if not head or not head.next:
        return head
    slow, fast = head, head.next
    while fast and fast.next:         # find midpoint
        slow = slow.next
        fast = fast.next.next
    mid = slow.next
    slow.next = None                  # split into two lists
    left  = sort_list(head)
    right = sort_list(mid)
    return merge_lists(left, right)

def merge_lists(l1: ListNode, l2: ListNode) -> ListNode:
    dummy = ListNode(0)
    curr = dummy
    while l1 and l2:
        if l1.val <= l2.val:
            curr.next = l1; l1 = l1.next
        else:
            curr.next = l2; l2 = l2.next
        curr = curr.next
    curr.next = l1 or l2
    return dummy.next
```

**Count inversions using merge sort — O(n log n)**
```python
def count_inversions(items: list) -> int:
    if len(items) <= 1:
        return 0
    mid = len(items) // 2
    left, right = items[:mid], items[mid:]
    count = count_inversions(left) + count_inversions(right)
    i = j = k = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            items[k] = left[i]; i += 1
        else:
            items[k] = right[j]; j += 1
            count += len(left) - i    # all remaining left elements are > right[j]
        k += 1
    items[k:] = left[i:] or right[j:]
    return count
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