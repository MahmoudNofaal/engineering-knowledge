# Recurrence Relations
> A mathematical equation that defines a function in terms of its own value at smaller inputs — the formal tool for expressing and solving the time complexity of recursive algorithms.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Equation expressing T(n) in terms of T(smaller n) |
| **Use when** | Analyzing recursive algorithms |
| **Solving methods** | Substitution, Recursion tree, Master Theorem |
| **Most common form** | T(n) = aT(n/b) + f(n) (divide-and-conquer) |
| **Key result** | Merge sort: T(n) = 2T(n/2) + O(n) → O(n log n) |
| **Master Theorem** | Only applies when subproblems are equal-sized |

---

## When To Use It

Set up a recurrence relation any time you write a recursive algorithm and want to formally derive its complexity. Without it, you're guessing — "it feels like O(n log n)" is not an analysis. The recurrence encodes the structure of the recursion: how many subproblems, what size are they, how much work at each level. From the recurrence, you derive the closed-form Big-O.

Skip deep recurrence analysis for simple recursion with a single subproblem (e.g., `factorial(n-1)`) — those are obviously O(n). Use it seriously for divide-and-conquer algorithms, tree traversals, and DP with non-obvious structure.

---

## Core Concept

A recurrence relation expresses the cost of solving a problem of size n in terms of the cost of smaller subproblems. The general divide-and-conquer form is `T(n) = a·T(n/b) + f(n)`:
- `a` = number of recursive subproblems
- `b` = factor by which input is divided
- `f(n)` = cost of work done outside the recursive calls (combining, splitting)
- Base case = the stopping condition, typically T(1) = O(1)

Solving the recurrence gives you the closed-form complexity. The three methods: **substitution** (guess the answer, prove by induction), **recursion tree** (draw out the call tree, sum level costs), and **Master Theorem** (apply a formula when the form matches). The Master Theorem handles the vast majority of divide-and-conquer recurrences without manual work.

---

## Version History

| Tool | Origin | Notes |
|---|---|---|
| Recurrence relations | Mathematics (18th century) | Predates algorithm analysis |
| Master Theorem | Bentley, Haken, Saxe (1980) | Published in "A General Method for Solving Divide-and-Conquer Recurrences" |
| Akra-Bazzi method | Akra & Bazzi (1998) | Generalizes Master Theorem to unequal-sized subproblems |
| CLRS formalization | Cormen et al. (1990) | Standard CS textbook treatment of recurrences |

---

## Performance

| Algorithm | Recurrence | Closed Form | Notes |
|---|---|---|---|
| Binary search | T(n) = T(n/2) + O(1) | O(log n) | One subproblem, constant work |
| Merge sort | T(n) = 2T(n/2) + O(n) | O(n log n) | Two subproblems, linear merge |
| Quicksort (average) | T(n) = 2T(n/2) + O(n) | O(n log n) | Same as merge sort on average |
| Quicksort (worst) | T(n) = T(n-1) + O(n) | O(n²) | Degenerate pivot, not dividing |
| Fibonacci (naive) | T(n) = T(n-1) + T(n-2) + O(1) | O(2ⁿ) | No common factor — exponential |
| Strassen's matrix mult | T(n) = 7T(n/2) + O(n²) | O(n^2.81) | Beats naive O(n³) via Master Theorem |
| Binary tree traversal | T(n) = 2T(n/2) + O(1) | O(n) | Two subproblems, constant work per node |

---

## The Code

**Setting up the recurrence — merge sort**
```csharp
public static List<int> MergeSort(List<int> items)
{
    // Base case: T(1) = O(1)
    if (items.Count <= 1) return items;

    int mid = items.Count / 2;

    // Two recursive calls, each on input of size n/2 → 2·T(n/2)
    var left = MergeSort(items.Take(mid).ToList());
    var right = MergeSort(items.Skip(mid).ToList());

    // Merge step: O(n) work to combine results → f(n) = O(n)
    return Merge(left, right);
}

// Recurrence: T(n) = 2T(n/2) + O(n)
// a=2, b=2, f(n)=n
// Master Theorem case 2: log_b(a) = log_2(2) = 1, f(n) = n = n^1
// → T(n) = O(n log n)
```

**Setting up the recurrence — binary search**
```csharp
public static int BinarySearch(List<int> sorted, int target, int lo, int hi)
{
    // Base case: T(0) = O(1)
    if (lo > hi) return -1;

    int mid = lo + (hi - lo) / 2;
    if (sorted[mid] == target) return mid;

    // One recursive call on input of size n/2 → 1·T(n/2)
    if (sorted[mid] < target)
        return BinarySearch(sorted, target, mid + 1, hi);  // T(n/2)
    return BinarySearch(sorted, target, lo, mid - 1);      // T(n/2)

    // Recurrence: T(n) = T(n/2) + O(1)
    // a=1, b=2, f(n)=1
    // Master Theorem case 2: log_b(a) = log_2(1) = 0, f(n) = 1 = n^0
    // → T(n) = O(log n)
}
```

