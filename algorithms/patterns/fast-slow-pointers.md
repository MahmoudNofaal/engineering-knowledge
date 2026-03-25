# Fast & Slow Pointers
> Two pointers traversing the same structure at different speeds — slow moves one step, fast moves two — to detect cycles, find midpoints, and locate structural features without extra space.

---

## When To Use It
Use fast/slow pointers on linked lists or arrays when you need to detect a cycle, find the midpoint, find the kth element from the end, or detect a repeated value without extra space. It's the O(1) space alternative to storing visited nodes in a hash set. Don't use it when the problem requires tracking the full path — fast/slow only tells you that a cycle exists or where a specific position is, not what came before it.

---

## Core Concept
Slow advances one step per iteration; fast advances two. If a cycle exists, fast laps slow — they must eventually occupy the same node. If no cycle exists, fast reaches the end (null) first. The math: when slow has traveled k steps, fast has traveled 2k steps. If there's a cycle of length L, they meet when 2k - k = mL for some integer m — i.e., after k = mL steps, which is guaranteed to happen.

For finding midpoint: when fast reaches the end (null or null.next), slow is at the midpoint. This works because fast travels twice as far — when it's done, slow is halfway.

For kth from end: advance fast by k steps first, then advance both together. When fast reaches null, slow is exactly k nodes from the end.

---

## The Code

**Cycle detection — Floyd's algorithm**
```csharp
public bool HasCycle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast)
            return true;
    }
    return false;
}
```

**Find cycle entry point — where does the cycle begin?**
```csharp
public ListNode DetectCycle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
        if (slow == fast)
            break;
    }
    if (fast == null || fast.Next == null)
        return null;             // no cycle

    // reset slow to head; both now advance one step at a time
    slow = head;
    while (slow != fast)
    {
        slow = slow.Next;
        fast = fast.Next;
    }
    return slow;                 // meeting point is the cycle entry
}
```

**Find middle of linked list**
```csharp
public ListNode FindMiddle(ListNode head)
{
    ListNode slow = head, fast = head;
    while (fast != null && fast.Next != null)
    {
        slow = slow.Next;
        fast = fast.Next.Next;
    }
    return slow;                 // slow is at the middle (right-middle for even length)
}
```

**Kth node from end**
```csharp
public ListNode KthFromEnd(ListNode head, int k)
{
    ListNode slow = head, fast = head;
    for (int i = 0; i < k; i++)  // advance fast by k steps
    {
        if (fast == null)
            return null;         // k exceeds list length
        fast = fast.Next;
    }
    while (fast != null)
    {
        slow = slow.Next;
        fast = fast.Next;
    }
    return slow;                 // slow is now k from end
}
```

**Happy number — cycle detection on a sequence**
```csharp
public bool IsHappy(int n)
{
    Func<int, int> NextNum = x =>
    {
        int sum = 0;
        while (x > 0)
        {
            int digit = x % 10;
            sum += digit * digit;
            x /= 10;
        }
        return sum;
    };

    int slow = n, fast = NextNum(n);
    while (fast != 1 && slow != fast)
    {
        slow = NextNum(slow);
        fast = NextNum(NextNum(fast));
    }
    return fast == 1;            // cycle ends at 1 (happy) or loops (not happy)
}
```

**Find duplicate in array — treat values as pointers (Floyd on array)**
```csharp
public int FindDuplicate(int[] nums)
{
    // Treat nums[i] as a pointer to index nums[i].
    // A duplicate creates a cycle in this implicit linked list.
    int slow = nums[0], fast = nums[0];
    while (true)
    {
        slow = nums[slow];
        fast = nums[nums[fast]];
        if (slow == fast)
            break;
    }
    slow = nums[0];
    while (slow != fast)
    {
        slow = nums[slow];
        fast = nums[fast];
    }
    return slow;
}
```

---

## Gotchas

- **The cycle entry point proof requires a second phase.** After slow and fast meet inside the cycle, resetting slow to head and advancing both one step at a time causes them to meet at the cycle entry. This is a mathematical result — don't try to intuit it, just know it.
- **`fast and fast.next` both must be checked.** If you only check `fast`, accessing `fast.next.next` crashes when `fast.next` is null. The guard must be `while fast and fast.next`.
- **"Middle" has two definitions for even-length lists.** With `while fast and fast.next`, slow lands on the right-middle node. To land on the left-middle, use `while fast.next and fast.next.next`. Know which your problem requires.
- **The find-duplicate trick only works under specific constraints.** The array must have values in [1, n], length n+1, and exactly one duplicate. Treating values as pointers only forms a valid cycle under these conditions.
- **Fast/slow doesn't tell you the cycle length directly.** You need an extra pass to measure it: once the meeting point is found, hold one pointer and count steps until it returns to itself.

---

## Interview Angle

**What they're really testing:** Whether you know Floyd's algorithm as a space-O(1) alternative to a hash set for cycle detection, and whether you can apply the same pointer mechanic to midpoint and kth-from-end problems.

**Common question form:** Linked list cycle, linked list cycle II (entry point), middle of linked list, remove nth node from end, happy number, find duplicate number.

**The depth signal:** A junior detects a cycle with a hash set — O(n) space. A senior uses fast/slow for O(1) space and can explain the mathematical argument for why the second-phase pointer reset finds the cycle entry: the distance from head to cycle entry equals the distance from the meeting point to the cycle entry, so starting both at distance 0 from each causes them to arrive simultaneously. Applying the pattern to the find-duplicate problem (treating array values as implicit pointers) is the hardest extension and signals deep understanding.

---

## Related Topics

- [[algorithms/two-pointers.md]] — Fast/slow is a special case of two pointers on non-array structures.
- [[algorithms/linked-list.md]] — The primary structure fast/slow pointers are applied to.
- [[algorithms/hash-table.md]] — The O(n) space alternative; fast/slow trades space for conceptual complexity.

---

## Source

https://en.wikipedia.org/wiki/Cycle_detection#Floyd's_tortoise_and_hare

---

*Last updated: 2026-03-24*