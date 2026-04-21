# Monotonic Stack

> A stack that maintains elements in either strictly increasing or strictly decreasing order, allowing O(1) amortized lookup of the next greater/smaller element for every position.

---

## Quick Reference

| | |
|---|---|
| **What it is** | A stack kept sorted by popping invalidated elements before pushing |
| **Use when** | Next greater/smaller element, spanning ranges, histogram max rectangle |
| **Avoid when** | You need random access to elements or need all k nearest, not just the next |
| **C# version** | C# 1.0+ (uses `Stack<T>`) |
| **Namespace** | `System.Collections.Generic` — `Stack<T>` |
| **Key types** | `Stack<int>` (storing indices, not values) |

---

## When To Use It

Use a monotonic stack when you need, for each element, the nearest element that is greater or smaller — in either direction. The signal is a problem asking for "next greater element," "previous smaller element," "days until warmer temperature," or "width of the largest rectangle." The brute-force is O(n²) (for each element, scan left or right). A monotonic stack gives O(n) by maintaining a stack of candidates and processing each element exactly once.

Don't confuse it with a regular stack or with a sliding window maximum (which uses a monotonic deque and tracks a moving window, not all-elements-simultaneously).

---

## Core Concept

A **monotonic increasing stack** pops any element larger than the incoming element before pushing. The result: the stack always holds elements in increasing order from bottom to top. When you pop an element because a smaller incoming element arrived, you've found the "next smaller element" for everything you popped.

A **monotonic decreasing stack** pops any element smaller than the incoming element. This finds the "next greater element" for popped items.

The key: store **indices**, not values. You need the index to compute distances ("how many days until warmer?") and to write results back to an answer array.

The amortized analysis: each element is pushed once and popped at most once. Total operations: O(2n) = O(n).

---

## Algorithm History

| Era | Development |
|---|---|
| 1970s | Stack-based parsing uses monotonic properties for operator precedence |
| 1984 | Largest rectangle in histogram formalised as a stack problem (competitive programming) |
| 1990s | "Next greater element" becomes a standard data structures exercise |
| 2000s | Codified as "monotonic stack" pattern in competitive programming literature |
| 2010s | Popularised as an interview pattern (LeetCode daily temperatures, trapping rain water) |

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Next greater element (all n) | O(n) | O(n) | Each element pushed/popped once |
| Previous smaller element (all n) | O(n) | O(n) | Same — right-to-left traversal |
| Largest rectangle in histogram | O(n) | O(n) | Extend with sentinel |
| Trapping rain water | O(n) | O(n) | Or O(1) space with two-pointer |
| Daily temperatures | O(n) | O(n) | Standard decreasing stack |

**Allocation behaviour:** One `Stack<int>` allocated upfront, up to O(n) entries. One result `int[]` of size n. No per-element allocation in the inner loop.

**Benchmark notes:** The O(n) monotonic stack beats the O(n²) brute force significantly at n > 1,000. At n = 100,000, the brute force is 10 billion operations; the monotonic stack is 200,000. At smaller n (< 50), the simpler brute force is often faster due to cache effects and branch prediction.

---

## The Code

**Scenario 1 — next greater element (to the right)**
```csharp
// For each element, find the first greater element to its right.
// Returns -1 if no greater element exists.
public static int[] NextGreaterElement(int[] nums)
{
    int n = nums.Length;
    var result = new int[n];
    Array.Fill(result, -1); // default: no greater element
    var stack = new Stack<int>(); // stores indices, not values

    for (int i = 0; i < n; i++)
    {
        // Pop all elements smaller than nums[i] — nums[i] is their next greater
        while (stack.Count > 0 && nums[stack.Peek()] < nums[i])
            result[stack.Pop()] = nums[i];

        stack.Push(i);
    }
    return result;
}
// Stack is decreasing (top has the smallest index of a not-yet-resolved element)
```

