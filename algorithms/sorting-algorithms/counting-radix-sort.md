# Counting Sort & Radix Sort

> Non-comparison sorts that achieve O(n) time by exploiting the structure of the keys — bypassing the Ω(n log n) comparison sort lower bound.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Sort by key structure (not comparisons): count frequencies or sort digit-by-digit |
| **Use when** | Integer keys in bounded range; fixed-length strings; IP addresses; timestamps |
| **Avoid when** | Floating-point, arbitrary objects, key range k >> n (counting sort), variable-length strings |
| **C# version** | C# 1.0+ (manual implementation — no built-in non-comparison sort) |
| **Namespace** | None |
| **Key types** | `int[] count`, `int[] output`, base-10 or base-256 digit extraction |

---

## When To Use It

Use **counting sort** when keys are non-negative integers in a small, known range [0, k] where k ≈ n. Examples: sort ages (0–120), sort scores (0–100), sort characters in a string. Use **radix sort** when keys are integers with large range but bounded digit count — sorting 32-bit integers, IP addresses, or fixed-length strings. Both break the O(n log n) comparison sort barrier, but only for specific data types.

---

## Core Concept

**Counting sort:** Count how many times each value appears. Compute prefix sums to find the starting output position for each value. Place each element at its computed position. Stability is preserved by iterating the input right-to-left during placement.

**Radix sort (LSD — Least Significant Digit first):** Sort numbers digit by digit from least significant to most significant, using a stable sort (counting sort) on each digit. Stability at each digit pass is critical — it's what makes the overall sort correct. After all digits are processed, the full sort is complete.

The key insight for radix sort: stable sorting by the least significant digit first, then the next, etc., means earlier digit orderings are preserved within ties at the current digit. After all digits, the result is fully sorted.

---

## Algorithm History

| Year | Development |
|---|---|
| 1887 | Herman Hollerith uses a mechanical card-sorter — first radix sort device |
| 1954 | Harold Seward describes LSD radix sort for computers |
| 1960s | Counting sort formalised in computer science literature |
| 1970s | Knuth analyses both in TAOCP Volume 3 |
| 1987 | MSD (most-significant digit) radix sort for strings formalised |

---

## Performance

| Algorithm | Time | Space | Notes |
|---|---|---|---|
| Counting sort | O(n + k) | O(n + k) | k = key range; impractical if k >> n |
| LSD Radix sort | O(d × (n + b)) | O(n + b) | d = digits, b = base (10 or 256) |
| Radix sort base 256 | O(4n) = O(n) | O(n) | For 32-bit integers: 4 passes of base-256 counting sort |
| Comparison lower bound | Ω(n log n) | — | Cannot be beaten by any comparison sort |

**Allocation behaviour:** Counting sort allocates `int[k+1]` count array + `T[n]` output array. Radix sort allocates `int[base]` count array (reused per pass) + `T[n]` output buffer. Both are O(n + k) or O(n + b) — no per-element allocation.

**Benchmark notes:** Radix sort base 256 (4 passes for 32-bit int) is measurably faster than `Array.Sort` at n > 100,000 for random integers. At n = 1,000,000: radix sort ≈ 150ms, `Array.Sort` ≈ 400ms in benchmarks. For n < 10,000, `Array.Sort` wins due to better cache behaviour on small arrays.

---

## The Code

**Scenario 1 — counting sort for integers in [0, k]**
```csharp
public static int[] CountingSort(int[] arr, int k)
{
    var count  = new int[k + 1];
    var output = new int[arr.Length];

    foreach (int val in arr) count[val]++;

    // Prefix sum: count[i] = number of elements ≤ i
    for (int i = 1; i <= k; i++) count[i] += count[i - 1];

    // Place elements right-to-left to preserve stability
    for (int j = arr.Length - 1; j >= 0; j--)
    {
        output[count[arr[j]] - 1] = arr[j];
        count[arr[j]]--;
    }
    return output;
}
```

