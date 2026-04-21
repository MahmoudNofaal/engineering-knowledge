# Two Pointers

> A technique that uses two indices moving through a data structure — often toward each other or at different speeds — to solve problems in O(n) that would otherwise require O(n²).

---

## Quick Reference

| | |
|---|---|
| **What it is** | Two indices eliminating nested loops |
| **Use when** | Sorted array, find pair/triplet, in-place partition |
| **Avoid when** | Unsorted data with no sort step, non-sequential access needed |
| **C# version** | C# 1.0+ (no language feature — pure index logic) |
| **Namespace** | None — works on `int[]`, `List<T>`, `string` |
| **Key types** | `int lo`, `int hi`, `int slow`, `int fast` |

---

## When To Use It

Use two pointers on sorted arrays or when processing pairs, triplets, or subarrays. The signal is a brute-force solution with nested loops that you need to reduce to a single pass. Also applies to linked lists (detect cycles, find midpoint, merge). Don't use it on unsorted data where the pointer movement logic would be undefined — sort first (O(n log n)) or reach for a hash map (O(n) time, O(n) space) instead. Two pointers is usually the O(n) answer that beats the hash map when you can sort.

---

## Core Concept

Two pointers eliminates the inner loop by using the sorted order (or structure) to make informed decisions about which pointer to advance. When the current pair gives too small a sum, move the left pointer right to increase it. Too large, move the right pointer left to decrease it. Each step either finds the answer or eliminates a candidate that can't possibly work — so you never need to revisit. The total movement across both pointers is O(n), giving a single-pass O(n) solution.

There are two distinct variants. The **converging** variant starts lo at 0 and hi at the end, moving toward each other — used for pair/triplet sum problems. The **slow/fast** variant uses a trailing write pointer (slow) and a leading read pointer (fast) moving in the same direction — used for in-place deduplication and partitioning. Don't conflate them; the movement logic is completely different.

---

## Algorithm History

| Introduced | Context | Notes |
|---|---|---|
| 1970s | Competitive programming | Informal technique predating formal literature |
| 1980s | Donald Knuth's TAOCP | Formalized as "scanning from both ends" for sorted arrays |
| 1990s | Interview culture | Became a canonical O(n) pattern for pair-sum problems |
| 2000s | LeetCode era | Extended to three-sum, container with most water, trapping rain water |

*The pattern has no single inventor — it emerged from the observation that sorted order lets you make provably safe eliminations.*

---

## Performance

| Operation | Time | Space | Notes |
|---|---|---|---|
| Find pair with target sum (sorted) | O(n) | O(1) | Single pass, no extra structure |
| Three sum | O(n²) | O(1) | Outer loop O(n) × inner two-pointer O(n) |
| Remove duplicates in-place | O(n) | O(1) | One pass, slow/fast variant |
| Merge two sorted arrays | O(n + m) | O(n + m) | Output array counts as space |
| Sort step before two pointers | O(n log n) | O(log n) | Stack space for sort |

**Allocation behaviour:** Two pointers itself allocates nothing — it works with existing indices. If you need to sort first, that's O(log n) stack space for quicksort's recursion. The merge variant allocates O(n + m) for the output array.

**Benchmark notes:** For small arrays (< 50 elements), the nested loop O(n²) is often faster due to branch prediction and cache effects. Two pointers matters at n > 1,000 where the quadratic term becomes measurable.

---

## The Code

**Scenario 1 — two sum on sorted array**
```csharp
public static (int, int) TwoSumSorted(int[] nums, int target)
{
    int lo = 0, hi = nums.Length - 1;
    while (lo < hi)
    {
        int sum = nums[lo] + nums[hi];
        if (sum == target)   return (lo, hi);
        if (sum < target)    lo++;   // sum too small — advance left to increase it
        else                 hi--;   // sum too large — retreat right to decrease it
    }
    return (-1, -1);
}
```