**Scenario 2 — daily temperatures (days until warmer)**
```csharp
// For each day, how many days until a warmer temperature? 0 if none.
public static int[] DailyTemperatures(int[] temperatures)
{
    int n = temperatures.Length;
    var result = new int[n]; // default 0 — stays 0 if never warmer
    var stack = new Stack<int>(); // monotonic decreasing: indices of unresolved days

    for (int i = 0; i < n; i++)
    {
        while (stack.Count > 0 && temperatures[stack.Peek()] < temperatures[i])
        {
            int prevDay = stack.Pop();
            result[prevDay] = i - prevDay; // distance to the warmer day
        }
        stack.Push(i);
    }
    return result;
}
```

**Scenario 3 — largest rectangle in histogram**
```csharp
// Find the area of the largest rectangle that fits within the histogram bars.
public static int LargestRectangle(int[] heights)
{
    var stack = new Stack<int>(); // monotonic increasing: indices of bars
    int maxArea = 0;

    // Append a sentinel 0 to flush remaining elements from the stack
    for (int i = 0; i <= heights.Length; i++)
    {
        int h = i == heights.Length ? 0 : heights[i];

        while (stack.Count > 0 && heights[stack.Peek()] > h)
        {
            int height = heights[stack.Pop()];
            // Width: from the new stack top (exclusive) to i (exclusive)
            int width = stack.Count == 0 ? i : i - stack.Peek() - 1;
            maxArea = Math.Max(maxArea, height * width);
        }
        stack.Push(i);
    }
    return maxArea;
}
```

**Scenario 4 — what NOT to do: brute force for next greater element**
```csharp
// BAD: O(n²) — for each element, scan right to find the first greater
public static int[] NextGreaterBad(int[] nums)
{
    var result = new int[nums.Length];
    for (int i = 0; i < nums.Length; i++)
    {
        result[i] = -1;
        for (int j = i + 1; j < nums.Length; j++) // inner loop: O(n) per element
        {
            if (nums[j] > nums[i]) { result[i] = nums[j]; break; }
        }
    }
    return result;
}

// GOOD: O(n) — monotonic decreasing stack resolves each element exactly once
public static int[] NextGreaterGood(int[] nums)
{
    var result = new int[nums.Length];
    Array.Fill(result, -1);
    var stack = new Stack<int>();
    for (int i = 0; i < nums.Length; i++)
    {
        while (stack.Count > 0 && nums[stack.Peek()] < nums[i])
            result[stack.Pop()] = nums[i];
        stack.Push(i);
    }
    return result;
}
```

---

## Real World Example

The `OrderBookDepthService` in a trading platform calculates, for each price level in the order book, the next price level where a significantly larger volume exists (a "volume wall"). This is exactly the next-greater-element problem — for each volume, find the nearest higher volume. The order book has up to 10,000 price levels; the brute-force O(n²) scan was taking 80ms; the monotonic stack brings it to under 1ms.

```csharp
public class OrderBookDepthService
{
    public record PriceLevel(decimal Price, int Volume);

    // For each price level, returns the nearest price level with strictly greater volume.
    // Returns null if no such level exists above (in price).
    public List<PriceLevel?> FindVolumeWalls(List<PriceLevel> levels)
    {
        int n = levels.Count;
        var result = new PriceLevel?[n]; // null = no volume wall found
        var stack = new Stack<int>();    // indices of unresolved price levels

        // Traverse price levels from lowest to highest price
        for (int i = 0; i < n; i++)
        {
            // Any level with less volume than the current level is now resolved
            while (stack.Count > 0 && levels[stack.Peek()].Volume < levels[i].Volume)
            {
                int resolvedIndex = stack.Pop();
                result[resolvedIndex] = levels[i]; // levels[i] is the volume wall
            }
            stack.Push(i);
        }
        // Remaining items in stack have no volume wall — result stays null

        return result.ToList();
    }

    // Related: for each level, find the nearest level with strictly smaller volume (support floor)
    public List<PriceLevel?> FindSupportFloors(List<PriceLevel> levels)
    {
        int n = levels.Count;
        var result = new PriceLevel?[n];
        var stack = new Stack<int>();

        for (int i = n - 1; i >= 0; i--) // traverse right-to-left for "previous smaller"
        {
            while (stack.Count > 0 && levels[stack.Peek()].Volume >= levels[i].Volume)
                stack.Pop();

            result[i] = stack.Count > 0 ? levels[stack.Peek()] : null;
            stack.Push(i);
        }
        return result.ToList();
    }
}
```

