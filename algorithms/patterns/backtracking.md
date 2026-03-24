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
```python
def subsets(nums: list) -> list:
    result, path = [], []

    def backtrack(start: int) -> None:
        result.append(path[:])           # snapshot: every path is a valid subset
        for i in range(start, len(nums)):
            path.append(nums[i])
            backtrack(i + 1)
            path.pop()                   # undo

    backtrack(0)
    return result
```

**Permutations — enumerate all n! orderings**
```python
def permutations(nums: list) -> list:
    result, path, used = [], [], [False] * len(nums)

    def backtrack() -> None:
        if len(path) == len(nums):
            result.append(path[:])
            return
        for i in range(len(nums)):
            if used[i]:
                continue
            used[i] = True
            path.append(nums[i])
            backtrack()
            path.pop()
            used[i] = False              # undo

    backtrack()
    return result
```

**Combination sum — reuse allowed, find all combos summing to target**
```python
def combination_sum(candidates: list, target: int) -> list:
    result, path = [], []
    candidates.sort()

    def backtrack(start: int, remaining: int) -> None:
        if remaining == 0:
            result.append(path[:])
            return
        for i in range(start, len(candidates)):
            if candidates[i] > remaining:
                break                    # pruning: sorted, so all further are too large
            path.append(candidates[i])
            backtrack(i, remaining - candidates[i])   # i not i+1: reuse allowed
            path.pop()

    backtrack(0, target)
    return result
```

**N-queens — constraint satisfaction with heavy pruning**
```python
def solve_n_queens(n: int) -> list:
    result = []
    cols = set()
    diag1 = set()    # row - col
    diag2 = set()    # row + col

    def backtrack(row: int, path: list) -> None:
        if row == n:
            result.append(path[:])
            return
        for col in range(n):
            if col in cols or (row - col) in diag1 or (row + col) in diag2:
                continue                # pruning: attacked square
            cols.add(col)
            diag1.add(row - col)
            diag2.add(row + col)
            path.append(col)
            backtrack(row + 1, path)
            path.pop()
            cols.remove(col)
            diag1.remove(row - col)
            diag2.remove(row + col)

    backtrack(0, [])
    return result
```

**Word search — backtracking on a 2D grid**
```python
def word_search(board: list, word: str) -> bool:
    rows, cols = len(board), len(board[0])

    def backtrack(r: int, c: int, idx: int) -> bool:
        if idx == len(word):
            return True
        if r < 0 or r >= rows or c < 0 or c >= cols or board[r][c] != word[idx]:
            return False
        temp, board[r][c] = board[r][c], '#'         # mark visited
        found = any(backtrack(r+dr, c+dc, idx+1)
                    for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)])
        board[r][c] = temp                            # restore
        return found

    return any(backtrack(r, c, 0) for r in range(rows) for c in range(cols))
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