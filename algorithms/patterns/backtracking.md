# Backtracking
> A DFS-based technique that builds solutions incrementally, abandoning (pruning) any partial solution that cannot lead to a valid result.

---

## When To Use It
Use backtracking when you need to enumerate all valid combinations, permutations, subsets, or configurations — and many partial states can be ruled out early. It's the right tool for constraint satisfaction problems: N-queens, Sudoku, word search, subset sum. Backtracking is exhaustive search made tolerable by pruning. Without pruning, it's brute-force O(n!). Good pruning can make it practically fast even when worst-case is still exponential.

---

## Core Concept
Backtracking is DFS with state mutation and undo. At each step, make a choice (add to path), recurse, then undo the choice (remove from path) before trying the next option. The critical insight: you're not creating a new copy of the state at each level — you're mutating one shared state and restoring it. This is what makes backtracking memory-efficient compared to creating a new list at every branch.

Pruning is where backtracking separates itself from naive enumeration. Before making a choice, check if it violates any constraint. If it does, skip it entirely — don't recurse into that branch at all.

---

## The Code

**Subsets — enumerate all 2^n subsets**
```csharp
public List<List<int>> Subsets(int[] nums)
{
    var result = new List<List<int>>();
    var path = new List<int>();

    void Backtrack(int start)
    {
        result.Add(new List<int>(path));  // snapshot: every path is a valid subset
        for (int i = start; i < nums.Length; i++)
        {
            path.Add(nums[i]);
            Backtrack(i + 1);
            path.RemoveAt(path.Count - 1);  // undo
        }
    }

    Backtrack(0);
    return result;
}
```

**Permutations — enumerate all n! orderings**
```csharp
public List<List<int>> Permutations(int[] nums)
{
    var result = new List<List<int>>();
    var path = new List<int>();
    var used = new bool[nums.Length];

    void Backtrack()
    {
        if (path.Count == nums.Length)
        {
            result.Add(new List<int>(path));
            return;
        }
        for (int i = 0; i < nums.Length; i++)
        {
            if (used[i])
                continue;
            used[i] = true;
            path.Add(nums[i]);
            Backtrack();
            path.RemoveAt(path.Count - 1);
            used[i] = false;  // undo
        }
    }

    Backtrack();
    return result;
}
```

**Combination sum — reuse allowed, find all combos summing to target**
```csharp
public List<List<int>> CombinationSum(int[] candidates, int target)
{
    var result = new List<List<int>>();
    var path = new List<int>();
    Array.Sort(candidates);

    void Backtrack(int start, int remaining)
    {
        if (remaining == 0)
        {
            result.Add(new List<int>(path));
            return;
        }
        for (int i = start; i < candidates.Length; i++)
        {
            if (candidates[i] > remaining)
                break;  // pruning: sorted, so all further are too large
            path.Add(candidates[i]);
            Backtrack(i, remaining - candidates[i]);  // i not i+1: reuse allowed
            path.RemoveAt(path.Count - 1);
        }
    }

    Backtrack(0, target);
    return result;
}
```

**N-queens — constraint satisfaction with heavy pruning**
```csharp
public List<List<int>> SolveNQueens(int n)
{
    var result = new List<List<int>>();
    var cols = new HashSet<int>();
    var diag1 = new HashSet<int>();  // row - col
    var diag2 = new HashSet<int>();  // row + col
    var path = new List<int>();

    void Backtrack(int row)
    {
        if (row == n)
        {
            result.Add(new List<int>(path));
            return;
        }
        for (int col = 0; col < n; col++)
        {
            if (cols.Contains(col) || diag1.Contains(row - col) || diag2.Contains(row + col))
                continue;  // pruning: attacked square
            cols.Add(col);
            diag1.Add(row - col);
            diag2.Add(row + col);
            path.Add(col);
            Backtrack(row + 1);
            path.RemoveAt(path.Count - 1);
            cols.Remove(col);
            diag1.Remove(row - col);
            diag2.Remove(row + col);
        }
    }

    Backtrack(0);
    return result;
}
```

**Word search — backtracking on a 2D grid**
```csharp
public bool WordSearch(char[][] board, string word)
{
    int rows = board.Length, cols = board[0].Length;

    bool Backtrack(int r, int c, int idx)
    {
        if (idx == word.Length)
            return true;
        if (r < 0 || r >= rows || c < 0 || c >= cols || board[r][c] != word[idx])
            return false;
        char temp = board[r][c];
        board[r][c] = '#';  // mark visited
        bool found = Backtrack(r - 1, c, idx + 1) || Backtrack(r + 1, c, idx + 1) ||
                     Backtrack(r, c - 1, idx + 1) || Backtrack(r, c + 1, idx + 1);
        board[r][c] = temp;  // restore
        return found;
    }

    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            if (Backtrack(r, c, 0))
                return true;
    return false;
}
```

---

## Gotchas

- **Always copy the path when adding to results.** `result.append(path)` adds a reference to the mutable path — it will be empty when the recursion is done. Use `result.append(path[:])` or `result.append(list(path))`.
- **Undo must be paired with every do, exactly.** Every `path.append(x)` must be matched with `path.pop()`. Every `visited.add(x)` must be matched with `visited.remove(x)`. Missing an undo corrupts state for all sibling branches.
- **Sort before backtracking for deduplication or pruning.** Sorting enables the `if candidates[i] > remaining: break` pruning. It also makes duplicate-skipping (`if i > start and nums[i] == nums[i-1]: continue`) straightforward.
- **Pruning position matters: prune before recursing.** Checking the constraint at the start of the recursive call is late — you've already entered the call. Check before the recursive call to avoid the function call overhead entirely.
- **Backtracking is exponential by nature.** O(2^n) for subsets, O(n!) for permutations. The goal isn't to eliminate this — you're generating all valid solutions — it's to prune invalid branches as early as possible. A solution that skips half the tree is 2× faster but still exponential.

---

## Interview Angle

**What they're really testing:** Whether you know the backtracking template and can apply it cleanly — especially the snapshot-on-append and undo-after-recurse pattern — and whether you identify and implement pruning.

**Common question form:** Subsets, permutations, combination sum, N-queens, Sudoku solver, word search, palindrome partitioning, letter combinations of a phone number.

**The depth signal:** A junior generates combinations but appends path references (not copies) — all results are empty. A senior writes the template correctly from memory, adds pruning immediately (sort + break for combination sum, three-set attack tracking for N-queens), and can explain the time complexity as O(b^d) where b is the branching factor and d is the depth — and how pruning reduces the effective branching factor.

---

## Related Topics

- [[algorithms/depth-first-search.md]] — Backtracking is DFS with state mutation; the traversal mechanics are identical.
- [[algorithms/dynamic-programming.md]] — When you're counting ways (not enumerating them), DP is often the right upgrade from backtracking.
- [[algorithms/recursion-to-iteration.md]] — Backtracking is inherently recursive; understanding the call stack helps when converting.

---

## Source

https://en.wikipedia.org/wiki/Backtracking

---

*Last updated: 2026-03-24*