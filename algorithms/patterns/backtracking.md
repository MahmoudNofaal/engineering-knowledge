# Backtracking

> A DFS-based technique that builds solutions incrementally, abandoning (pruning) any partial solution that cannot lead to a valid result.

---

## Quick Reference

| | |
|---|---|
| **What it is** | DFS with state mutation, undo, and constraint pruning |
| **Use when** | Enumerate all valid combinations, permutations, subsets, constraint satisfaction |
| **Avoid when** | You only need to count/optimise (use DP); problem size makes O(2^n) intractable |
| **C# version** | C# 1.0+ (uses local functions cleanly from C# 7.0+) |
| **Namespace** | None — pure recursive pattern |
| **Key types** | `List<T> path`, `bool[] used`, `HashSet<int>` for constraint tracking |

---

## When To Use It

Use backtracking when you need to enumerate all valid combinations, permutations, subsets, or configurations — and many partial states can be ruled out early. It's the right tool for constraint satisfaction problems: N-queens, Sudoku, word search, subset sum. Backtracking is exhaustive search made tolerable by pruning. Without pruning, it's brute-force O(n!). Good pruning can make it practically fast even when the worst case is still exponential. If you only need to count solutions or find the optimal one, DP is usually better.

---

## Core Concept

Backtracking is DFS with state mutation and undo. At each step, make a choice (add to path), recurse, then undo the choice (remove from path) before trying the next option. The critical insight: you're not creating a new copy of the state at each level — you're mutating one shared state and restoring it. This is what makes backtracking memory-efficient compared to creating a new list at every branch.

Pruning is where backtracking separates itself from naive enumeration. Before making a choice, check if it violates any constraint. If it does, skip it entirely — don't recurse into that branch at all. Sorting the input before backtracking often enables early termination (`if candidates[i] > remaining: break`) which turns O(n!) into something tractable.

---

## Algorithm History

| Era | Development |
|---|---|
| 1950s | Term "backtracking" coined by D.H. Lehmer for solving combinatorial problems |
| 1960s | Davis-Putnam algorithm applies backtracking to SAT solving |
| 1970s | Formalized in Knuth's "Dancing Links" (DLX) for exact cover problems |
| 1980s | N-queens and Sudoku become canonical teaching examples |
| 2000s | Codified as the standard interview pattern for enumeration problems |

---

## Performance

| Problem | Time (worst) | Space | With pruning |
|---|---|---|---|
| Subsets | O(2^n) | O(n) path depth | Same — must visit all subsets |
| Permutations | O(n! × n) | O(n) path + O(n) used | Same |
| Combination sum | O(2^(t/m)) | O(t/m) depth | Early break when candidate > remaining |
| N-queens | O(n!) | O(n) | ~O(n!) but pruning eliminates most branches |
| Sudoku | O(9^81) theoretical | O(81) | Constraint propagation makes it fast in practice |

**Allocation behaviour:** The path list and constraint tracking sets allocate on the heap. One result snapshot per valid solution (the `new List<T>(path)` copy). In tight loops with many solutions, result list growth can cause GC pressure — preallocate if profiling shows it.

**Benchmark notes:** Backtracking is exponential by nature. The goal isn't to eliminate this — you're generating all valid solutions — it's to prune invalid branches as early as possible. Sort before backtracking, check constraints before recursing (not inside the call), and break instead of continue when the remaining candidates are provably invalid.

---

## The Code

**Scenario 1 — subsets (enumerate all 2^n subsets)**
```csharp
public List<List<int>> Subsets(int[] nums)
{
    var result = new List<List<int>>();
    var path = new List<int>();

    void Backtrack(int start)
    {
        result.Add(new List<int>(path)); // snapshot: every path is a valid subset
        for (int i = start; i < nums.Length; i++)
        {
            path.Add(nums[i]);
            Backtrack(i + 1);
            path.RemoveAt(path.Count - 1); // undo
        }
    }

    Backtrack(0);
    return result;
}
```