**Scenario 2 — three sum (all unique triplets summing to zero)**
```csharp
public static List<List<int>> ThreeSum(int[] nums)
{
    Array.Sort(nums);
    var result = new List<List<int>>();

    for (int i = 0; i < nums.Length - 2; i++)
    {
        if (i > 0 && nums[i] == nums[i - 1]) continue; // skip outer duplicates

        int lo = i + 1, hi = nums.Length - 1;
        while (lo < hi)
        {
            long s = (long)nums[i] + nums[lo] + nums[hi];
            if (s == 0)
            {
                result.Add(new List<int> { nums[i], nums[lo], nums[hi] });
                while (lo < hi && nums[lo] == nums[lo + 1]) lo++; // skip inner dupes
                while (lo < hi && nums[hi] == nums[hi - 1]) hi--;
                lo++; hi--;
            }
            else if (s < 0) lo++;
            else            hi--;
        }
    }
    return result;
}
```

**Scenario 3 — remove duplicates in-place (slow/fast variant)**
```csharp
public static int RemoveDuplicates(int[] nums)
{
    if (nums.Length == 0) return 0;
    int slow = 0;
    for (int fast = 1; fast < nums.Length; fast++)
    {
        if (nums[fast] != nums[slow])
        {
            slow++;
            nums[slow] = nums[fast]; // slow is the write head; fast is the read head
        }
    }
    return slow + 1; // length of deduplicated array
}
```

**Scenario 4 — what NOT to do (hash map when two pointers suffices on sorted input)**
```csharp
// BAD: allocates O(n) extra space when the array is already sorted
public static (int, int) TwoSumBad(int[] sortedNums, int target)
{
    var seen = new Dictionary<int, int>();
    for (int i = 0; i < sortedNums.Length; i++)
    {
        int complement = target - sortedNums[i];
        if (seen.ContainsKey(complement))
            return (seen[complement], i);
        seen[sortedNums[i]] = i;
    }
    return (-1, -1);
}

// GOOD: uses sort order, O(1) space
public static (int, int) TwoSumGood(int[] sortedNums, int target)
{
    int lo = 0, hi = sortedNums.Length - 1;
    while (lo < hi)
    {
        int sum = sortedNums[lo] + sortedNums[hi];
        if (sum == target) return (lo, hi);
        if (sum < target)  lo++;
        else               hi--;
    }
    return (-1, -1);
}
```

---

## Real World Example

In an e-commerce platform, the `OrderMatcher` service pairs buy and sell orders from a sorted order book. Every incoming buy order needs the cheapest available sell order whose price is within a spread threshold. The order book is pre-sorted by price. A nested loop was hitting 800ms on books of 10,000 orders. Two pointers brought it to 4ms.

```csharp
public class OrderMatcher
{
    public record Order(int Id, decimal Price, int Quantity, OrderSide Side);
    public enum OrderSide { Buy, Sell }

    // Both lists arrive pre-sorted by price ascending.
    // Find all (buy, sell) pairs where sellPrice - buyPrice <= maxSpread.
    public List<(Order Buy, Order Sell)> FindMatchablePairs(
        List<Order> buyOrders,
        List<Order> sellOrders,
        decimal maxSpread)
    {
        var matches = new List<(Order, Order)>();

        // Sort buys descending (highest buyer first), sells ascending (cheapest seller first)
        buyOrders  = buyOrders.OrderByDescending(o => o.Price).ToList();
        sellOrders = sellOrders.OrderBy(o => o.Price).ToList();

        int b = 0, s = 0;
        while (b < buyOrders.Count && s < sellOrders.Count)
        {
            var buy  = buyOrders[b];
            var sell = sellOrders[s];

            decimal spread = sell.Price - buy.Price;

            if (spread < 0)
            {
                // Sell is cheaper than buy — advance sell pointer to find a valid ask
                s++;
            }
            else if (spread <= maxSpread)
            {
                matches.Add((buy, sell));
                // Try to match this buyer with the next seller too
                s++;
            }
            else
            {
                // Spread too wide — this buyer can't afford any remaining seller
                b++;
            }
        }

        return matches;
    }
}
```

