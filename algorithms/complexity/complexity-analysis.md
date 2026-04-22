# Complexity Analysis

> The process of deriving the Big-O time and space complexity of an algorithm by systematically examining its structure — loops, recursion, and data structure operations.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Step-by-step method for deriving algorithm complexity |
| **Use when** | Analysing any algorithm before or after implementation |
| **Avoid when** | N/A — always do this; benchmarking confirms, analysis predicts |
| **C# version** | N/A — mathematical process |
| **Namespace** | N/A |
| **Key types** | Loop analysis, recurrence relations, Master Theorem |

---

## When To Use It

Always. Every function you write should have a known time and space complexity. Complexity analysis tells you whether a solution will scale before you run it — it predicts problems at n = 10^6 that your test at n = 100 didn't catch. In interviews, stating complexity proactively (without being asked) is a strong signal of seniority.

---

## Core Concept

**For iterative algorithms:** count how many times each statement executes as a function of n. Loops multiply; sequential blocks add; drop constants and lower-order terms.

**For recursive algorithms:** write the recurrence relation T(n) = work at this level + cost of subproblems, then solve it. Three tools: substitution, recursion tree, and the Master Theorem.

**Master Theorem** for `T(n) = aT(n/b) + f(n)`:
- Case 1: `f(n) = O(n^(log_b(a) - ε))` → T(n) = **Θ(n^log_b(a))** — subproblem work dominates
- Case 2: `f(n) = Θ(n^log_b(a))` → T(n) = **Θ(n^log_b(a) × log n)** — balanced
- Case 3: `f(n) = Ω(n^(log_b(a) + ε))` → T(n) = **Θ(f(n))** — combine step dominates

**Space complexity:** count memory allocated proportional to n — heap allocations, call stack depth, and auxiliary data structures.

---

## Algorithm History

| Year | Development |
|---|---|
| 1960s | Knuth formalises algorithm analysis in TAOCP |
| 1973 | Aho, Hopcroft, Ullman publish "The Design and Analysis of Computer Algorithms" |
| 1980 | Master Theorem published by Bentley, Haken, Saxe |
| 1990 | CLRS textbook standardises complexity analysis methodology |
| 2000s | Amortised analysis (aggregate, accounting, potential) popularised |

---

## Performance

| Code Pattern | Complexity | Why |
|---|---|---|
| Single loop 0..n | O(n) | n iterations |
| Nested loops 0..n × 0..n | O(n²) | n × n |
| Loop halving each iteration | O(log n) | log₂(n) iterations |
| Loop from i to n in outer, 0 to i in inner | O(n²) | n(n+1)/2 ≈ n²/2 |
| Recursive halving + O(n) combine | O(n log n) | Master Theorem Case 2 |
| Recursive halving + O(1) combine | O(n) | Master Theorem Case 1 |
| Two independent O(n) loops | O(n) | O(n) + O(n) = O(n) |

---

## The Code

**Scenario 1 — iterative analysis step by step**
```csharp
public bool HasDuplicate(int[] nums)           // n = nums.Length
{
    for (int i = 0; i < nums.Length; i++)      // executes n times
    {
        for (int j = i + 1; j < nums.Length; j++) // executes n-i-1 times
        {
            if (nums[i] == nums[j]) return true; // O(1)
        }
    }
    return false;
}
// Total iterations: (n-1) + (n-2) + ... + 1 = n(n-1)/2 = O(n²)
// Space: O(1) — no auxiliary allocation
```

**Scenario 2 — applying the Master Theorem to merge sort**
```csharp
// MergeSort recurrence: T(n) = 2T(n/2) + O(n)
// a=2 (two subproblems), b=2 (each half the size), f(n) = O(n)
// log_b(a) = log_2(2) = 1
// f(n) = O(n) = O(n^1) = O(n^log_b(a)) → Master Theorem Case 2
// Result: T(n) = O(n log n)

public void MergeSort(int[] arr, int lo, int hi)  // T(n)
{
    if (lo >= hi) return;                          // base case: O(1)
    int mid = (lo + hi) / 2;
    MergeSort(arr, lo, mid);                       // T(n/2)
    MergeSort(arr, mid + 1, hi);                   // T(n/2)
    Merge(arr, lo, mid, hi);                       // O(n) ← the f(n) term
}
// Space: O(n) for merge buffer + O(log n) stack → O(n) total
```