**Recursion tree method — visualizing the cost by level**
```csharp
// Merge sort recursion tree for T(n) = 2T(n/2) + O(n)
//
// Level 0: 1 call,  problem size n,   work = n
// Level 1: 2 calls, size n/2 each,    work = 2 × (n/2)  = n
// Level 2: 4 calls, size n/4 each,    work = 4 × (n/4)  = n
// Level k: 2^k calls, size n/2^k,     work = 2^k × (n/2^k) = n
// ...
// Level log n: n calls, size 1,       work = n × O(1) = n
//
// Total levels: log n (we halve n until it reaches 1)
// Cost per level: n
// Total cost: n × log n = O(n log n)
//
// Key insight: work is EQUAL at every level — this is why you get n log n

public static void DrawRecursionTree(int n, int depth = 0)
{
    if (n <= 1) return;
    Console.WriteLine($"{new string(' ', depth * 2)}T({n}): {n} work at this level");
    DrawRecursionTree(n / 2, depth + 1);
    DrawRecursionTree(n / 2, depth + 1);
}
```

**Substitution method — guess and verify**
```csharp
// For T(n) = T(n/2) + O(1), prove T(n) = O(log n) by induction
//
// Guess: T(n) ≤ c·log n for some constant c
//
// Base case: T(1) = O(1) ≤ c·log(1) = 0... doesn't work.
// Adjust: T(n) ≤ c·log n + d for some constants c, d
//
// Inductive step:
// T(n) = T(n/2) + O(1)
//      ≤ c·log(n/2) + d + k      (by inductive hypothesis + O(1) = k)
//      = c·(log n - 1) + d + k
//      = c·log n - c + d + k
//      ≤ c·log n + d             (when c ≥ k, the -c + k ≤ 0)
// ✓ Holds for c ≥ k
//
// Conclusion: T(n) = O(log n)
//
// (This proof isn't C# code — it's the mathematical argument you'd write in an interview)
```

**Unequal subproblems — when Master Theorem doesn't apply**
```csharp
// QuickSort worst case: T(n) = T(n-1) + T(0) + O(n) ≈ T(n-1) + O(n)
// This is NOT a Master Theorem form — subproblems aren't equal-sized
//
// Use substitution or expansion:
// T(n) = T(n-1) + n
//       = T(n-2) + (n-1) + n
//       = T(n-3) + (n-2) + (n-1) + n
//       = ...
//       = T(1) + 2 + 3 + ... + n
//       = O(1) + n(n+1)/2
//       = O(n²)
//
// The degenerate pivot case collapses to O(n²) — visible from expansion

public static int QuickSortWorstCase(List<int> items, int lo, int hi)
{
    if (lo >= hi) return 0;  // T(0) = 0

    // Always picking first element as pivot on sorted input → worst case
    int pivotIdx = Partition(items, lo, hi);
    // Left subproblem: 0 elements (pivot was smallest)
    // Right subproblem: n-1 elements
    QuickSortWorstCase(items, lo, pivotIdx - 1);   // T(0)
    QuickSortWorstCase(items, pivotIdx + 1, hi);   // T(n-1)
    return 0;
    // Recurrence: T(n) = T(0) + T(n-1) + O(n) → T(n-1) + O(n) → O(n²)
}
```

---

## Real World Example

When reviewing a custom tree-walking algorithm for document processing, the recurrence was non-obvious because each node had a variable number of children. Setting up the recurrence explicitly revealed it was actually O(n) — linear in the number of nodes — not O(n log n) as the team assumed, which meant the algorithm was already optimal and no rewrite was needed.

```csharp
// Document tree: each node is a section, children are subsections
public record Section(string Title, string Content, List<Section> Children);

// What's the complexity of WalkAndProcess?
public static void WalkAndProcess(Section section, Action<Section> process)
{
    process(section);                              // O(1) per node

    foreach (var child in section.Children)        // iterate children
        WalkAndProcess(child, process);            // recurse into each
}

// Setting up the recurrence:
// Let n = total number of nodes in the subtree rooted at 'section'
// T(n) = sum of T(child_size) for all children + O(1)
//
// Since sum of all child_sizes = n - 1 (every node except the root):
// T(n) = T(n-1) + O(1)   ... NO, this isn't right
//
// Correct formulation using aggregate over entire tree:
// Each node is processed exactly once → T(n) = O(n)
//
// The recursion tree confirms this: n total calls, O(1) work each = O(n)
// The branching factor doesn't matter — it's the TOTAL NODES that count,
// not the branching structure, when work per node is O(1)

// Wrong intuition: "it's a tree so it's O(n log n)"
// Correct: O(n) — visiting each of n nodes exactly once is O(n) by definition
```

