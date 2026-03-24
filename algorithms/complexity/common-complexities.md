# Common Complexities
> A reference for the growth classes that appear most often in real algorithms, ordered from fastest to slowest.

---

## When To Use It
Use this as a decision framework when designing or reviewing algorithms. Knowing which complexity class your target solution falls into tells you whether your current approach has room to improve — or whether you've already hit the theoretical limit. Don't memorize this list; understand why each class exists.

---

## Core Concept
Most algorithms you'll encounter fall into one of seven complexity classes. They form a hierarchy: O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!). Moving up that hierarchy is expensive — an O(n²) solution that works at n=1,000 will fall apart at n=1,000,000. The practical skill is recognizing which class your code falls into by its structure: loops, recursion depth, branching factor, and whether you're halving or doubling the problem each step.

---

## The Code

**O(1) — Constant**
```python
def get_last(items: list):
    return items[-1]  # index access, no matter the size
```

**O(log n) — Logarithmic**
```python
# Input is halved each iteration — classic log n shape
def binary_search(items: list, target: int) -> int:
    lo, hi = 0, len(items) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if items[mid] == target:
            return mid
        elif items[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
```

**O(n) — Linear**
```python
def linear_search(items: list, target: int) -> int:
    for i, val in enumerate(items):
        if val == target:
            return i
    return -1
```

**O(n log n) — Linearithmic**
```python
# The best achievable for comparison-based sorting
items = [3, 1, 4, 1, 5, 9, 2, 6]
items.sort()  # Timsort: O(n log n) time, O(n) space
```

**O(n²) — Quadratic**
```python
# Every pair of elements is compared — nested loops
def bubble_sort(items: list) -> list:
    n = len(items)
    for i in range(n):
        for j in range(0, n - i - 1):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
    return items
```

**O(2ⁿ) — Exponential**
```python
# Each call branches into two — tree doubles every level
def fibonacci_naive(n: int) -> int:
    if n <= 1:
        return n
    return fibonacci_naive(n - 1) + fibonacci_naive(n - 2)
```

**O(n!) — Factorial**
```python
from itertools import permutations

# Generating all orderings — grows faster than anything else
def all_permutations(items: list) -> list:
    return list(permutations(items))
# n=10 → 3,628,800 permutations
# n=15 → 1,307,674,368,000 permutations
```

---

## Gotchas

- **O(n log n) is the floor for comparison-based sorting — you cannot do better.** Any algorithm that sorts by comparing elements cannot beat this. Counting sort and radix sort sidestep comparisons entirely, which is why they achieve O(n).
- **O(2ⁿ) explodes faster than it looks.** At n=30, that's over a billion operations. Naive recursion on overlapping subproblems (Fibonacci, subset generation) is almost always fixable with memoization — bringing it down to O(n).
- **O(n²) is a hidden danger in nested data structures.** A loop over a list that calls `.index()` or `in` on another list inside it is O(n²) even though it looks like one loop. The inner operation is itself O(n).
- **O(log n) requires a sorted or structured input.** Binary search is O(log n) only because the data is sorted. Apply it to unsorted data and it simply doesn't work — it's not slower, it's wrong.
- **Polynomial (O(nᵏ)) is the boundary between "feasible" and "hard."** Problems solvable in polynomial time are considered tractable. Exponential and factorial complexity almost always signals that you need dynamic programming, greedy approximation, or a different problem formulation.

---

## Interview Angle

**What they're really testing:** Whether you can look at unfamiliar code and immediately classify its complexity — and whether you know the theoretical limits of what's achievable.

**Common question form:** "Can you optimize this?" — where the current solution is O(n²) and the expected answer involves recognizing a hash map or sorting step that brings it to O(n) or O(n log n).

**The depth signal:** A junior knows the classes by name and associates them with common examples. A senior knows *why* a class is a lower bound — e.g., "comparison-based sorting can't beat O(n log n) because the decision tree for n elements has n! leaves, requiring at least log(n!) ≈ n log n decisions." That kind of reasoning shows understanding, not memorization.

---

## Related Topics

- [[algorithms/big-o-notation.md]] — The notation and rules for expressing and simplifying complexity.
- [[algorithms/complexity-analysis.md]] — How to derive the complexity class of code you haven't seen before.
- [[algorithms/sorting-algorithms.md]] — Concrete algorithms spanning O(n log n) to O(n²) with real trade-offs.
- [[algorithms/dynamic-programming.md]] — The primary technique for converting O(2ⁿ) recursive solutions to O(n) or O(n²).

---

## Source

https://www.bigocheatsheet.com

---

*Last updated: 2026-03-24*