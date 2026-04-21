# Fast & Slow Pointers

> Two pointers traversing the same structure at different speeds — slow moves one step, fast moves two — to detect cycles, find midpoints, and locate structural features without extra space.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Two pointers at 1× and 2× speed on a sequence |
| **Use when** | Linked list cycle detection, midpoint, kth from end, happy number |
| **Avoid when** | You need the full path through the cycle, not just its existence |
| **C# version** | C# 1.0+ (pure pointer logic, no language feature) |
| **Namespace** | None — operates on `ListNode` references or array indices |
| **Key types** | `ListNode slow`, `ListNode fast` (or `int slow`, `int fast` for arrays) |

---

## When To Use It

Use fast/slow pointers on linked lists or arrays when you need to detect a cycle, find the midpoint, find the kth element from the end, or detect a repeated value without extra space. It's the O(1) space alternative to storing visited nodes in a `HashSet`. Don't use it when you need to track the full path — fast/slow only tells you that a cycle exists or where a specific position is, not what came before it.

---

## Core Concept

Slow advances one step per iteration; fast advances two. If a cycle exists, fast laps slow — they must eventually occupy the same node. If no cycle exists, fast reaches the end (null) first. The math: when slow has traveled k steps, fast has traveled 2k steps. If there's a cycle of length L, they meet when 2k − k = mL for some integer m — after k = mL steps, guaranteed.

For finding the cycle entry point, a second phase is required: after the meeting point is found inside the cycle, reset slow to the head. Advance both one step at a time. They meet at the cycle entry. This works because the distance from head to cycle entry equals the distance from meeting point to cycle entry — a result of the modular arithmetic of the cycle.

For finding the midpoint: when fast reaches null (or null.next), slow is at the midpoint. Fast travels twice as far — when it's done, slow is exactly halfway.

---

## Algorithm History

| Year | Event |
|---|---|
| 1967 | Robert Floyd publishes cycle detection algorithm — "tortoise and hare" |
| 1980s | Richard Brent's variant improves constant factors |
| 1990s | Applied to pseudorandom number generator cycle detection |
| 2000s | Adopted as canonical interview pattern for linked list problems |
| 2010s | Extended to array problems — find duplicate, happy number |

*Floyd's original paper was about detecting cycles in function iteration sequences. The linked-list application came much later.*

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Cycle detection | O(n) | O(1) | vs O(n) time + O(n) space with HashSet |
| Cycle entry point | O(n) | O(1) | Two phases, both O(n) |
| Find midpoint | O(n) | O(1) | One pass |
| kth node from end | O(n) | O(1) | One pass with k-step head start |
| Find duplicate (array) | O(n) | O(1) | Requires values in [1, n], length n+1 |

**Allocation behaviour:** Zero allocation. Works entirely with existing references or indices. The HashSet alternative allocates O(n) heap memory — fast/slow is the drop-in replacement when space is the constraint.

**Benchmark notes:** For small lists (< 100 nodes), the HashSet is often faster in practice due to branch-prediction-friendly code. Fast/slow matters when memory is constrained or when the list is large enough that HashSet allocation causes GC pressure.

---

## The Code

**Scenario 1 — cycle detection**
```csharp
public bool HasCycle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast) return true; // same node reference = cycle
    }
    return false;
}
```

**Scenario 2 — cycle entry point (where does the cycle begin?)**
```csharp
public ListNode DetectCycle(ListNode head)
{
    ListNode slow = head, fast = head;

    // Phase 1: find meeting point inside the cycle
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast) break;
    }
    if (fast == null || fast.Next == null) return null; // no cycle

    // Phase 2: reset slow to head; advance both one step at a time
    // They meet at the cycle entry — mathematical guarantee
    slow = head;
    while (slow != fast)
    {
        slow = slow.Next;
        fast = fast.Next;
    }
    return slow;
}
```

**Scenario 3 — find middle of linked list**
```csharp
public ListNode FindMiddle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
    }
    // For even length: lands on right-middle node.
    // To get left-middle: use while (fast.Next != null && fast.Next.Next != null)
    return slow;
}
```

**Scenario 4 — what NOT to do: HashSet for cycle detection when space matters**
```csharp
// BAD: O(n) extra space — unnecessary when we only need to know IF a cycle exists
public bool HasCycleBad(ListNode head)
{
    var visited = new HashSet<ListNode>();
    while (head != null)
    {
        if (!visited.Add(head)) return true; // Add returns false if already present
        head = head.Next;
    }
    return false;
}

// GOOD: O(1) space — Floyd's algorithm
public bool HasCycleGood(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast?.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast) return true;
    }
    return false;
}
// Note: use HashSet when you need the FULL PATH — fast/slow only tells you a cycle exists.
```

---

## Real World Example

The `ObjectGraphValidator` in a serialization library checks whether a data model object graph has circular references before attempting to serialize. The library previously used a `HashSet<object>` to track visited objects — this caused measurable GC pressure on large graphs (10,000+ nodes) during bulk API response serialization. The fast/slow approach eliminates all allocations for the common case (no cycle).

