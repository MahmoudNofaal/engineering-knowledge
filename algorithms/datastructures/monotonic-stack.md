# Monotonic Stack

> A stack that maintains elements in a consistent increasing or decreasing order by popping elements that violate the invariant as new ones arrive.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Stack with enforced ordering invariant |
| **Use when** | Next greater/smaller element, histogram max area |
| **Avoid when** | You need both next-greater and next-smaller simultaneously |
| **C# version** | C# 2.0+ (`Stack<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Stack<int>` (stores indices, not values) |

---

## When To Use It

Use a monotonic stack when a problem involves finding, for each element, the nearest element to its left or right that is strictly greater or smaller. The pattern converts an O(n²) naive double loop into O(n) by processing each element exactly once — each element is pushed once and popped at most once.

Classic problems: "next greater element," "previous smaller element," "daily temperatures" (next warmer day), "largest rectangle in histogram," "trapping rain water." The common thread is that each element needs to be compared against others in a sequential scan with a directional bias (nearest to the left/right).

Avoid it when the comparison isn't about immediate neighbours in value-space, when you need the k-th greater (use a heap), or when you need both directions simultaneously (run the algorithm twice — once left-to-right, once right-to-left).

---

## Core Concept

A **monotonic increasing stack** maintains elements from bottom to top in increasing order. When a new element arrives that is larger than the top, it's pushed. When it's smaller or equal, elements are popped until the invariant holds. The moment you pop an element, you've found its "next smaller element" — the element that caused the pop.

A **monotonic decreasing stack** is the mirror: elements are in decreasing order from bottom to top. When a new element is larger than the top, elements are popped — at the moment of pop, the new element is the "next greater element" for the popped element.

The O(n) time bound comes from the invariant that each element is pushed once and popped at most once across the entire run. No element is ever examined more than twice regardless of input size.

The critical implementation choice: **store indices, not values**. You need to know both the value (for comparison) and the position (for computing distances or filling result arrays).

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 2.0 | .NET 2.0 | `Stack<T>` — generic, O(1) push/pop |
| C# 10.0 | .NET 6 | `Stack<T>.TryPop` and `TryPeek` — cleaner guards |

*The monotonic stack is a pattern built on a plain `Stack<T>`, not a distinct data structure. Its power comes entirely from the invariant maintained during use.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Full algorithm (n elements) | O(n) | Each element pushed once, popped at most once |
| Space | O(n) | Stack holds at most n elements |

**Allocation behaviour:** Same as `Stack<T>` — an internal resizing array. Storing int indices (not objects) means no heap allocation per element for value types.

**Benchmark notes:** The O(n) bound is tight — on a fully sorted input (all elements increasing), no pops occur and all n elements remain on the stack at the end. On a fully reverse-sorted input, every new element immediately pops all preceding elements. Both cases are O(n) total operations.

---

## The Code

**Next greater element to the right — O(n)**
```csharp
public static int[] NextGreater(int[] nums)
{
    int n      = nums.Length;
    int[] res  = new int[n];
    Array.Fill(res, -1);              // default: no greater element
    var stack  = new Stack<int>();    // stores indices

    for (int i = 0; i < n; i++)
    {
        // Pop everything the current element is strictly greater than
        while (stack.Count > 0 && nums[stack.Peek()] < nums[i])
            res[stack.Pop()] = nums[i];
        stack.Push(i);
    }
    return res;
}
// NextGreater([2,1,2,4,3]) → [4,2,4,-1,-1]
```

**Previous smaller element to the left — O(n)**
```csharp
public static int[] PrevSmaller(int[] nums)
{
    int n      = nums.Length;
    int[] res  = new int[n];
    Array.Fill(res, -1);
    var stack  = new Stack<int>();

    for (int i = 0; i < n; i++)
    {
        // Pop everything that is >= current (we want strictly smaller)
        while (stack.Count > 0 && nums[stack.Peek()] >= nums[i])
            stack.Pop();
        res[i] = stack.Count > 0 ? nums[stack.Peek()] : -1;
        stack.Push(i);
    }
    return res;
}
// PrevSmaller([3,7,8,4,1,6]) → [-1,3,7,3,1,1]  ← wait, corrected:
// → [-1,3,7,3,-1,1]
```

