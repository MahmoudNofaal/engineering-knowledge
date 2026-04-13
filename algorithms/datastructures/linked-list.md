# Linked List

> A sequence of nodes where each node holds a value and a pointer to the next node, with no contiguous memory requirement.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Node chain with pointer navigation |
| **Use when** | Frequent insert/delete at known positions |
| **Avoid when** | Index access or cache-friendly iteration needed |
| **C# version** | C# 2.0 (`LinkedList<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `LinkedList<T>`, `LinkedListNode<T>` |

---

## When To Use It

Use a linked list when you need O(1) insertions and deletions at known positions and you never need to jump to an element by index. It's the right structure when data size is unpredictable and you're frequently splicing, prepending, or removing nodes from both ends. The classic production use case is an LRU cache — the doubly linked list tracks access order and lets you promote or evict any node in O(1) once you hold a reference to it.

Avoid it whenever you need to access elements by index (that's O(n) — a walk from the head), iterate over large datasets in a tight loop (poor cache locality; each node pointer-chases to a random heap address), or need to search by value (also O(n) with no shortcut). For most sequential data needs, `List<T>` is the right default. Reach for `LinkedList<T>` only when the insertion/deletion pattern is proven to matter.

---

## Core Concept

Unlike arrays, linked list nodes can live anywhere in memory. Each node knows where the next one is via a pointer — that's the only navigation available. This makes inserting or removing a node at a **known location** O(1): you just rewire two pointers. But reaching node k means walking from the head one step at a time, so reads are O(n).

A **singly linked list** has one pointer per node (`next`). A **doubly linked list** adds a `prev` pointer, enabling O(1) removal when you already hold a reference to the node — no walking needed to find the predecessor. That's the key property that makes doubly linked lists the backbone of LRU cache implementations and .NET's own `LinkedList<T>`.

The design trade-off is intentional: sacrifice random access to gain cheap mutation at the edges and at any known interior position. Whenever your access pattern is dominated by "insert here" and "remove this" rather than "give me element k", a linked list wins.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | No generic linked list; `ArrayList` was the closest option |
| C# 2.0 | .NET 2.0 | `LinkedList<T>` and `LinkedListNode<T>` introduced |
| C# 5.0 | .NET 4.5 | No structural change; async patterns influence when to prefer queues over lists |
| C# 9.0 | .NET 5 | `record` types make immutable node wrappers cleaner |

*Before `LinkedList<T>`, developers either used `ArrayList` (non-generic, boxing overhead) or rolled their own node classes. The generic version eliminated boxing and added type safety.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Prepend / append | O(1) | `LinkedList<T>` maintains both `First` and `Last` pointers |
| Insert after known node | O(1) | Rewire two pointers; you must already hold the `LinkedListNode<T>` |
| Remove known node | O(1) | Doubly linked — no need to find the predecessor |
| Find by value | O(n) | Linear scan from head |
| Access by index | O(n) | No arithmetic shortcut; must walk |
| Memory per element | O(1) extra | Each node carries two pointers (~16 bytes on 64-bit) overhead over the value |

**Allocation behaviour:** Every node is a separate heap object. For a list of n elements you pay n allocations plus n pointer pairs. This fragments the heap and destroys cache locality — iterating a linked list of 100,000 integers is measurably slower than iterating an array of the same integers because each step is a pointer chase to a random address.

**Benchmark notes:** Below ~1,000 elements the difference between `LinkedList<T>` and `List<T>` for read-heavy patterns is irrelevant. The gap becomes painful above that threshold during iteration. Insertion at the front or middle, however, is where `LinkedList<T>` wins — `List<T>.Insert(0, x)` shifts every element and becomes O(n).

---

## The Code

**Node definition and basic singly linked list (custom)**
```csharp
public class ListNode
{
    public int Val;
    public ListNode Next;
    public ListNode(int val) { Val = val; }
}

// Build: 1 → 2 → 3
var head = new ListNode(1);
head.Next = new ListNode(2);
head.Next.Next = new ListNode(3);

// Traverse
for (var curr = head; curr != null; curr = curr.Next)
    Console.WriteLine(curr.Val);
```

**Reverse a linked list in-place — O(n) time, O(1) space**
```csharp
public static ListNode Reverse(ListNode head)
{
    ListNode prev = null;
    ListNode curr = head;
    while (curr != null)
    {
        ListNode next = curr.Next;   // save before overwriting
        curr.Next = prev;            // reverse the pointer
        prev = curr;
        curr = next;
    }
    return prev;                     // prev is the new head
}
```

**Detect a cycle — Floyd's two-pointer algorithm**
```csharp
public static bool HasCycle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast) return true;   // they met — cycle confirmed
    }
    return false;
}

// To also find the cycle start node:
public static ListNode CycleStart(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast)
        {
            slow = head;                  // reset one pointer to head
            while (slow != fast)
            {
                slow = slow.Next;
                fast = fast.Next;
            }
            return slow;                  // meeting point = cycle start
        }
    }
    return null;
}
```

**Merge two sorted linked lists — O(n + m)**
```csharp
public static ListNode MergeSorted(ListNode l1, ListNode l2)
{
    var dummy = new ListNode(0);          // dummy head eliminates edge cases
    var curr = dummy;
    while (l1 != null && l2 != null)
    {
        if (l1.Val <= l2.Val) { curr.Next = l1; l1 = l1.Next; }
        else                  { curr.Next = l2; l2 = l2.Next; }
        curr = curr.Next;
    }
    curr.Next = l1 ?? l2;                 // attach the remaining tail
    return dummy.Next;
}
```

**What NOT to do — and the fix**
```csharp
// BAD: deleting the head node without a dummy — special-case bug
public static ListNode DeleteValueBad(ListNode head, int val)
{
    if (head == null) return null;
    if (head.Val == val) return head.Next;    // easy to forget this branch
    var curr = head;
    while (curr.Next != null)
    {
        if (curr.Next.Val == val) { curr.Next = curr.Next.Next; break; }
        curr = curr.Next;
    }
    return head;
}

// GOOD: dummy head unifies the head-deletion case with all others
public static ListNode DeleteValueGood(ListNode head, int val)
{
    var dummy = new ListNode(0) { Next = head };
    var curr = dummy;
    while (curr.Next != null)
    {
        if (curr.Next.Val == val) curr.Next = curr.Next.Next;
        else curr = curr.Next;
    }
    return dummy.Next;
}
```

---

## Real World Example

A trading platform maintains an order book where buy and sell orders arrive and cancel continuously. Orders must be inserted in price-priority order and cancelled (removed) the instant a cancel message arrives — at volumes of tens of thousands of operations per second. An array-backed structure would require shifting on every insertion and cancellation. A doubly linked list with a `Dictionary<orderId, LinkedListNode<Order>>` gives O(1) cancel by looking up the node directly and rewiring its neighbours.

```csharp
public class OrderBook
{
    private readonly LinkedList<Order> _orders = new();
    // Maps orderId → its node so cancel is O(1)
    private readonly Dictionary<string, LinkedListNode<Order>> _index = new();

    public void AddOrder(Order order)
    {
        // Insert in price-descending order (buy side)
        var node = _orders.First;
        while (node != null && node.Value.Price >= order.Price)
            node = node.Next;

        LinkedListNode<Order> newNode = node == null
            ? _orders.AddLast(order)
            : _orders.AddBefore(node, order);

        _index[order.Id] = newNode;
    }

    public bool CancelOrder(string orderId)
    {
        if (!_index.TryGetValue(orderId, out var node))
            return false;

        _orders.Remove(node);          // O(1) — doubly linked, no walking
        _index.Remove(orderId);
        return true;
    }

    public Order? BestBid() => _orders.First?.Value;
}

public record Order(string Id, decimal Price, int Quantity);
```

*The critical insight here is the index dictionary: it bridges the O(n) find problem by letting the code skip navigation entirely — it holds a direct reference to the node, so `Remove` rewires two pointers and nothing more.*

---

## Common Misconceptions

**"LinkedList<T> is a good general-purpose replacement for List<T>"**
It's not. `List<T>` is the right default for sequential data in C#. `LinkedList<T>` only wins when your workload is dominated by insertion/deletion at known positions. For everything else — reads, searches, iteration — `List<T>` is faster because of cache locality and lower per-element overhead.

**"You can traverse a singly linked list backwards"**
You cannot without reversing it first or collecting all nodes into an array. A singly linked list has no `prev` pointer. If backward traversal is needed, either use a doubly linked list or accumulate nodes into a `Stack<T>` during a forward pass, then pop.

```csharp
// "Reverse" traversal on a singly linked list
var stack = new Stack<ListNode>();
for (var n = head; n != null; n = n.Next)
    stack.Push(n);
while (stack.Count > 0)
    Console.WriteLine(stack.Pop().Val);  // visits in reverse
```

**"Removing a node from a LinkedList<T> is always O(1)"**
Only if you already hold the `LinkedListNode<T>` reference. `LinkedList<T>.Remove(T value)` — which takes the value, not the node — does a linear scan to find the node first, making it O(n). Cache the node reference when you insert if you'll need to remove later.

---

## Gotchas

- **Always use a dummy head node for deletion logic.** Removing the actual head is a special case that breaks naive pointer code. A dummy node before the head eliminates that case — all deletions look the same regardless of position.

- **Never call `list.Remove(value)` when you need O(1) removal.** The overload that takes a value scans for it. The overload that takes a `LinkedListNode<T>` is truly O(1). Keep the node reference.

- **Cycle detection is invisible to naive traversal.** A `while (curr != null)` loop on a cyclic list runs forever. Always ask: can this input contain a cycle? Floyd's algorithm (slow/fast pointers) detects it in O(n) with O(1) space.

- **`LinkedList<T>` is not thread-safe.** Concurrent Add/Remove requires external locking. If you need concurrent FIFO/LIFO access, use `ConcurrentQueue<T>` or `ConcurrentStack<T>` instead.

- **Linked lists have poor cache performance at scale.** Nodes are scattered across the heap. For CPU-bound workloads iterating large lists, an array will outperform a linked list despite identical Big-O. Profile before reaching for `LinkedList<T>` on a hot path.

---

## Interview Angle

**What they're really testing:** Pointer manipulation under pressure — whether you can track `prev`, `curr`, and `next` simultaneously without losing the list, and whether you know the canonical patterns (dummy head, slow/fast pointers).

**Common question forms:**
- "Reverse a linked list" (iterative and recursive)
- "Detect a cycle and find where it starts"
- "Find the kth node from the end in one pass"
- "Merge two sorted linked lists"
- "Remove the nth node from the end"

**The depth signal:** A junior draws the pointer rewiring on paper and gets lost updating three variables at once. A senior immediately writes the dummy head, knows the two-pointer cycle detection by heart, and explains *why* slow/fast works — two pointers at different speeds must eventually land on the same node if a cycle exists, because the faster pointer laps the slower one. Seniors also know that the doubly linked list plus a hash map of node references is the O(1) LRU cache — one of the most common "design a data structure" interview questions.

**Follow-up questions to expect:**
- "How would you reverse a linked list recursively?" (Base case: single node; recursive step: fix the tail pointer)
- "What's the space complexity of your cycle detection?" (O(1) for Floyd's — vs O(n) for a hash set approach)
- "How would you implement an LRU cache?" (Dict<key, LinkedListNode> + DoublyLinkedList, move-to-front on access, evict tail on capacity)

---

## Related Topics

- [[algorithms/datastructures/lru-cache.md]] — The canonical production use of a doubly linked list combined with a hash map.
- [[algorithms/datastructures/stack.md]] — A stack can be implemented with a linked list for O(1) push/pop with no capacity limit.
- [[algorithms/datastructures/queue.md]] — Same: a queue as a linked list gives O(1) enqueue and dequeue from opposite ends.
- [[algorithms/datastructures/hash-table.md]] — Hash tables use linked lists for chaining to resolve collisions.
- [[algorithms/patterns/fast-slow-pointers.md]] — The two-pointer technique generalised beyond cycle detection.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1

---

*Last updated: 2026-04-12*