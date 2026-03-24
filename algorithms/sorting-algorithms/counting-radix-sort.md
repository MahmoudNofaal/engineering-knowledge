# Counting Sort & Radix Sort
> Non-comparison sorts that achieve O(n) time by exploiting the structure of the keys rather than comparing elements.

---

## When To Use It
Use counting sort when keys are integers within a small, known range (e.g., scores 0–100, ages 0–120). Use radix sort when keys are integers or fixed-length strings with a larger range but bounded digit count — sorting 32-bit integers, IP addresses, or fixed-length strings. Both beat O(n log n) because they don't compare elements — they exploit key structure. Avoid them for floating-point keys, variable-length strings, or when key range k ≫ n (counting sort wastes memory; radix sort gains nothing).

---

## Core Concept
**Counting sort:** Count how many times each value appears. Compute prefix sums to find the starting position of each value in the output. Place each element at its computed position. Stable. O(n + k) time and space where k is the key range.

**Radix sort:** Sort numbers digit by digit, from least significant to most significant (LSD radix sort). Use a stable sort (typically counting sort) on each digit. After processing all digits, the array is sorted. Stability at each digit pass is critical — it's what makes the overall sort correct. O(d × (n + b)) where d is the number of digits and b is the base (usually 10 or 256).

The key insight for radix sort: if you sort by the least significant digit first using a stable algorithm, then by the next digit, earlier digit orderings are preserved within ties at the current digit. After all digits, the result is fully sorted.

---

## The Code

**Counting sort — integers in range [0, k]**
```python
def counting_sort(items: list, k: int) -> list:
    count = [0] * (k + 1)
    for val in items:
        count[val] += 1

    # prefix sum: count[i] = number of elements ≤ i
    for i in range(1, k + 1):
        count[i] += count[i - 1]

    output = [0] * len(items)
    for val in reversed(items):           # reversed preserves stability
        output[count[val] - 1] = val
        count[val] -= 1
    return output
```

**Counting sort used as a subroutine in radix sort**
```python
def counting_sort_by_digit(items: list, exp: int) -> list:
    n = len(items)
    count = [0] * 10
    output = [0] * n

    for val in items:
        digit = (val // exp) % 10
        count[digit] += 1

    for i in range(1, 10):
        count[i] += count[i - 1]          # prefix sum

    for val in reversed(items):           # reversed for stability
        digit = (val // exp) % 10
        output[count[digit] - 1] = val
        count[digit] -= 1
    return output
```

**LSD Radix sort**
```python
def radix_sort(items: list) -> list:
    if not items:
        return items
    max_val = max(items)
    exp = 1
    while max_val // exp > 0:
        items = counting_sort_by_digit(items, exp)
        exp *= 10                         # move to next digit
    return items

# Usage
arr = [170, 45, 75, 90, 802, 24, 2, 66]
print(radix_sort(arr))  # [2, 24, 45, 66, 75, 90, 170, 802]
```

**Counting sort for characters — sort a string**
```python
def sort_string(s: str) -> str:
    count = [0] * 26
    for ch in s:
        count[ord(ch) - ord('a')] += 1
    return ''.join(chr(ord('a') + i) * count[i] for i in range(26))
```

---

## Gotchas

- **Counting sort requires knowing the key range upfront.** If k is large (e.g., sorting arbitrary 32-bit integers with counting sort), the count array requires 4 billion entries. That's where radix sort steps in — it processes those same integers 4 bytes at a time with a count array of size 256.
- **Stability in radix sort is non-negotiable.** Using an unstable sort per digit produces wrong results. The stable pass on digit d preserves the order established by digits 0..d-1 among elements that tie on digit d.
- **Radix sort is not comparison-based — it cannot be used for arbitrary objects.** It only works on data with a well-defined digit/position decomposition: integers, fixed-length strings, IP addresses.
- **The "O(n) sort" claim has a hidden constant.** Radix sort is O(d × n). For 64-bit integers sorted base 256, d = 8. That's 8 passes over n elements — faster than O(n log n) for large n, but not magically instant.
- **Negative integers require special handling.** Separate negatives and positives, sort each group, reverse the negatives, and concatenate. Forgetting this produces incorrect results on mixed input.

---

## Interview Angle

**What they're really testing:** Whether you know that O(n log n) is not a universal lower bound for sorting — only for comparison-based sorting — and can articulate the conditions under which linear sort is achievable.

**Common question form:** "Can you sort this faster than O(n log n)?" when the input is integers in a bounded range. Or: "Sort an array of strings where all strings have the same length."

**The depth signal:** A junior knows counting sort exists. A senior explains the information-theoretic argument: comparison sorts have an Ω(n log n) lower bound because there are n! possible orderings and a decision tree needs at least log(n!) ≈ n log n leaves. Non-comparison sorts sidestep this by using key structure instead of comparisons — which is why they're only applicable to specific data types. They also know that radix sort base 256 is a practical optimization over base 10, cutting the number of passes by a factor of ~2.4.

---

## Related Topics

- [[algorithms/sorting-in-practice.md]] — When to use linear sorts vs comparison sorts in real systems.
- [[algorithms/common-complexities.md]] — Why O(n log n) is a lower bound for comparison sorts specifically.
- [[algorithms/merge-sort.md]] — The stable O(n log n) comparison sort used as radix sort's subroutine.

---

## Source

https://en.wikipedia.org/wiki/Radix_sort

---

*Last updated: 2026-03-24*