**Scenario 2 — combination sum (reuse allowed, target sum)**
```csharp
public List<List<int>> CombinationSum(int[] candidates, int target)
{
    var result = new List<List<int>>();
    var path = new List<int>();
    Array.Sort(candidates); // enables break-based pruning

    void Backtrack(int start, int remaining)
    {
        if (remaining == 0) { result.Add(new List<int>(path)); return; }
        for (int i = start; i < candidates.Length; i++)
        {
            if (candidates[i] > remaining) break; // sorted: all further are also too large
            path.Add(candidates[i]);
            Backtrack(i, remaining - candidates[i]); // i not i+1: reuse allowed
            path.RemoveAt(path.Count - 1);
        }
    }

    Backtrack(0, target);
    return result;
}
```

**Scenario 3 — N-queens (constraint satisfaction with heavy pruning)**
```csharp
public int TotalNQueens(int n)
{
    int count = 0;
    var cols  = new HashSet<int>();
    var diag1 = new HashSet<int>(); // row - col (top-left to bottom-right diagonals)
    var diag2 = new HashSet<int>(); // row + col (top-right to bottom-left diagonals)

    void Backtrack(int row)
    {
        if (row == n) { count++; return; }
        for (int col = 0; col < n; col++)
        {
            if (cols.Contains(col) || diag1.Contains(row - col) || diag2.Contains(row + col))
                continue; // attacked square — prune

            cols.Add(col);  diag1.Add(row - col);  diag2.Add(row + col);
            Backtrack(row + 1);
            cols.Remove(col); diag1.Remove(row - col); diag2.Remove(row + col);
        }
    }

    Backtrack(0);
    return count;
}
```

**Scenario 4 — what NOT to do: snapshot path instead of undo**
```csharp
// BAD: creates a new list at every recursive call — O(n) allocation per node
public void BacktrackBad(int[] nums, int start, List<int> path, List<List<int>> result)
{
    result.Add(path); // adds a reference — path will be empty when recursion ends!
    for (int i = start; i < nums.Length; i++)
    {
        var newPath = new List<int>(path) { nums[i] }; // new allocation every call
        BacktrackBad(nums, i + 1, newPath, result);
    }
}

// GOOD: mutate one shared path, copy only when adding to results
public void BacktrackGood(int[] nums, int start, List<int> path, List<List<int>> result)
{
    result.Add(new List<int>(path)); // snapshot the current state
    for (int i = start; i < nums.Length; i++)
    {
        path.Add(nums[i]);
        BacktrackGood(nums, i + 1, path, result);
        path.RemoveAt(path.Count - 1); // undo — restores path for the next iteration
    }
}
```

---

## Real World Example

The `PermissionAssignmentService` in an access control system validates whether a set of requested permissions can be satisfied by assigning available roles, where each role covers a subset of permissions and a user may hold multiple roles. This is an exact cover problem — backtracking finds all valid role assignments or confirms none exists.

```csharp
public class PermissionAssignmentService
{
    public record Role(string Name, HashSet<string> Permissions);

    // Returns all minimal sets of roles that together cover all required permissions.
    // "Minimal" = no role in the set is redundant.
    public List<List<Role>> FindValidAssignments(
        List<Role> availableRoles,
        HashSet<string> requiredPermissions)
    {
        var result  = new List<List<Role>>();
        var current = new List<Role>();
        var covered = new HashSet<string>();

        void Backtrack(int start)
        {
            if (covered.IsSupersetOf(requiredPermissions))
            {
                result.Add(new List<Role>(current)); // found a valid assignment
                return;
            }

            for (int i = start; i < availableRoles.Count; i++)
            {
                var role = availableRoles[i];

                // Pruning: skip if this role adds no new permissions
                if (role.Permissions.IsSubsetOf(covered)) continue;

                // Choose
                current.Add(role);
                var newPermissions = new HashSet<string>(role.Permissions);
                newPermissions.ExceptWith(covered); // track what this role adds
                covered.UnionWith(role.Permissions);

                Backtrack(i + 1); // i+1: each role used at most once

                // Undo
                current.RemoveAt(current.Count - 1);
                covered.ExceptWith(newPermissions);
            }
        }

        Backtrack(0);
        return result;
    }
}
```