**Largest rectangle in histogram — the definitive monotonic stack problem**
```csharp
public static int LargestRectangle(int[] heights)
{
    var stack   = new Stack<int>();   // monotonic increasing stack of indices
    int maxArea = 0;
    int n       = heights.Length;

    for (int i = 0; i <= n; i++)
    {
        int h = (i == n) ? 0 : heights[i];   // sentinel 0 flushes remaining stack
        while (stack.Count > 0 && heights[stack.Peek()] > h)
        {
            int height = heights[stack.Pop()];
            int width  = stack.Count == 0 ? i : i - stack.Peek() - 1;
            maxArea    = Math.Max(maxArea, height * width);
        }
        stack.Push(i);
    }
    return maxArea;
}
// LargestRectangle([2,1,5,6,2,3]) → 10  (5×2 rectangle at indices 2–3)
```

**Daily temperatures — next warmer day**
```csharp
public static int[] DailyTemperatures(int[] temps)
{
    int n     = temps.Length;
    int[] res = new int[n];           // default 0 = no warmer day found
    var stack = new Stack<int>();     // decreasing stack (top = smallest temp so far)

    for (int i = 0; i < n; i++)
    {
        while (stack.Count > 0 && temps[stack.Peek()] < temps[i])
        {
            int prev = stack.Pop();
            res[prev] = i - prev;     // distance to the next warmer day
        }
        stack.Push(i);
    }
    return res;
}
// DailyTemperatures([73,74,75,71,69,72,76,73]) → [1,1,4,2,1,1,0,0]
```

**What NOT to do — and the fix**
```csharp
// BAD: store values instead of indices — loses position information
var stackBad = new Stack<int>();
for (int i = 0; i < nums.Length; i++)
{
    while (stackBad.Count > 0 && stackBad.Peek() < nums[i])
    {
        stackBad.Pop();
        // Can't fill result[???] = nums[i] — don't know the popped element's index
    }
    stackBad.Push(nums[i]);
}

// GOOD: always store indices — access value as nums[stack.Peek()]
var stackGood = new Stack<int>();   // indices
for (int i = 0; i < nums.Length; i++)
{
    while (stackGood.Count > 0 && nums[stackGood.Peek()] < nums[i])
        result[stackGood.Pop()] = nums[i];   // index available
    stackGood.Push(i);
}
```

---

## Real World Example

A stock trading platform computes "stock span" — for each trading day, how many consecutive preceding days had a price less than or equal to today's price. This is the "previous greater element" problem. The naïve O(n²) approach scans backward for each day. The monotonic stack computes all spans in a single O(n) pass.

```csharp
public class StockSpanCalculator
{
    // For each price in the time series, computes the span (consecutive days ≤ today)
    public static int[] ComputeSpans(int[] prices)
    {
        int n      = prices.Length;
        int[] span = new int[n];
        // Stack stores indices of "blocking" days — days with price > current
        var stack  = new Stack<int>();

        for (int i = 0; i < n; i++)
        {
            // Pop all days whose price is ≤ today — they're "absorbed" into this span
            while (stack.Count > 0 && prices[stack.Peek()] <= prices[i])
                stack.Pop();

            // If stack is empty, all previous days are ≤ today
            span[i] = stack.Count == 0 ? i + 1 : i - stack.Peek();
            stack.Push(i);
        }
        return span;
    }
}

// Usage
int[] prices = { 100, 80, 60, 70, 60, 75, 85 };
int[] spans  = StockSpanCalculator.ComputeSpans(prices);
// spans = [1, 1, 1, 2, 1, 4, 6]
// Day 6 (85): spans 6 days back because all previous prices ≤ 85
```

