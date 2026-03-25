# Common Patterns Map
> A reference map from problem signal to algorithm pattern — the mental model for recognizing which tool to reach for before writing any code.

---

## When To Use It
Use this as a first-pass diagnostic when reading a new problem. Pattern recognition is the highest-leverage skill in algorithm interviews — it converts "I've never seen this problem" into "I've seen this structure before." This file is not an algorithm. It's the index into all the other algorithm files.

---

## Core Concept
Most algorithm problems are variations on a small number of structural patterns. The problem statement contains signals — keywords, constraints, input types — that point to a pattern. Learning to read those signals is what separates someone who solves problems they've memorized from someone who solves problems they've never seen.

The map below is organized by signal (what you read in the problem) → pattern (what to reach for) → file (where to learn it).

---

## The Code

**The full pattern map**
```csharp
var patternMap = new Dictionary<string, string>
{
    // ── ARRAY PROBLEMS ──────────────────────────────────────────────────────
    { "find pair/triplet with target sum in sorted array", "two pointers → two-pointers.md" },
    { "longest/shortest subarray or substring with constraint", "sliding window → sliding-window.md" },
    { "subarray with exactly k [distinct/odd/etc]", "sliding window: exactly(k) = atMost(k) - atMost(k-1) → sliding-window.md" },
    { "maximum subarray sum", "Kadane's algorithm (greedy DP) → dynamic-programming.md" },
    { "range sum query on mutable array", "segment tree → segment-tree.md" },
    { "range sum query on immutable array", "prefix sums → array.md" },
    { "sorted array + find value or boundary", "binary search → binary-search.md" },
    { "find minimum X such that condition(X) is true", "binary search on answer space → binary-search.md" },

    // ── LINKED LIST PROBLEMS ─────────────────────────────────────────────────
    { "detect cycle in linked list", "fast/slow pointers → fast-slow-pointers.md" },
    { "find cycle entry point", "fast/slow pointers phase 2 → fast-slow-pointers.md" },
    { "find middle of linked list", "fast/slow pointers → fast-slow-pointers.md" },
    { "kth node from end", "fast/slow pointers with k-step head start → fast-slow-pointers.md" },

    // ── TREE PROBLEMS ────────────────────────────────────────────────────────
    { "tree traversal (inorder/preorder/postorder)", "DFS → depth-first-search.md" },
    { "level order traversal / minimum depth", "BFS → breadth-first-search.md" },
    { "lowest common ancestor", "DFS with return-value pattern → tree.md" },
    { "validate BST / sorted order", "inorder DFS on BST → balanced-bst.md" },

    // ── GRAPH PROBLEMS ───────────────────────────────────────────────────────
    { "shortest path, unweighted graph or grid", "BFS → breadth-first-search.md" },
    { "shortest path, weighted graph, non-negative weights", "Dijkstra → dijkstra.md" },
    { "shortest path with spatial heuristic (game maps, GPS)", "A* → a-star.md" },
    { "detect cycle in directed graph", "three-color DFS → depth-first-search.md" },
    { "topological sort / course schedule", "Kahn's BFS or DFS postorder → graph.md" },
    { "number of islands / connected components", "DFS or BFS flood fill → depth-first-search.md" },
    { "all paths from source to target", "DFS backtracking → backtracking.md" },

    // ── STRING PROBLEMS ──────────────────────────────────────────────────────
    { "prefix search / autocomplete / word starts with", "trie → trie.md" },
    { "longest common subsequence / edit distance", "2D DP → dynamic-programming.md" },
    { "anagram / substring / window over characters", "sliding window + frequency map → sliding-window.md" },

    // ── OPTIMIZATION / COUNTING ──────────────────────────────────────────────
    { "count ways to do X / minimum cost to reach Y", "dynamic programming → dynamic-programming.md" },
    { "locally optimal choice leads to global optimum", "greedy → greedy-algorithms.md" },
    { "interval scheduling / non-overlapping intervals", "greedy, sort by end time → greedy-algorithms.md" },
    { "top-k elements / kth largest / streaming median", "heap → heap.md" },
    { "merge k sorted lists", "heap (k-way merge) → heap.md" },

    // ── ENUMERATION ─────────────────────────────────────────────────────────
    { "enumerate all subsets / combinations / permutations", "backtracking → backtracking.md" },
    { "Sudoku / N-queens / constraint satisfaction", "backtracking with pruning → backtracking.md" },
    { "subsets as state (small n ≤ 20)", "bitmask DP → bit-manipulation.md + dynamic-programming.md" },

    // ── BIT / MATH ──────────────────────────────────────────────────────────
    { "find unpaired element / XOR trick", "bit manipulation → bit-manipulation.md" },
    { "check power of 2 / count set bits", "bit manipulation → bit-manipulation.md" },

    // ── DIVIDE AND CONQUER ───────────────────────────────────────────────────
    { "independent subproblems of same form", "divide and conquer → divide-and-conquer.md" },
    { "overlapping subproblems of same form", "dynamic programming → dynamic-programming.md" },
};
```