*The key insight: the pruning check (`role.Permissions.IsSubsetOf(covered)`) eliminates entire branches where a role is redundant — it adds no new permissions to the already-covered set. Without this, the algorithm visits every role combination; with it, it skips the majority in practice.*

---

## Common Misconceptions

**"Backtracking and recursion are the same thing"**
Recursion is a control-flow mechanism. Backtracking is a specific pattern that uses recursion with state mutation and undo. Not all recursive algorithms are backtracking — merge sort is recursive but not backtracking. The undo step is what makes it backtracking: you deliberately reverse the state change before trying the next choice.

**"result.Add(path) is safe"**
It adds a reference to the mutable path list, not a copy. When the recursion finishes unwinding, path is empty — all entries in result point to the same empty list. Always snapshot with `new List<T>(path)` or `.ToList()`.

**"Backtracking is exponential so it's not useful for real problems"**
The theoretical worst case is exponential, but with good pruning it's practical on real inputs. Sudoku has 9^81 theoretical combinations but a well-pruned backtracker solves any valid puzzle in milliseconds. N-queens for n=8 has only 92 solutions out of 8^8 = 16 million theoretical placements — pruning eliminates ~99.9% of candidates.

---

## Gotchas

- **Always snapshot the path when adding to results.** `result.Add(path)` adds a reference to the mutable path — it will be empty when the recursion unwinds. Use `result.Add(new List<int>(path))` or `result.Add(path.ToList())`.

- **Undo must pair with every do, exactly.** Every `path.Add(x)` must be matched with `path.RemoveAt(path.Count - 1)`. Every `visited.Add(x)` with `visited.Remove(x)`. Missing an undo corrupts state for all sibling branches silently — the bug is hard to spot because results look partially correct.

- **Sort before backtracking for pruning and deduplication.** Sorting enables the `if candidates[i] > remaining: break` pruning. It also makes duplicate-skipping (`if i > start && nums[i] == nums[i-1]: continue`) clean. Without sorting, deduplication requires a `HashSet<string>` per level — much more expensive.

- **Prune before recursing, not at the start of the call.** Checking the constraint at the top of the recursive function means you've already made the function call — stack frame allocated, overhead paid. Check before the recursive call to avoid it entirely.

- **Permutations need a `used[]` boolean array, not a `start` index.** Subsets and combination sum use a start index to prevent re-using earlier elements. Permutations use every element but not the same index twice — a `bool[] used` array tracks which indices are in the current path.

---

## Interview Angle

**What they're really testing:** Whether you know the backtracking template and can apply it cleanly — especially the snapshot-on-add and undo-after-recurse pattern — and whether you identify and implement pruning.

**Common question forms:**
- "Generate all subsets / permutations / combinations."
- "Combination sum (with/without duplicates)."
- "N-queens / Sudoku solver."
- "Word search on a 2D grid."
- "Palindrome partitioning / letter combinations of a phone number."

**The depth signal:** A junior generates combinations but adds path references (not copies) — all results are empty. A senior writes the template correctly from memory, adds pruning immediately (sort + break for combination sum, three-set attack tracking for N-queens), and explains the time complexity as O(b^d) where b is the branching factor and d is the depth — and how pruning reduces the effective branching factor.

**Follow-up questions to expect:**
- "How would you optimise this?" → Pruning strategy: sort, early break, constraint propagation.
- "How does this differ from DP?" → Backtracking lists all solutions; DP counts or finds the optimal one. "How many ways" → DP. "List all ways" → backtracking.

---

## Related Topics

- [[algorithms/searching/depth-first-search.md]] — Backtracking is DFS with state mutation and undo; the traversal mechanics are identical.
- [[algorithms/patterns/dynamic-programming.md]] — When you're counting ways (not enumerating them), DP is the right upgrade from backtracking.
- [[algorithms/problem-solving-frameworks/recursion-to-iteration.md]] — Backtracking is inherently recursive; converting it to iteration is non-trivial.
- [[algorithms/datastructures/stack.md]] — The call stack is the implicit data structure backing all backtracking algorithms.

---

## Source

https://en.wikipedia.org/wiki/Backtracking

---

*Last updated: 2026-04-21*