```csharp
public class ObjectGraphValidator
{
    // Treats the object graph as an implicit linked list by following
    // the first navigable reference property at each node.
    // Full circular reference detection (any reference, not just first-child)
    // still requires HashSet — this is the fast path for list-shaped graphs.

    public static bool HasCircularReference(ILinkedNode head)
    {
        if (head == null) return false;

        ILinkedNode slow = head;
        ILinkedNode fast = head;

        while (fast?.Next != null)
        {
            slow = slow.Next;
            fast = fast.Next.Next;

            if (ReferenceEquals(slow, fast))
            {
                LogCircularReference(slow);
                return true;
            }
        }
        return false;
    }

    public static ILinkedNode FindCycleEntry(ILinkedNode head)
    {
        ILinkedNode slow = head, fast = head;

        while (fast?.Next != null)
        {
            slow = slow.Next;
            fast = fast.Next.Next;
            if (ReferenceEquals(slow, fast)) break;
        }

        if (fast?.Next == null) return null; // no cycle

        slow = head;
        while (!ReferenceEquals(slow, fast))
        {
            slow = slow.Next;
            fast = fast.Next;
        }
        return slow; // returns the node where the cycle originates
    }

    private static void LogCircularReference(ILinkedNode node) =>
        Console.Error.WriteLine($"[ObjectGraphValidator] Circular reference detected at node: {node}");
}

public interface ILinkedNode
{
    ILinkedNode Next { get; }
}
```

*The key insight: `ReferenceEquals` is the correct comparison — we're detecting pointer equality (same object in memory), not value equality. A `==` override would give false positives on value-equal but distinct objects.*

---

## Common Misconceptions

**"Fast/slow tells you the cycle length"**
It doesn't directly — it tells you a cycle exists and where it starts. To measure cycle length, hold one pointer at the meeting point and count steps until it returns to itself. That's an extra O(L) pass, where L is the cycle length.

**"The phase-2 pointer reset is a heuristic"**
It's a mathematical guarantee, not a trick. The distance from head to cycle entry equals the distance from meeting point to cycle entry (modulo cycle length). Resetting slow to head and advancing both one step causes them to arrive at the entry simultaneously — always. Trust the proof; don't try to intuit it.

**"For even-length lists, slow lands on the middle"**
It depends on the loop condition. `while (fast != null && fast.Next != null)` lands slow on the right-middle node for even-length lists. `while (fast.Next != null && fast.Next.Next != null)` lands it on the left-middle. Know which your problem needs — merge sort on a linked list usually needs the left-middle so the split is even.

---

## Gotchas

- **`fast != null && fast.Next != null` both must be checked.** If you only check `fast`, accessing `fast.Next.Next` throws a `NullReferenceException` when `fast.Next` is null. Always guard both.

- **The phase-2 cycle-entry detection only works if phase 1 found a meeting point.** If you break out of the loop because `fast` reached null (no cycle), skipping directly to phase 2 will produce wrong results. Always check `if (fast == null || fast.Next == null) return null` before starting phase 2.

- **The find-duplicate array trick has strict preconditions.** Values must be in [1, n], array length must be n+1, and there must be exactly one duplicate. Treating arbitrary array values as next-pointers only produces a valid cycle under these conditions. Don't apply it to general arrays.

- **Using `==` instead of `ReferenceEquals` on objects.** For `ListNode` structs or objects with value-equality overrides, `==` may give false positives. Use `ReferenceEquals` when comparing node identity in cycle detection.

- **Fast/slow doesn't reconstruct the cycle path.** If you need to know which nodes are in the cycle (not just the entry), you need a HashSet of nodes from the entry point around the cycle. Fast/slow gives you the entry; walking from there to the meeting point gives you the cycle contents.

---

## Interview Angle

**What they're really testing:** Whether you know Floyd's algorithm as a space-O(1) alternative to a HashSet for cycle detection, and whether you can apply the same pointer mechanic to midpoint and kth-from-end problems.

**Common question forms:**
- "Detect a cycle in a linked list."
- "Find where the cycle begins."
- "Find the middle of a linked list."
- "Remove the nth node from the end."
- "Is this a happy number?"

**The depth signal:** A junior detects a cycle with a HashSet — O(n) space. A senior uses fast/slow for O(1) space and explains the mathematical argument for why the phase-2 reset finds the cycle entry. Applying the pattern to the find-duplicate array problem (treating array values as implicit pointers) is the hardest extension and signals genuine depth.

**Follow-up questions to expect:**
- "What if you also need to know the cycle length?" → Hold one pointer at the meeting point, advance the other until it returns — count the steps.
- "Why does resetting slow to head work in phase 2?" → Distance from head to entry = distance from meeting point to entry (mod cycle length). Be ready to sketch the proof.

---

## Related Topics

- [[algorithms/patterns/two-pointers.md]] — Fast/slow is a specialised two-pointer pattern on non-array structures.
- [[algorithms/datastructures/linked-list.md]] — The primary structure fast/slow pointers are applied to.
- [[algorithms/datastructures/hash-table.md]] — The O(n) space alternative; fast/slow trades space for conceptual complexity.

---

## Source

https://en.wikipedia.org/wiki/Cycle_detection#Floyd's_tortoise_and_hare

---

*Last updated: 2026-04-21*