*The key insight is what the stack represents: it's a history of "price barriers" — days whose price is higher than subsequent days. When today's price exceeds a barrier, that barrier is irrelevant for any future day, so we pop it. What remains on the stack is exactly the nearest day with a higher price.*

---

## Common Misconceptions

**"A monotonic stack is a separate data structure from a regular stack"**
It's not. A monotonic stack is a usage pattern — a plain `Stack<T>` used with a specific invariant. The monotonic property is maintained by the algorithm, not enforced by the data structure. Any stack can be used; the pop-before-push logic is what creates the monotonic behaviour.

**"The algorithm pops elements we'll need later"**
Once an element is popped because a new element is larger (for a decreasing stack), that element can never be the "previous greater" for any future element — because the current element is greater and is closer. The element is popped precisely because it's permanently answered.

**"Monotonic stacks only work for the 'next greater' problem"**
They solve a whole family of problems by adjusting two parameters: direction (left→right or right→left) and comparison (`<` vs `>`). "Next greater," "next smaller," "previous greater," "previous smaller" — all four are the same pattern with those two parameters flipped.

---

## Gotchas

- **Always store indices, not values.** You need the index to fill the result array and to compute distances. The value is accessible as `nums[stack.Peek()]`.

- **Remaining stack elements at the end have no answer.** After the loop, elements still on the stack have no next greater element (or whichever you're looking for). They should remain at the default value in your result array (typically -1 or 0).

- **For "largest rectangle in histogram," use a sentinel.** Appending a height of 0 at the end forces the stack to flush completely — otherwise bars that were never popped during the main loop would be missed. This is the cleanest way to handle the final flush.

- **Handle the strict vs non-strict inequality carefully.** "Next greater" uses `<` (pop when top is strictly less than current). "Next greater or equal" uses `<=`. Getting this wrong produces off-by-one errors in the result that only show up on inputs with duplicate values.

- **Running right-to-left gives "previous" answers.** The same algorithm run right-to-left (`for (int i = n-1; i >= 0; i--)`) finds the previous greater/smaller element instead of the next one — since "right" and "left" swap perspective.

---

## Interview Angle

**What they're really testing:** Whether you recognise that "for each element, find the nearest X" problems don't need O(n²) — and whether you know the monotonic stack pattern to solve them in O(n).

**Common question forms:**
- "Daily temperatures" (next warmer day — LeetCode 739)
- "Largest rectangle in histogram" (LeetCode 84)
- "Trapping rain water" (LeetCode 42)
- "Next greater element" (LeetCode 496, 503)
- "Remove k digits to make smallest number"

**The depth signal:** A junior writes the nested loop. A senior immediately recognises the "next greater" pattern, reaches for a monotonic stack, and implements it in O(n). The elite signal is solving "largest rectangle in histogram" — it's the hardest application of the pattern because the width calculation (`i - stack.Peek() - 1`) requires careful reasoning about what the stack represents at the moment of a pop.

**Follow-up questions to expect:**
- "Why is this O(n) and not O(n log n)?" (Each element is pushed once and popped once — O(2n) total operations)
- "What does the sentinel 0 do in the histogram problem?" (Forces remaining bars to be processed — prevents off-by-one at the end)
- "How would you find the previous smaller element instead?" (Same pattern, right-to-left traversal, or reverse the comparison)

---

## Related Topics

- [[algorithms/datastructures/stack.md]] — The underlying data structure; monotonic stack is a usage pattern on top of a plain stack.
- [[algorithms/datastructures/monotonic-queue.md]] — The deque-based analogue for sliding window min/max problems.
- [[algorithms/patterns/sliding-window.md]] — Monotonic queue is the tool when the window is bounded; monotonic stack when there's no window constraint.

---

## Source

https://leetcode.com/discuss/study-guide/2347639/a-comprehensive-guide-and-template-for-monotonic-stack-based-problems

---

*Last updated: 2026-04-12*