**Scenario 2 — LSD radix sort for non-negative integers**
```csharp
public static void RadixSort(int[] arr)
{
    if (arr.Length == 0) return;
    int max = arr.Max();

    // Sort by each digit (base 10), from least to most significant
    for (int exp = 1; max / exp > 0; exp *= 10)
        CountingSortByDigit(arr, exp);
}

private static void CountingSortByDigit(int[] arr, int exp)
{
    int n      = arr.Length;
    var output = new int[n];
    var count  = new int[10]; // base 10

    foreach (int val in arr) count[(val / exp) % 10]++;
    for (int i = 1; i < 10; i++) count[i] += count[i - 1];

    // Right-to-left for stability
    for (int j = n - 1; j >= 0; j--)
    {
        int digit = (arr[j] / exp) % 10;
        output[count[digit] - 1] = arr[j];
        count[digit]--;
    }
    Array.Copy(output, arr, n);
}
```

**Scenario 3 — radix sort base 256 (4 passes for 32-bit integers)**
```csharp
public static void RadixSortBase256(int[] arr)
{
    int n      = arr.Length;
    var output = new int[n];

    for (int bytePos = 0; bytePos < 4; bytePos++) // 4 bytes per 32-bit int
    {
        int shift = bytePos * 8;
        var count = new int[256]; // base 256

        foreach (int val in arr) count[(val >> shift) & 0xFF]++;
        for (int i = 1; i < 256; i++) count[i] += count[i - 1];

        for (int j = n - 1; j >= 0; j--)
        {
            int b = (arr[j] >> shift) & 0xFF;
            output[count[b] - 1] = arr[j];
            count[b]--;
        }
        Array.Copy(output, arr, n);
    }
    // Only 4 passes of O(n + 256) vs ~log₂(n) passes for comparison sorts
}
```

**Scenario 4 — what NOT to do: counting sort with large key range**
```csharp
// BAD: counting sort with k >> n — wastes massive memory and time on the count array
public static int[] CountingSortBad(int[] arr)
{
    int k = arr.Max(); // Could be int.MaxValue = 2,147,483,647
    var count = new int[k + 1]; // 2 BILLION entries → OutOfMemoryException
    foreach (int val in arr) count[val]++;
    // ... rest of algorithm
    return Array.Empty<int>(); // never reached
}

// GOOD: use radix sort when key range is large but digits are bounded
// Or use Array.Sort (introsort) if n < 100,000 — constant factors dominate
public static void SortLargeRange(int[] arr)
{
    if (arr.Length < 100_000)
        Array.Sort(arr);         // O(n log n) but faster for small n
    else
        RadixSortBase256(arr);   // O(n) — faster for large n with 32-bit int keys
}
```

---

## Real World Example

The `EventLogIndexer` in a monitoring platform sorts 10 million event log entries by their Unix timestamp (32-bit integer) every 5 minutes for time-range queries. Using `Array.Sort` (introsort): ~4 seconds. Using radix sort base 256 (4 passes over 10M entries): ~800ms — 5× faster. The key type (bounded-range integer) makes non-comparison sort applicable.

```csharp
public class EventLogIndexer
{
    public record LogEntry(int UnixTimestamp, string EventId, string Payload);

    // Sort 10M entries by Unix timestamp using radix sort on the key field.
    // Returns entries in ascending timestamp order.
    public LogEntry[] SortByTimestamp(LogEntry[] entries)
    {
        if (entries.Length < 10_000)
        {
            // Small batch — Array.Sort constant factor wins
            return entries.OrderBy(e => e.UnixTimestamp).ToArray();
        }

        // Extract keys for radix sort (operate on int[] for cache efficiency)
        int n     = entries.Length;
        int[] keys = new int[n];
        for (int i = 0; i < n; i++) keys[i] = entries[i].UnixTimestamp;

        // Track original indices alongside keys
        int[] indices = Enumerable.Range(0, n).ToArray();

        // 4-pass base-256 radix sort on (key, index) pairs
        var outputIdx = new int[n];
        for (int bytePos = 0; bytePos < 4; bytePos++)
        {
            int shift  = bytePos * 8;
            var count  = new int[256];

            foreach (int idx in indices) count[(keys[idx] >> shift) & 0xFF]++;
            for (int i = 1; i < 256; i++) count[i] += count[i - 1];

            for (int j = n - 1; j >= 0; j--)
            {
                int b = (keys[indices[j]] >> shift) & 0xFF;
                outputIdx[count[b] - 1] = indices[j];
                count[b]--;
            }
            Array.Copy(outputIdx, indices, n);
        }

        // Reconstruct sorted entries array
        var sorted = new LogEntry[n];
        for (int i = 0; i < n; i++) sorted[i] = entries[indices[i]];
        return sorted;
    }
}
```