**Scenario 3 — amortised analysis of List<T>.Add**
```csharp
// Aggregate method: sum total work over all operations, divide by count
// n Add() calls on a List starting at capacity 1:
//   - Resize happens at size 1, 2, 4, 8, ..., n/2 → copies 1+2+4+...+n/2 = n-1 elements
//   - Non-resize adds: n direct writes
//   - Total work: n + (n-1) ≈ 2n = O(n)
//   - Per operation: O(n) / n = O(1) amortised

var list = new List<int>(1); // start with capacity 1
for (int i = 0; i < 1_000_000; i++)
    list.Add(i); // O(1) amortised — occasionally O(n) for the resize, but rare
```

**Scenario 4 — what NOT to do: analysing only the visible loops**
```csharp
// BAD analysis: "one loop = O(n)"
public List<int> GetUnique(List<int> items)
{
    var result = new List<int>();
    foreach (int item in items)             // loop: n iterations
        if (!result.Contains(item))         // HIDDEN O(n) — scans result each time
            result.Add(item);
    return result;
    // TRUE complexity: O(n²) — not O(n)
}

// GOOD: use a HashSet to track seen elements — O(n) total
public List<int> GetUniqueFast(List<int> items)
{
    var seen   = new HashSet<int>();        // O(1) Contains
    var result = new List<int>();
    foreach (int item in items)
    {
        if (seen.Add(item))                 // Add returns false if already present — O(1)
            result.Add(item);
    }
    return result;
    // TRUE complexity: O(n) time, O(n) space
}
```

---

## Real World Example

A performance review of `ReportGeneratorService` found a report that took 45 seconds for 5,000 employees. The developer claimed "it's just a loop." The complexity analysis revealed three hidden O(n) operations inside the loop: a LINQ `.FirstOrDefault()` on an unsorted list, a string concatenation chain, and a `.Contains()` check on a `List<string>`. Total: O(n³), not O(n).

```csharp
public class ReportGeneratorService
{
    // Version 1: O(n³) — three hidden linear operations inside the main loop
    public string GenerateReportSlow(List<Employee> employees, List<Department> departments)
    {
        var report = "";
        foreach (var emp in employees)                                    // O(n)
        {
            var dept = departments.FirstOrDefault(d => d.Id == emp.DeptId); // O(d) hidden scan
            var manager = employees.FirstOrDefault(e => e.Id == emp.ManagerId); // O(n) hidden scan
            report += $"{emp.Name},{dept?.Name},{manager?.Name}\n";       // O(n) string growth
        }
        return report;
        // Total: O(n × d × n × n) ≈ O(n³) for n employees, d departments
    }

    // Version 2: O(n) — precompute lookups, use StringBuilder
    public string GenerateReportFast(List<Employee> employees, List<Department> departments)
    {
        // Precompute O(1) lookups — O(n) + O(d) once
        var deptById    = departments.ToDictionary(d => d.Id);    // O(d) build, O(1) lookup
        var empById     = employees.ToDictionary(e => e.Id);      // O(n) build, O(1) lookup
        var sb          = new StringBuilder(employees.Count * 50); // O(1) amortised append

        foreach (var emp in employees)                             // O(n)
        {
            deptById.TryGetValue(emp.DeptId, out var dept);        // O(1)
            empById.TryGetValue(emp.ManagerId, out var manager);   // O(1)
            sb.AppendLine($"{emp.Name},{dept?.Name},{manager?.Name}"); // O(1) amortised
        }
        return sb.ToString();
        // Total: O(n) — one pass, all lookups O(1)
    }

    public record Employee(int Id, string Name, int DeptId, int ManagerId);
    public record Department(int Id, string Name);
}
```

