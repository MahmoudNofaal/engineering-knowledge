# Sorting in Practice
> How real-world sorting algorithms work — why language built-ins are hybrid algorithms, and how to choose the right sort for a given situation.

---

## When To Use It
This is the decision layer above individual sorting algorithms. Use it when you need to choose between sorting approaches in production, when an interviewer asks "which sort would you use and why," or when you're hitting performance limits with a naive sort. The answer is almost always "use the built-in sort" — but you need to know what's inside it and when to deviate.

---

## Core Concept
No single sorting algorithm dominates across all cases. Real implementations are hybrids:

**Timsort** (Python `list.sort()`, Java `Arrays.sort()` for objects) combines merge sort and insertion sort. It scans the input for natural runs (already-sorted subsequences), uses insertion sort to extend short runs to a minimum size (~32–64 elements), then merges runs using a merge sort strategy. Best case is O(n) on sorted or nearly-sorted data. Worst case is O(n log n). Always stable.

**Introsort** (C++ `std::sort`, Rust `slice::sort_unstable`) starts with quick sort for cache performance, switches to heap sort if recursion depth exceeds 2 log n (preventing O(n²) worst case), and falls back to insertion sort for small subarrays. Result: O(n log n) worst case, fast average case, in-place, but not stable.

**Pdqsort** (pattern-defeating quicksort, used by Rust and newer C++ implementations) extends introsort with pivot selection strategies that detect and handle adversarial patterns like sorted, reverse-sorted, and repeated elements.

The crossover points matter: insertion sort beats merge sort and quick sort below ~10–64 elements because constant factors dominate at small n. Every major sort implementation uses insertion sort for small subarrays.

---

## The Code

**Python built-in sort — always reach for this first**
```python
# list.sort() — in-place Timsort, O(n log n), stable
items = [3, 1, 4, 1, 5, 9, 2, 6]
items.sort()

# sorted() — returns new list, same Timsort
items = sorted([3, 1, 4, 1, 5, 9, 2, 6])

# custom key — sort by second element of tuple
pairs = [(1, 'b'), (2, 'a'), (3, 'c')]
pairs.sort(key=lambda x: x[1])

# multi-key sort — primary by age, secondary by name
people = [('Alice', 30), ('Bob', 25), ('Carol', 30)]
people.sort(key=lambda p: (p[1], p[0]))
```

**Stability matters — multi-pass sort**
```python
# Sort students: primary by grade descending, secondary by name ascending
# Stable sort lets you do this in two passes
students = [('Alice', 'B'), ('Bob', 'A'), ('Carol', 'B'), ('Dave', 'A')]
students.sort(key=lambda s: s[0])          # pass 1: sort by name
students.sort(key=lambda s: s[1])          # pass 2: sort by grade (stable = names preserved within grade)
```

**When to use counting/radix sort over built-in**
```python
import time

# Scenario: sort 1 million integers in range [0, 1000]
# Timsort: O(n log n) = ~20 million comparisons
# Counting sort: O(n + k) = ~1 million + 1000 operations

def counting_sort_perf(items: list, k: int) -> list:
    count = [0] * (k + 1)
    for val in items:
        count[val] += 1
    return [val for val, cnt in enumerate(count) for _ in range(cnt)]

import random
data = [random.randint(0, 1000) for _ in range(1_000_000)]

start = time.time()
sorted(data)
print(f"Timsort:       {time.time() - start:.3f}s")

start = time.time()
counting_sort_perf(data, 1000)
print(f"Counting sort: {time.time() - start:.3f}s")
# Counting sort is measurably faster here
```

**Choosing the right sort — decision tree in code comments**
```python
def choose_sort(data, stable_required, key_range=None):
    # 1. Small input (< 20 elements)?
    #    → insertion sort or just use built-in (it does this internally)

    # 2. Nearly sorted?
    #    → Timsort (built-in) exploits existing runs — close to O(n)

    # 3. Integer keys with small range k where k ≈ n?
    #    → counting sort: O(n + k)

    # 4. Integer keys with large range but fixed digit count?
    #    → radix sort: O(d × n)

    # 5. Stable sort required for arbitrary objects?
    #    → Python built-in (Timsort), Java Arrays.sort for objects

    # 6. In-place required, no stability needed?
    #    → quick sort or heap sort; or built-in if language uses introsort

    # 7. Sorting a linked list?
    #    → merge sort: no random access needed, O(log n) stack space

    # 8. Everything else?
    #    → built-in sort. It's probably Timsort or introsort. Trust it.
    pass
```

---

## Gotchas

- **Python's `sort` is already heavily optimized — don't reimplement it.** A hand-rolled quick sort in Python is slower than `list.sort()` by 10–50× because the built-in is implemented in C. Only deviate when the input structure lets you beat O(n log n) (counting/radix sort).
- **Stable vs unstable matters in multi-key sorts.** The two-pass stable sort trick (sort by secondary key first, then primary key) only works with a stable sort. With an unstable sort, the secondary ordering is destroyed by the primary pass.
- **`key=` is O(n) extra function calls but usually worth it.** For small n, a custom comparator via `functools.cmp_to_key` works fine. For large n, a `key=` function that extracts a lightweight value is faster because it's called once per element, not once per comparison.
- **Java has two different sort implementations.** `Arrays.sort()` for primitive arrays uses dual-pivot quicksort (fast, unstable). `Arrays.sort()` for object arrays uses Timsort (stable). Mixing the two assumptions in an interview is a red flag.
- **Timsort's O(n) best case requires actual runs in the data.** A random shuffle destroys all runs; Timsort degrades to merge sort behavior. "Timsort is O(n)" only applies to nearly-sorted data — it's not a general O(n) sort.

---

## Interview Angle

**What they're really testing:** Whether you have practical judgment about sorting — not just academic knowledge of algorithms, but knowing which tool fits which situation and why language implementors made the choices they did.

**Common question form:** "Which sorting algorithm would you use here and why?" — especially when given constraints like stability, memory limits, data distribution, or data type.

**The depth signal:** A junior picks merge sort or quick sort and justifies with Big-O. A senior explains Timsort's run detection, why introsort uses heap sort as a fallback instead of merge sort (in-place matters), and knows the practical crossover points: insertion sort below ~32 elements, counting sort when k ≈ n, radix sort for fixed-width integers. The elite signal is knowing that Java's primitive vs object sort difference is a deliberate trade-off: primitives have no identity, so unstable is fine; objects may depend on stable ordering.

---

## Related Topics

- [[algorithms/merge-sort.md]] — The stable O(n log n) base of Timsort.
- [[algorithms/quick-sort.md]] — The cache-efficient base of introsort; also the source of its worst-case risk.
- [[algorithms/heap-sort.md]] — Introsort's fallback; guarantees O(n log n) in-place when quick sort degrades.
- [[algorithms/counting-radix-sort.md]] — When to break out of O(n log n) with linear-time sorts.

---

## Source

https://en.wikipedia.org/wiki/Timsort

---

*Last updated: 2026-03-24*