*The key insight: for tree traversals where work per node is O(1), the recurrence always resolves to O(n) regardless of branching factor — because the total work equals total nodes. The confusion usually comes from conflating tree traversal with tree sorting.*

---

## Common Misconceptions

**"Recurrences only apply to sorting algorithms"**
Any recursive algorithm has a recurrence — tree traversal, graph search, dynamic programming, divide-and-conquer geometry, recursive string parsing. The recurrence is just the formal notation for what the algorithm's call structure does. Setting one up is a universal skill, not a sorting-specific one.

**"The Master Theorem handles all recurrences"**
It handles `T(n) = aT(n/b) + f(n)` where subproblems are **equal-sized** fractions. QuickSort's worst case (`T(n) = T(n-1) + O(n)`) doesn't fit. Fibonacci (`T(n) = T(n-1) + T(n-2) + O(1)`) doesn't fit — the subproblems aren't of the form n/b. For those, use expansion, substitution, or the Akra-Bazzi method.

```csharp
// Master Theorem DOES apply: T(n) = 2T(n/2) + O(n)
// a=2, b=2, f(n)=n → O(n log n) ✓

// Master Theorem does NOT apply: T(n) = T(n-1) + O(n)
// The subproblem is T(n-1), not T(n/b) — use expansion instead
// T(n) = T(n-1) + n = T(n-2) + (n-1) + n = ... = O(n²)
```

**"A recurrence with fewer subproblems is always faster"**
Not necessarily — the size of each subproblem and the combination work both matter. T(n) = T(n-1) + O(1) (one subproblem, linear reduction) → O(n). T(n) = 2T(n/2) + O(1) (two subproblems, but halved each time) → O(n). Both O(n)! The structure determines the result, not just the number of recursive calls.

---

## Gotchas

- **Always identify the base case explicitly.** A recurrence without a stated base case is incomplete. T(n) = 2T(n/2) + O(n) needs T(1) = O(1) to be a complete definition. Missing base cases lead to infinite recursion in code and undefined recurrences in analysis.

- **The Master Theorem has three cases — apply the right one.** Case 1: f(n) grows slower than n^(log_b a) → answer is n^(log_b a). Case 2: f(n) grows at the same rate → answer is f(n) · log n. Case 3: f(n) grows faster → answer is f(n). Applying the wrong case is a common interview error.

- **Recursion tree method errors: miscounting work per level.** The total work at each level must be computed carefully — it's (number of nodes at level) × (work per node at that level), where work per node shrinks as input size shrinks. The mistake is using n for work per node when the subproblem size is n/2.

- **QuickSort's average-case analysis requires probability, not just recurrences.** The average-case O(n log n) result assumes a random pivot selection and uniform input distribution. The recurrence T(n) = 2T(n/2) + O(n) describes average behavior but proving it requires expected value analysis over random pivots — the recurrence alone doesn't tell the full story.

- **Fibonacci recurrence is T(n) = T(n-1) + T(n-2) + O(1) → O(2ⁿ), but the exact base is φ (golden ratio), not 2.** The precise result is O(φⁿ) where φ ≈ 1.618. Saying O(2ⁿ) is correct as a Big-O bound but O(1.618ⁿ) is tighter. This distinction usually only comes up at the academic level.

---

## Interview Angle

**What they're really testing:** Whether you can derive complexity formally — not just label a known algorithm, but set up and solve a recurrence for an algorithm you haven't seen before. This is the senior-level version of complexity analysis.

**Common question forms:**
- "Walk me through the time complexity of this recursive function"
- "Write the recurrence relation for your solution"
- "Apply the Master Theorem to this recurrence"

**The depth signal:** A junior says "it's O(n log n) — it's like merge sort." A senior sets up the recurrence: "We have two recursive calls each on n/2 elements, plus O(n) work to merge — that's T(n) = 2T(n/2) + O(n). By the Master Theorem, log_b(a) = log_2(2) = 1, and f(n) = n = n¹, which matches case 2 — so T(n) = O(n log n)." The derivation is the signal.

**Follow-up questions to expect:**
- "What would the complexity be if the merge step were O(n²) instead of O(n)?"
- "What if we made 3 recursive calls instead of 2, each on n/3?"
- "How would you analyze QuickSort's worst case? Does Master Theorem apply?"

---

## Related Topics

- [[algorithms/complexity/complexity-analysis.md]] — The broader process that uses recurrences as one tool.
- [[algorithms/complexity/master-theorem.md]] — The systematic formula for solving divide-and-conquer recurrences.
- [[algorithms/complexity/big-o-notation.md]] — The notation that recurrence solutions are expressed in.
- [[algorithms/sorting-algorithms/merge-sort.md]] — The canonical T(n) = 2T(n/2) + O(n) example.
- [[algorithms/patterns/dynamic-programming.md]] — DP recurrences express optimal substructure, not just algorithmic cost.

---

## Source

https://web.mit.edu/16.070/www/lecture/big_o.pdf

---

*Last updated: 2026-04-12*