**Decision tree for the five most common interview problem types**
```csharp
/// <summary>
/// Decision tree for diagnosing problem type and choosing algorithm
/// </summary>
public void FirstQuestionsToAsk(string problem)
{
    /*
    Q1: Is the input sorted, or can I sort it?
        YES → binary search or two pointers
        NO  → continue

    Q2: Does the problem involve a contiguous subarray/substring?
        YES → sliding window
        NO  → continue

    Q3: Is it a graph or tree problem?
        YES → shortest path? → BFS/Dijkstra
              all paths / cycle? → DFS
        NO  → continue

    Q4: Is it asking to count ways or find optimal value?
        YES → does it have overlapping subproblems? → DP
              can greedy choice be proven safe? → greedy
        NO  → continue

    Q5: Is it asking to enumerate all valid combinations?
        YES → backtracking
    */
}

---

## Gotchas

- **A problem can match multiple patterns.** "Find the longest subarray with exactly k distinct values" is both sliding window and uses a hash map. Start with the dominant pattern and layer in supporting structures.
- **The pattern is a starting point, not the solution.** Knowing "this is a DP problem" is 20% of the work. Defining the state correctly is the other 80%.
- **Wrong pattern recognition wastes the entire interview.** A BFS solution on a problem requiring DP will never converge. If you've been coding for 10 minutes and are making no progress, stop, re-read the problem, and re-pattern-match.
- **"Count ways" is almost always DP; "find all ways" is almost always backtracking.** This distinction is not obvious from problem wording but is almost universally true. "How many paths?" → DP. "List all paths?" → backtracking or DFS.
- **Grid problems are implicit graphs.** Every grid problem is a graph problem. The cells are vertices; edges connect adjacent cells. You don't need an adjacency list — compute neighbors on the fly. BFS for shortest path, DFS for connectivity.

---

## Interview Angle

**What they're really testing:** Speed and accuracy of pattern recognition under pressure — not whether you've memorized a specific problem.

**Common question form:** Every algorithm problem. This map is the meta-skill behind all of them.

**The depth signal:** A junior solves problems they've seen before. A senior reads a new problem, identifies the structural pattern within 60 seconds, and names the algorithm before touching code. The real separator is handling hybrid problems — "this is sliding window with a monotonic deque" or "this is BFS but multi-source" — which requires knowing not just the patterns but how they compose.

---

## Related Topics

- [[algorithms/interview-problem-solving.md]] — The process framework that uses this map in Phase 3.
- [[algorithms/complexity-analysis.md]] — Each pattern has a characteristic complexity; knowing them together is the complete picture.
- [[algorithms/dynamic-programming.md]] — The deepest pattern; warrants its own study track.

---

## Source

https://leetcode.com/explore/interview/card/leetcodes-interview-crash-course-data-structures-and-algorithms/

---

*Last updated: 2026-03-24*