*The key insight: complexity analysis must account for every operation inside a loop — including method calls whose complexity isn't visible at the call site. `FirstOrDefault` with a predicate is always O(n). If you see it inside a loop, the overall complexity is O(n²) minimum.*

---

## Common Misconceptions

**"One loop = O(n), always"**
Only if the loop body is O(1). If the loop body calls a method that is O(n) (like `List.Contains`, `string +=`, or `FirstOrDefault`), the loop is O(n²). Always analyse the cost of everything inside the loop, including method calls.

**"Recursive = exponential"**
Only if there are exponential branches that recompute the same subproblem. Binary search is recursive and O(log n). Merge sort is recursive and O(n log n). A recursive Fibonacci without memoization is O(2^n) because it recomputes subproblems exponentially. Recursion is not inherently expensive — the recurrence structure determines the complexity.

**"The Master Theorem applies to all recurrences"**
Only to recurrences of the form T(n) = aT(n/b) + f(n) with constant a and b. T(n) = T(n-1) + O(n) (sequential reduction, not halving) needs the substitution method. T(n) = T(n/3) + T(2n/3) + O(n) (unequal splits) needs the Akra-Bazzi method. Know the limits of the Master Theorem.

---

## Gotchas

- **Analyse inside-out, not outside-in.** Start with the innermost operation and work outward. The inner cost × the loop count = the total cost. Missing the inner cost is the most common analysis error.

- **Space complexity includes the call stack.** A recursive algorithm of depth d uses O(d) stack space even if it allocates nothing on the heap. For a balanced binary tree DFS, d = O(log n). For a skewed tree or a list, d = O(n).

- **LINQ is lazy but `.ToList()` and `.ToArray()` force evaluation.** A LINQ query like `items.Where(x => x > 0)` is O(1) to construct but O(n) when iterated. Chaining `.OrderBy().First()` forces the full sort — O(n log n) — before returning one element.

- **`Dictionary` and `HashSet` operations are O(1) average, O(n) worst case.** Hash collisions degrade to O(n) for pathological inputs. In competitive programming with adversarial inputs, this matters. In production code with realistic data, O(1) average is the right model.

- **Amortised analysis requires the whole sequence.** Saying a single `List.Add` is O(1) amortised only makes sense in the context of a sequence of n adds. A single add can still be O(n) in the worst case (resize). Don't use amortised analysis for real-time systems where per-operation latency matters.

---

## Interview Angle

**What they're really testing:** Whether you can derive complexity from code structure — not just state it for memorised algorithms.

**Common question forms:**
- "Walk me through the complexity of this code." (hands you code with hidden O(n) inside a loop)
- "What's the recurrence for this recursive algorithm?"
- "Can you apply the Master Theorem here?"

**The depth signal:** A junior states the loop count. A senior analyses every operation inside the loop (including method calls), writes the recurrence for recursive code, applies the Master Theorem correctly, and distinguishes worst-case from amortised. The real separator: the `string +=` O(n²) trap — a senior catches it immediately; a junior misses it.

**Follow-up questions to expect:**
- "How would you verify your complexity analysis?" → Benchmarking: time the algorithm at n, 2n, 4n. If O(n), time doubles. If O(n²), time quadruples.
- "What's the recurrence for binary search?" → T(n) = T(n/2) + O(1). Master Theorem Case 1: log₂(1) = 0, f(n) = O(1) = O(n^0) = O(n^log_b(a)) → wait, a=1, b=2, log_2(1)=0, f(n)=O(1)=O(n^0)=O(n^log_b(a)) → Case 2 → T(n) = O(log n).

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation used throughout this analysis process.
- [[algorithms/complexity/common-complexities.md]] — The reference table for classifying results.
- [[algorithms/patterns/dynamic-programming.md]] — DP converts exponential recurrences to polynomial by memoizing overlapping subproblems.
- [[algorithms/patterns/divide-and-conquer.md]] — Master Theorem is primarily used to analyse D&C recurrences.

---

## Source

https://en.wikipedia.org/wiki/Analysis_of_algorithms

---

*Last updated: 2026-04-21*