*The key insight: because both lists are sorted, each pointer move permanently eliminates candidates — we never need to revisit a sell order once we've advanced past it. O(n + m) instead of O(n × m).*

---

## Common Misconceptions

**"Two pointers only works on arrays"**
It works on any indexed sequence — strings, spans, and even implicit sequences. `ValidPalindrome` on a `string` is two pointers. The linked-list fast/slow variant is also two pointers, just without random access. The pattern is about the pointer movement logic, not the container.

**"I need to sort first, so two pointers isn't really O(n)"**
The full complexity including the sort is O(n log n) — but that's still better than O(n²) brute force, and the sort is often already done or required by the problem. State the full complexity (O(n log n) for sort + O(n) for the pass = O(n log n) total) and note that on pre-sorted input it degrades to O(n).

**"The slow/fast read-write variant is the same as the converging variant"**
They look similar but are different patterns. Converging (`lo`/`hi` moving toward each other) solves pair-sum problems on sorted data. Slow/fast (`slow` as write head, `fast` as read head moving in the same direction) solves in-place partition/dedup problems. Using converging logic on a dedup problem or vice versa will produce wrong answers.

---

## Gotchas

- **`lo < hi` not `lo <= hi`.** When `lo == hi`, both pointers are on the same element. A pair requires two distinct indices. This off-by-one causes false positives — you'll match an element against itself.

- **Duplicate handling in three-sum breaks most implementations.** You must skip duplicates at both the outer loop level (`if i > 0 && nums[i] == nums[i-1]`) and the inner two-pointer level (after adding a result, advance past identical values on both sides). Missing either one produces duplicate triplets in the output.

- **Pointer movement must be provably correct.** For each step, you must be able to argue: "this candidate is impossible, so discarding it is safe." If you can't articulate that argument, the pointer movement may skip valid answers. Write the argument as a comment the first time.

- **Two pointers only works correctly on sorted input for sum/pair problems.** If the array isn't sorted, sort it first (O(n log n)). This is still better than O(n²) brute force.

- **Merging two sorted arrays into one (not in-place) is O(n + m) space.** The two-pointer merge step itself is O(1) logic, but you need an output buffer the size of both inputs. True in-place merge is O((n + m) log(n + m)) due to rotation — almost never worth it.

---

## Interview Angle

**What they're really testing:** Whether you see a nested loop and immediately ask "can I sort first and use two pointers?" — reducing O(n²) to O(n log n) or O(n).

**Common question forms:**
- "Given a sorted array, find two numbers that sum to a target."
- "Find all unique triplets in an array that sum to zero."
- "Given an array, remove duplicates in-place and return the new length."
- "Given heights representing a histogram, find the container with the most water."

**The depth signal:** A junior brute-forces pairs. A senior sorts and applies two pointers, articulates why each pointer move is safe, and extends the pattern from 2-sum to 3-sum without prompting — fix one element, run two-sum on the rest. They handle duplicate-skipping cleanly (which is where most candidates fail on three-sum) and know which variant to use: converging for pair-sum, slow/fast for partition.

**Follow-up questions to expect:**
- "What if the array isn't sorted and you can't sort it?" → hash map, O(n) time O(n) space.
- "Can you do three-sum in O(n)?" → No. Lower bound for 3SUM is Ω(n²) under the comparison model.

---

## Related Topics

- [[algorithms/patterns/sliding-window.md]] — Related single-pass pattern; two pointers for subarrays where both ends move right only.
- [[algorithms/patterns/fast-slow-pointers.md]] — Two pointers at different speeds on linked lists; cycle detection and midpoint.
- [[algorithms/searching/binary-search.md]] — Another way to eliminate candidates; often combined with two pointers on sorted data.
- [[algorithms/datastructures/array.md]] — Two-pointer problems almost always live on arrays or strings.

---

## Source

https://leetcode.com/articles/two-pointer-technique

---

*Last updated: 2026-04-21*