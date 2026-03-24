# Linked List
> A sequence of nodes where each node holds a value and a pointer to the next node, with no contiguous memory requirement.

---

## When To Use It
Use a linked list when you need O(1) insertions and deletions at known positions and don't need random index access. It's the right structure when data size is unpredictable and you're frequently splicing or removing nodes. Avoid it when you need index access or cache-friendly iteration — both are O(n) and slow in practice.

---

## Core Concept
Unlike arrays, linked list nodes can live anywhere in memory. Each node knows where the next one is via a pointer. This makes inserting or removing a node at a known location O(1) — just rewire two pointers. But there's no arithmetic shortcut to reach node k; you must walk from the head, making access O(n). Doubly linked lists add a previous pointer, enabling O(1) removal when you already hold a reference to the node. That's the key insight behind LRU cache implementations.

---

## The Code

**Node definition and basic singly linked list**
```python
class Node:
    def __init__(self, val: int):
        self.val = val
        self.next = None

class LinkedList:
    def __init__(self):
        self.head = None

    def prepend(self, val: int) -> None:  # O(1)
        node = Node(val)
        node.next = self.head
        self.head = node

    def append(self, val: int) -> None:   # O(n) — must walk to tail
        node = Node(val)
        if not self.head:
            self.head = node
            return
        curr = self.head
        while curr.next:
            curr = curr.next
        curr.next = node

    def delete(self, val: int) -> None:   # O(n) — must find the node first
        dummy = Node(0)
        dummy.next = self.head
        curr = dummy
        while curr.next:
            if curr.next.val == val:
                curr.next = curr.next.next
                break
            curr = curr.next
        self.head = dummy.next
```

**Reverse a linked list in-place — O(n) time, O(1) space**
```python
def reverse(head: Node) -> Node:
    prev = None
    curr = head
    while curr:
        nxt = curr.next   # save next before overwriting
        curr.next = prev  # reverse the pointer
        prev = curr
        curr = nxt
    return prev           # prev is new head
```

**Detect a cycle — Floyd's algorithm**
```python
def has_cycle(head: Node) -> bool:
    slow, fast = head, head
    while fast and fast.next:
        slow = slow.next
        fast = fast.next.next
        if slow == fast:
            return True
    return False
```

**Find middle node — slow/fast pointer**
```python
def find_middle(head: Node) -> Node:
    slow, fast = head, head
    while fast and fast.next:
        slow = slow.next
        fast = fast.next.next
    return slow  # slow is at the middle when fast reaches the end
```

---

## Gotchas

- **Always use a dummy head node for deletion logic.** Removing the actual head is a special case that breaks naive pointer code. A dummy node before the head eliminates that edge case entirely.
- **You cannot walk backwards in a singly linked list.** If a problem requires it, either use a doubly linked list or collect nodes into an array first. Trying to reverse-traverse a singly linked list means reversing it first — O(n) just to set up.
- **Cycle detection is invisible to naive traversal.** A `while curr` loop on a cyclic list runs forever. Always ask: can this input contain a cycle?
- **Python's garbage collector handles memory, but in C/C++ you leak it.** Every deleted node must be freed manually. In interviews, mentioning this in a C++ context signals production awareness.
- **Linked lists have poor cache performance.** Nodes are scattered in memory. For CPU-bound workloads iterating large lists, a contiguous array will outperform a linked list despite identical Big-O.

---

## Interview Angle

**What they're really testing:** Pointer manipulation under pressure — whether you can track prev/curr/next without losing the list.

**Common question form:** Reverse a linked list, detect a cycle, find the kth node from the end, merge two sorted lists.

**The depth signal:** A junior draws it out and gets lost in pointer updates. A senior immediately reaches for the dummy head pattern and the two-pointer (slow/fast) technique, and explains *why* slow/fast works — they move at different speeds, so if there's a cycle, they must eventually occupy the same node. Seniors also know that a doubly linked list with a hash map is the backbone of an O(1) LRU cache.

---

## Related Topics

- [[algorithms/stack.md]] — A stack can be implemented with a linked list for O(1) push/pop.
- [[algorithms/queue.md]] — Same: a queue implemented as a linked list gives O(1) enqueue and dequeue.
- [[algorithms/hash-table.md]] — Hash tables use linked lists for chaining to resolve collisions.

---

## Source

https://en.wikipedia.org/wiki/Linked_list

---

*Last updated: 2026-03-24*