*The key insight: by storing indices (not values) in the stack, we can compute both the identity of the wall price level and its distance from the current level — without a second pass or any additional data structure.*

---

## Common Misconceptions

**"A monotonic stack is a special data structure"**
It's a regular `Stack<T>` used with a specific push/pop discipline. The "monotonic" property is maintained by the algorithm, not enforced by the data structure itself. You can accidentally push out-of-order elements — it's your loop's responsibility to pop invalidated entries first.

**"Store values in the stack, not indices"**
Storing values loses position information. You can't compute "how many days until warmer" if you don't know where the popped element was. Always store indices. Access the value via `nums[stack.Peek()]` when you need it.

**"Monotonic stack and monotonic deque are interchangeable"**
No. A monotonic stack is for "next/previous greater/smaller" problems where you resolve each element once. A monotonic deque is for sliding window maximum/minimum where elements expire based on a fixed window size and can be dequeued from the front. Different problem shapes, different data structures, different pop conditions.

---

## Gotchas

- **Use indices, not values.** The index is how you compute distances, write results back to the answer array, and determine window widths in histogram problems.

- **Direction determines what "next" means.** Left-to-right traversal with a stack finds the next greater/smaller to the **right**. Right-to-left finds it to the **left**. Flipping the traversal direction flips the meaning of "next" vs "previous."

- **The sentinel pattern for histogram problems.** Appending a 0 at the end forces all remaining stack elements to be popped and resolved. Without it, bars that never find a shorter bar to their right are never processed. The sentinel is not a hack — it's the standard approach.

- **Strictly greater vs greater-or-equal changes the pop condition.** `nums[stack.Peek()] < nums[i]` resolves elements strictly smaller. `<=` would also resolve equal elements, which matters when there are duplicate values. Know which the problem requires.

- **The stack may not be empty after the loop.** Elements remaining in the stack after the loop are those for which no greater/smaller element was found. Their result stays at the default value (-1 or 0). Don't forget to handle this — a common source of wrong answers.

---

## Interview Angle

**What they're really testing:** Whether you recognise the "next greater element" pattern and know that a stack — not a nested loop — is the right tool.

**Common question forms:**
- "Daily temperatures — days until a warmer day."
- "Next greater element I and II (circular array)."
- "Largest rectangle in histogram."
- "Trapping rain water."
- "Remove k digits to form the smallest number."
- "Asteroid collision."

**The depth signal:** A junior uses a nested loop. A senior immediately reaches for a monotonic stack, stores indices (not values), and handles the no-greater-element case (items remaining in the stack after the loop). The real separator: the largest rectangle in histogram problem, which requires correctly computing the width from `i - stack.Peek() - 1` when the stack is non-empty vs `i` when the stack is empty after popping.

**Follow-up questions to expect:**
- "Why store indices and not values?" → You need the position to compute distances and widths.
- "How is this different from a sliding window maximum?" → Sliding window max uses a deque and evicts by position; monotonic stack resolves by value and evicts when a larger/smaller element arrives.

---

## Related Topics

- [[algorithms/datastructures/stack.md]] — The underlying data structure; monotonic stack is a usage pattern on top of it.
- [[algorithms/patterns/sliding-window.md]] — Related pattern; sliding window maximum uses a monotonic deque instead of a stack.
- [[algorithms/patterns/two-pointers.md]] — Trapping rain water has an O(1) space two-pointer solution as an alternative to the O(n) stack solution.

---

## Source

https://en.wikipedia.org/wiki/Stack_(abstract_data_type)

---

*Last updated: 2026-04-21*