*The key insight: sorting indices alongside keys (rather than the full `LogEntry` objects) keeps the inner loop working on small integers — maximising cache efficiency. The objects are only rearranged once, at the end, in a single pass.*

---

## Common Misconceptions

**"O(n) sort is always faster than O(n log n) sort"**
O(n) has a hidden constant — radix sort base 256 does 4 × O(n + 256) passes. At small n (< 10,000), `Array.Sort`'s constant factor wins. The crossover where radix sort beats introsort is typically n ≈ 100,000–500,000 for random 32-bit integers.

**"Stability doesn't matter in radix sort — it's just a detail"**
Stability is mandatory for correctness. If the counting sort pass on each digit is unstable, the orderings established by lower digits are destroyed by higher digit passes, and the final result is wrong. Iterating right-to-left during placement is what makes counting sort stable.

**"Radix sort works for any data type"**
Only for data with a well-defined fixed-width positional decomposition — integers, fixed-length strings, IP addresses. It cannot sort floating-point numbers directly (the IEEE 754 bit layout doesn't sort correctly as an unsigned integer for negatives), arbitrary objects, or variable-length strings without extra transformation.

---

## Gotchas

- **Counting sort requires knowing the key range upfront.** If k is unknown or very large (k >> n), use radix sort instead.
- **Radix sort on signed integers needs special handling.** Negative integers in two's complement have their sign bit set — treating them as unsigned places negatives after positives. Sort negatives and positives separately, or XOR the sign bit to make the bit pattern sort correctly.
- **Stability requires right-to-left placement.** Iterating the input from right to left in the placement phase (and decrementing the count) preserves the relative order of equal-key elements.
- **Radix sort base 10 is 2–3× slower than base 256 for 32-bit integers.** Base 10 requires `log₁₀(max)` ≈ 10 passes for a 32-bit int. Base 256 requires exactly 4. Always use base 256 for integer radix sort.
- **`int.MaxValue` as a key requires `long` for `exp`.** When computing `max / exp`, if `exp` is `int`, multiplying by 10 overflows before reaching all digit positions. Use `long exp`.

---

## Interview Angle

**What they're really testing:** Whether you know O(n log n) is not a universal lower bound (only for comparison-based sorts) and can articulate the conditions under which linear-time sorting is achievable.

**Common question forms:** "Can you sort this faster than O(n log n)?" when input is integers in a bounded range. "Sort an array of strings where all strings have the same fixed length." "Sort 1 million ages."

**The depth signal:** A junior knows counting sort exists. A senior explains the information-theoretic Ω(n log n) lower bound for comparison sorts (n! orderings require log₂(n!) ≈ n log n bits to distinguish), why non-comparison sorts bypass it (using key structure instead of comparisons), and chooses base 256 over base 10 for integer radix sort. They handle the stability requirement correctly and know when to fall back to `Array.Sort`.

**Follow-up questions to expect:**
- "Why is radix sort stable?" → Counting sort (the subroutine) is made stable by iterating right-to-left during placement. Without stability, earlier digit orderings are destroyed by later passes.
- "Why does radix sort use LSD (least significant digit first) rather than MSD?" → LSD allows a single linear pass per digit with a stable sort, producing a fully sorted result after all digits. MSD requires recursive partitioning (like a trie sort) which is more complex and slower in practice for fixed-width keys.

---

## Related Topics

- [[algorithms/sorting-algorithms/sorting-in-practice.md]] — When to use linear sorts vs comparison sorts in real systems.
- [[algorithms/complexity/common-complexities.md]] — Why Ω(n log n) is a lower bound only for comparison-based sorts.
- [[algorithms/sorting-algorithms/merge-sort.md]] — The stable O(n log n) comparison sort used as counting sort's subroutine in radix sort.

---

## Source

https://en.wikipedia.org/wiki/Radix_sort

---

*Last updated: 2026-04-21*