# Domain 5 — Data Structures & Algorithms

## Phonebook

**63 topics across 13 groups.** Priority 1 = Critical → Priority 4 = Reference `[ ]` = not yet generated | `[x]` = generated

---

## How to Use This File

1. Pick a topic by priority tier — generate Tier 1 topics before Tier 2, and so on.
2. Open `_main_dsa.md` to retrieve the generation spec.
3. Call: "Generate note 5.XXX — [Topic Name]"
4. Mark `[x]` when the note is saved to the vault.

---

## Group A — Foundations

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.001|Big-O Notation and Complexity Analysis|1|[ ]|
|5.002|Recursion and the Call Stack|1|[ ]|
|5.003|Problem-Solving Framework|2|[ ]|

### Cross-References — Group A

- `[[5.001]]` is a prerequisite for every other note in this domain — it must be generated first
- `[[5.001]]` → `[[2.XXX — CLR Internals and Memory Model]]` — understanding stack vs. heap connects Big-O space analysis to .NET memory behavior
- `[[5.002]]` → `[[5.001]]` — recursion analysis requires Big-O; the call stack is the space complexity
- `[[5.002]]` → `[[5.059 — DP Fundamentals]]` — memoization is recursion with a cache; the connection must be explicit
- `[[5.002]]` → `[[5.055 — Backtracking Template]]` — all backtracking is recursive; Section 3 of this note seeds that connection
- `[[5.003]]` → `[[5.001]]` — the problem-solving framework includes a complexity estimation step that depends on Big-O fluency

---

## Group B — Arrays and Strings

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.004|Arrays — Fixed, Dynamic, and In-Place Operations|1|[ ]|
|5.005|Two Pointers|1|[ ]|
|5.006|Sliding Window|1|[ ]|
|5.007|Prefix Sums|2|[ ]|
|5.008|Kadane's Algorithm — Maximum Subarray|2|[ ]|
|5.009|String Manipulation and Pattern Problems|2|[ ]|

### Cross-References — Group B

- `[[5.004]]` → `[[2.XXX — Span<T> and Memory<T>]]` — in-place array operations in .NET are the primary use case for Span<T>
- `[[5.004]]` → `[[5.005]]` — Two Pointers operates on arrays; the in-place foundation is required
- `[[5.005]]` ↔ `[[5.006]]` — Two Pointers and Sliding Window are related patterns; the note must distinguish them clearly: Two Pointers converges from both ends or chases from the same direction; Sliding Window maintains a contiguous range
- `[[5.005]]` → `[[5.011 — Fast and Slow Pointers]]` — same pointer technique applied to linked lists
- `[[5.006]]` → `[[5.022 — Sliding Window with Hash Map]]` — variable-size sliding window requires a hash map to track window state
- `[[5.007]]` → `[[5.004]]` — prefix sums operate on arrays; the foundation is required
- `[[5.007]]` → `[[5.061 — 2D DP]]` — 2D prefix sums appear in matrix DP problems
- `[[5.008]]` → `[[5.059 — DP Fundamentals]]` — Kadane's is the simplest 1D DP problem; the note should make the DP recurrence explicit
- `[[5.009]]` → `[[5.019 — Hash Maps and Hash Sets]]` — anagram detection and character frequency require hash maps
- `[[5.009]]` → `[[5.026 — Tries]]` — prefix matching and word search are the trie use case

---

## Group C — Linked Lists

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.010|Singly and Doubly Linked Lists|3|[ ]|
|5.011|Fast and Slow Pointers — Floyd's Cycle Detection|2|[ ]|
|5.012|Linked List Reversal|2|[ ]|
|5.013|Merge Two Sorted Lists|3|[ ]|
|5.014|Find Middle Node and Remove Nth from End|3|[ ]|

### Cross-References — Group C

- `[[5.010]]` → `[[5.004 — Arrays]]` — the core comparison: cache locality of arrays vs. pointer-following cost of linked lists
- `[[5.010]]` → `[[2.XXX — LinkedList<T> in .NET]]` — .NET's `LinkedList<T>` is doubly linked; the note must cover when it beats `List<T>` (O(1) insert at known node) and when it doesn't (cache miss penalty)
- `[[5.011]]` → `[[5.005 — Two Pointers]]` — fast/slow is Two Pointers applied to a linked list; the same convergence intuition
- `[[5.011]]` → `[[5.010]]` — Floyd's requires understanding node structure
- `[[5.012]]` → `[[5.010]]` — reversal requires understanding next/prev pointer manipulation
- `[[5.013]]` → `[[5.034 — Merge K Sorted Lists]]` — merge two sorted lists is the base case that Merge K builds on; note must connect them
- `[[5.014]]` → `[[5.011]]` — finding middle uses fast/slow; removing Nth uses two pointers with a gap

---

## Group D — Stacks and Queues

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.015|Stack — LIFO Applications and Balanced Parentheses|1|[ ]|
|5.016|Queue — FIFO and BFS Applications|2|[ ]|
|5.017|Monotonic Stack Pattern|2|[ ]|
|5.018|Deque — Double-Ended Queue and Sliding Window Maximum|3|[ ]|

### Cross-References — Group D

- `[[5.015]]` → `[[2.XXX — Stack<T> in .NET]]` — `Stack<T>` is the built-in; the note must cover when to use a `List<T>` as a stack instead (index access needed)
- `[[5.015]]` → `[[5.002 — Recursion]]` — DFS uses the call stack implicitly; iterative DFS uses an explicit stack. This connection must appear in Section 4
- `[[5.016]]` → `[[5.037 — BFS]]` — BFS requires a queue; this note is the prerequisite. Section 4 must show the BFS skeleton using `Queue<T>`
- `[[5.016]]` → `[[2.XXX — Queue<T> and Channel<T>]]` — `Channel<T>` in System.Threading.Channels is the production async queue
- `[[5.017]]` → `[[5.015 — Stack]]` — Monotonic Stack is a constrained stack; the stack note is a prerequisite
- `[[5.017]]` → `[[5.006 — Sliding Window]]` — Sliding Window Maximum uses a monotonic deque; the two patterns overlap on the "next greater element" problem class
- `[[5.018]]` → `[[5.017 — Monotonic Stack]]` — sliding window maximum specifically requires a monotonic deque; this note is the application

---

## Group E — Hash Maps and Sets

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.019|Hash Maps and Hash Sets — Design and Collision Handling|1|[ ]|
|5.020|Two-Sum Pattern and Generalizations|1|[ ]|
|5.021|Frequency Counting and Grouping|2|[ ]|
|5.022|Sliding Window with Hash Map|2|[ ]|

### Cross-References — Group E

- `[[5.019]]` → `[[2.XXX — Dictionary<TKey,TValue> and HashSet<T>]]` — .NET internals: open addressing in `Dictionary<TKey,TValue>`, how `GetHashCode()` and `Equals()` interact, why custom key types need both
- `[[5.019]]` → `[[5.001 — Big-O]]` — amortized O(1) for hash map operations must be derived here; worst-case O(n) on collision must be addressed
- `[[5.020]]` → `[[5.019]]` — Two-Sum requires a hash map; the structure note is a prerequisite
- `[[5.020]]` → `[[5.005 — Two Pointers]]` — Two-Sum on a sorted array is solved with Two Pointers; the note must compare both approaches explicitly
- `[[5.021]]` → `[[5.019]]` — frequency counting is a hash map application
- `[[5.021]]` → `[[5.039 — Topological Sort]]` — in-degree counting in Kahn's algorithm is frequency counting applied to graphs
- `[[5.022]]` → `[[5.006 — Sliding Window]]` — variable-size sliding window is the trigger for combining these two patterns
- `[[5.022]]` → `[[5.019]]` — the hash map tracks window state; both prerequisites required

---

## Group F — Trees

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.023|Binary Tree Traversals — Pre, In, Post, Level-Order|1|[ ]|
|5.024|Binary Search Tree — Operations and Validation|1|[ ]|
|5.025|Balanced BSTs — AVL and Red-Black (Conceptual)|3|[ ]|
|5.026|Tries — Prefix Trees|2|[ ]|
|5.027|Lowest Common Ancestor|2|[ ]|
|5.028|Binary Tree — Diameter, Serialize/Deserialize, Path Problems|2|[ ]|
|5.029|Segment Trees|3|[ ]|
|5.030|Binary Indexed Tree (Fenwick Tree)|4|[ ]|

### Cross-References — Group F

- `[[5.023]]` → `[[5.015 — Stack]]` — iterative DFS traversal (pre/in/post) uses an explicit stack; Section 4 must show both recursive and iterative versions
- `[[5.023]]` → `[[5.016 — Queue]]` — level-order traversal is BFS using a queue
- `[[5.023]]` → `[[5.037 — BFS]]` — level-order is BFS on a tree; the graph BFS note generalizes this
- `[[5.024]]` → `[[5.023]]` — BST operations require traversal understanding
- `[[5.024]]` → `[[5.025]]` — BST note must explain why balance matters and that AVL/Red-Black solve the degeneration problem
- `[[5.024]]` → `[[2.XXX — SortedSet<T> and SortedDictionary<TKey,TValue>]]` — .NET's sorted collections use Red-Black trees internally
- `[[5.025]]` → `[[5.024]]` — balanced BSTs are an evolution of the basic BST; prerequisite required
- `[[5.026]]` → `[[5.009 — String Manipulation]]` — tries are built for string prefix problems; the connection must be explicit
- `[[5.026]]` → `[[5.023]]` — trie traversal mirrors tree traversal patterns
- `[[5.027]]` → `[[5.023]]` — LCA requires traversal; both recursive and iterative approaches shown
- `[[5.027]]` → `[[5.040 — Union-Find]]` — LCA in general graphs uses Union-Find (Tarjan's offline LCA algorithm)
- `[[5.028]]` → `[[5.023]]` — diameter, path sum, and serialization all require traversal as the foundation
- `[[5.028]]` → `[[5.002 — Recursion]]` — path problems require post-order DFS with return values; the recursion note seeds this
- `[[5.029]]` → `[[5.007 — Prefix Sums]]` — segment trees generalize prefix sums to support range updates
- `[[5.030]]` → `[[5.029]]` — Fenwick tree is a space-optimized alternative to segment trees for specific query types

---

## Group G — Heaps and Priority Queues

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.031|Min-Heap and Max-Heap — Structure and Heapify|1|[ ]|
|5.032|PriorityQueue in .NET — Correct Usage and Patterns|3|[ ]|
|5.033|Top-K and K-th Element Problems|2|[ ]|
|5.034|Merge K Sorted Lists|2|[ ]|
|5.035|Median of a Data Stream — Two Heaps|2|[ ]|

### Cross-References — Group G

- `[[5.031]]` → `[[5.004 — Arrays]]` — a binary heap is stored as an array; the index arithmetic (parent = (i-1)/2, left = 2i+1, right = 2i+2) must be derived
- `[[5.031]]` → `[[5.049 — Sorting]]` — heap sort is built directly from the heap structure; the sort note references this
- `[[5.031]]` → `[[5.041 — Dijkstra's]]` — Dijkstra's uses a min-heap as its priority queue; this note is a prerequisite
- `[[5.032]]` → `[[5.031]]` — `PriorityQueue<TElement,TPriority>` is .NET's heap; the scratch implementation note is the prerequisite
- `[[5.032]]` → `[[2.XXX — PriorityQueue<TElement,TPriority> in .NET 6+]]` — the API changed significantly in .NET 6; the note must cover the correct API including the separate priority parameter
- `[[5.033]]` → `[[5.031]]` — Top-K uses a min-heap of size K; the heap note is required
- `[[5.033]]` → `[[5.049 — Sorting]]` — Top-K via sort is O(n log n); via heap is O(n log k) — the comparison must be explicit
- `[[5.034]]` → `[[5.013 — Merge Two Sorted Lists]]` — merge K is a generalization of merge two; the two-list note must come first
- `[[5.034]]` → `[[5.031]]` — the K-way merge uses a heap to select the minimum across K lists in O(log K)
- `[[5.035]]` → `[[5.031]]` — two heaps (max-heap for lower half, min-heap for upper half) is the data structure insight
- `[[5.035]]` → `[[5.033]]` — median is a K-th element variant; the connection must be explicit

---

## Group H — Graphs

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.036|Graph Representation — Adjacency List and Matrix|2|[ ]|
|5.037|BFS — Shortest Path, Level-Order, Multi-Source|1|[ ]|
|5.038|DFS — Cycle Detection, Connected Components, Islands|1|[ ]|
|5.039|Topological Sort — Kahn's and DFS-Based|1|[ ]|
|5.040|Union-Find (Disjoint Set Union)|1|[ ]|
|5.041|Dijkstra's Algorithm|1|[ ]|
|5.042|Bellman-Ford Algorithm|3|[ ]|
|5.043|Floyd-Warshall — All-Pairs Shortest Path|4|[ ]|
|5.044|Minimum Spanning Tree — Kruskal's and Prim's|3|[ ]|
|5.045|Strongly Connected Components — Tarjan's and Kosaraju's|3|[ ]|

### Cross-References — Group H

- `[[5.036]]` is a prerequisite for every other note in Group H; must be generated first within the group
- `[[5.036]]` → `[[5.019 — Hash Maps]]` — adjacency lists are implemented as `Dictionary<int, List<int>>` in C#; the hash map note is a prerequisite
- `[[5.037]]` → `[[5.016 — Queue]]` — BFS requires a queue; Section 4 must use `Queue<T>` explicitly
- `[[5.037]]` → `[[5.036]]` — BFS operates on a graph; representation prerequisite required
- `[[5.037]]` → `[[5.041 — Dijkstra's]]` — BFS is Dijkstra's on an unweighted graph; the note must state this connection
- `[[5.038]]` → `[[5.015 — Stack]]` — iterative DFS uses an explicit stack; both recursive and iterative shown
- `[[5.038]]` → `[[5.036]]` — DFS operates on a graph
- `[[5.038]]` → `[[5.039 — Topological Sort]]` — DFS-based topological sort is the natural extension; Section 4 seeds this
- `[[5.039]]` → `[[5.037]]` — Kahn's algorithm is BFS-based; the BFS note is a prerequisite
- `[[5.039]]` → `[[5.038]]` — DFS-based topological sort is the alternative; both shown in Section 4
- `[[5.040]]` → `[[5.044 — MST]]` — Kruskal's algorithm uses Union-Find to detect cycles; this note is a prerequisite for that one
- `[[5.040]]` → `[[5.038]]` — Union-Find solves the same connected components problem as DFS; the comparison must be explicit in Section 8
- `[[5.041]]` → `[[5.031 — Heaps]]` — Dijkstra's priority queue is a min-heap; the heap note is a prerequisite
- `[[5.041]]` → `[[5.037 — BFS]]` — Dijkstra's is BFS with weighted edges and a priority queue instead of a regular queue
- `[[5.042]]` → `[[5.041]]` — Bellman-Ford solves the same problem as Dijkstra's but handles negative edges; the comparison is the core teaching
- `[[5.043]]` → `[[5.041]]` → `[[5.042]]` — Floyd-Warshall solves all-pairs; the other two solve single-source; context required
- `[[5.044]]` → `[[5.040 — Union-Find]]` — Kruskal's requires Union-Find; the prerequisite must be listed
- `[[5.044]]` → `[[5.031 — Heaps]]` — Prim's uses a min-heap like Dijkstra's; the comparison is natural
- `[[5.045]]` → `[[5.038 — DFS]]` — Tarjan's and Kosaraju's are both DFS-based; DFS is the prerequisite

---

## Group I — Binary Search

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.046|Binary Search — Classic Implementation and Off-by-One Discipline|1|[ ]|
|5.047|Binary Search on the Answer|2|[ ]|
|5.048|Binary Search Variants — Rotated Array, 2D Matrix, Peak Element|2|[ ]|

### Cross-References — Group I

- `[[5.046]]` → `[[5.004 — Arrays]]` — binary search operates on sorted arrays; the in-place and index arithmetic foundation is required
- `[[5.046]]` → `[[5.001 — Big-O]]` — the O(log n) derivation (halving the search space each step) must be shown explicitly
- `[[5.046]]` is a prerequisite for `[[5.047]]` and `[[5.048]]`
- `[[5.047]]` → `[[5.046]]` — binary search on the answer is the same algorithm applied to a monotonic predicate space rather than an array
- `[[5.047]]` → `[[5.052 — Greedy Choice Property]]` — the answer-space problems (ship packages, capacity minimization) use greedy validation within the binary search loop
- `[[5.048]]` → `[[5.046]]` — all variants are modifications of the classic implementation; Section 3 must derive why the standard template fails for each variant and how to adapt it

---

## Group J — Sorting

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.049|Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort|1|[ ]|
|5.050|Non-Comparison Sorting — Counting, Radix, Bucket Sort|3|[ ]|
|5.051|Sorting in .NET — Array.Sort, List.Sort, Custom Comparers, Stability|3|[ ]|

### Cross-References — Group J

- `[[5.049]]` → `[[5.002 — Recursion]]` — merge sort and quick sort are recursive; the recurrence T(n) = 2T(n/2) + O(n) must be solved with the Master Theorem
- `[[5.049]]` → `[[5.031 — Heaps]]` — heap sort is built on the heap; the heap note is a prerequisite
- `[[5.049]]` → `[[5.001 — Big-O]]` — the O(n log n) lower bound proof for comparison-based sorting must appear here
- `[[5.049]]` → `[[5.051]]` — .NET's introsort (hybrid of quicksort + heapsort + insertion sort) is the production version of what this note teaches
- `[[5.050]]` → `[[5.001 — Big-O]]` — non-comparison sorting breaks the O(n log n) barrier; the note must explain why the bound does not apply
- `[[5.051]]` → `[[5.049]]` — the .NET implementation note assumes knowledge of the underlying algorithms
- `[[5.051]]` → `[[2.XXX — IComparable<T> and IComparer<T>]]` — custom comparers are C# language features; the cross-reference is required

---

## Group K — Greedy Algorithms

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.052|Greedy Choice Property and Optimal Substructure|2|[ ]|
|5.053|Interval Scheduling — Activity Selection and Merging Overlapping Intervals|2|[ ]|
|5.054|Common Greedy Patterns — Jump Game, Gas Station, Task Scheduler|2|[ ]|

### Cross-References — Group K

- `[[5.052]]` → `[[5.059 — DP Fundamentals]]` — greedy and DP both require optimal substructure; the key difference is that greedy makes a local choice without reconsidering; Section 3 must make this comparison explicit
- `[[5.052]]` is a prerequisite for `[[5.053]]` and `[[5.054]]`
- `[[5.053]]` → `[[5.049 — Sorting]]` — interval problems require sorting by start or end time as the first step
- `[[5.053]]` → `[[5.052]]` — the greedy choice proof (sorting by end time) must be shown
- `[[5.054]]` → `[[5.052]]` — each pattern in this note requires proving the greedy choice property; Section 3 does this per pattern
- `[[5.054]]` → `[[5.031 — Heaps]]` — Task Scheduler uses a max-heap to always execute the most frequent remaining task

---

## Group L — Backtracking

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.055|Backtracking Template — Choose, Explore, Unchoose|1|[ ]|
|5.056|Permutations and Combinations|2|[ ]|
|5.057|Subsets and Power Set|2|[ ]|
|5.058|Grid and Board Problems — N-Queens, Sudoku, Word Search|2|[ ]|

### Cross-References — Group L

- `[[5.055]]` → `[[5.002 — Recursion]]` — backtracking is recursive by definition; the call stack and base case structure must reference the recursion note
- `[[5.055]]` is a prerequisite for `[[5.056]]`, `[[5.057]]`, and `[[5.058]]`
- `[[5.055]]` → `[[5.059 — DP Fundamentals]]` — backtracking with memoization is DP; Section 8 must include a decision rule for when to add memoization
- `[[5.056]]` → `[[5.055]]` — permutations and combinations are direct applications of the backtracking template with different pruning rules
- `[[5.057]]` → `[[5.055]]` — subsets are backtracking with an include/exclude choice at each element
- `[[5.057]]` → `[[5.060 — 1D DP]]` — the subset-sum problem connects backtracking and DP; the note must flag this
- `[[5.058]]` → `[[5.038 — DFS]]` — grid problems use DFS with visited state; the graph DFS note is the conceptual parent
- `[[5.058]]` → `[[5.055]]` — N-Queens and Sudoku are backtracking with constraint pruning; the template is the prerequisite

---

## Group M — Dynamic Programming

|ID|Topic|Priority|Generated|
|---|---|---|---|
|5.059|DP Fundamentals — Recognizing Problems, Memoization vs Tabulation|1|[ ]|
|5.060|1D Dynamic Programming — Climbing Stairs, House Robber, Coin Change, Word Break, LIS|1|[ ]|
|5.061|2D Dynamic Programming — Unique Paths, LCS, Edit Distance, Knapsack|2|[ ]|
|5.062|Interval DP — Burst Balloons, Palindromic Substrings, Matrix Chain|3|[ ]|
|5.063|DP on Trees and Graphs — House Robber III, Shortest Path with K Stops|3|[ ]|

### Cross-References — Group M

- `[[5.059]]` → `[[5.002 — Recursion]]` — top-down DP (memoization) is recursion with a cache; understanding the call tree is required
- `[[5.059]]` → `[[5.052 — Greedy Choice Property]]` — DP vs. greedy decision requires understanding optimal substructure in both; the comparison must be explicit
- `[[5.059]]` is a prerequisite for `[[5.060]]`, `[[5.061]]`, `[[5.062]]`, `[[5.063]]`
- `[[5.060]]` → `[[5.059]]` — each 1D problem is introduced with its recurrence relation derived from first principles
- `[[5.060]]` → `[[5.008 — Kadane's Algorithm]]` — maximum subarray is the simplest 1D DP; Kadane's is the space-optimized form
- `[[5.060]]` → `[[5.046 — Binary Search]]` — LIS via patience sorting uses binary search; the O(n log n) solution must be shown alongside the O(n²) DP
- `[[5.061]]` → `[[5.060]]` — 2D DP builds on 1D; the dimensional extension must be explained conceptually
- `[[5.061]]` → `[[5.007 — Prefix Sums]]` — some 2D DP problems use 2D prefix sums as a subroutine
- `[[5.062]]` → `[[5.061]]` — interval DP is a specialized 2D DP on sub-intervals; the 2D DP note is a prerequisite
- `[[5.062]]` → `[[5.002 — Recursion]]` — interval DP is often clearest top-down; the recursion note underpins this
- `[[5.063]]` → `[[5.023 — Binary Tree Traversals]]` — DP on trees uses post-order DFS; the traversal note is a prerequisite
- `[[5.063]]` → `[[5.041 — Dijkstra's]]` — shortest path with at most K stops is a DP on a graph; Dijkstra's is the baseline to compare against

---

## Generation Order by Priority

### Tier 1 — Critical (19 topics) — Generate First

|#|ID|Topic|
|---|---|---|
|1|5.001|Big-O Notation and Complexity Analysis|
|2|5.002|Recursion and the Call Stack|
|3|5.004|Arrays — Fixed, Dynamic, and In-Place Operations|
|4|5.005|Two Pointers|
|5|5.006|Sliding Window|
|6|5.015|Stack — LIFO Applications and Balanced Parentheses|
|7|5.019|Hash Maps and Hash Sets — Design and Collision Handling|
|8|5.020|Two-Sum Pattern and Generalizations|
|9|5.023|Binary Tree Traversals — Pre, In, Post, Level-Order|
|10|5.024|Binary Search Tree — Operations and Validation|
|11|5.031|Min-Heap and Max-Heap — Structure and Heapify|
|12|5.037|BFS — Shortest Path, Level-Order, Multi-Source|
|13|5.038|DFS — Cycle Detection, Connected Components, Islands|
|14|5.039|Topological Sort — Kahn's and DFS-Based|
|15|5.040|Union-Find (Disjoint Set Union)|
|16|5.041|Dijkstra's Algorithm|
|17|5.046|Binary Search — Classic Implementation and Off-by-One Discipline|
|18|5.049|Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort|
|19|5.055|Backtracking Template — Choose, Explore, Unchoose|
|20|5.059|DP Fundamentals — Recognizing Problems, Memoization vs Tabulation|
|21|5.060|1D Dynamic Programming|

### Tier 2 — High (24 topics) — Generate Second

|#|ID|Topic|
|---|---|---|
|1|5.003|Problem-Solving Framework|
|2|5.007|Prefix Sums|
|3|5.008|Kadane's Algorithm — Maximum Subarray|
|4|5.009|String Manipulation and Pattern Problems|
|5|5.011|Fast and Slow Pointers — Floyd's Cycle Detection|
|6|5.012|Linked List Reversal|
|7|5.017|Monotonic Stack Pattern|
|8|5.021|Frequency Counting and Grouping|
|9|5.022|Sliding Window with Hash Map|
|10|5.026|Tries — Prefix Trees|
|11|5.027|Lowest Common Ancestor|
|12|5.028|Binary Tree — Diameter, Serialize/Deserialize, Path Problems|
|13|5.033|Top-K and K-th Element Problems|
|14|5.034|Merge K Sorted Lists|
|15|5.035|Median of a Data Stream — Two Heaps|
|16|5.036|Graph Representation — Adjacency List and Matrix|
|17|5.047|Binary Search on the Answer|
|18|5.048|Binary Search Variants — Rotated Array, 2D Matrix, Peak Element|
|19|5.052|Greedy Choice Property and Optimal Substructure|
|20|5.053|Interval Scheduling — Activity Selection and Merging Overlapping Intervals|
|21|5.054|Common Greedy Patterns — Jump Game, Gas Station, Task Scheduler|
|22|5.056|Permutations and Combinations|
|23|5.057|Subsets and Power Set|
|24|5.058|Grid and Board Problems — N-Queens, Sudoku, Word Search|
|25|5.061|2D Dynamic Programming|

### Tier 3 — Medium (15 topics) — Generate Third

|#|ID|Topic|
|---|---|---|
|1|5.010|Singly and Doubly Linked Lists|
|2|5.013|Merge Two Sorted Lists|
|3|5.014|Find Middle Node and Remove Nth from End|
|4|5.016|Queue — FIFO and BFS Applications|
|5|5.018|Deque — Double-Ended Queue and Sliding Window Maximum|
|6|5.025|Balanced BSTs — AVL and Red-Black (Conceptual)|
|7|5.029|Segment Trees|
|8|5.032|PriorityQueue in .NET — Correct Usage and Patterns|
|9|5.042|Bellman-Ford Algorithm|
|10|5.044|Minimum Spanning Tree — Kruskal's and Prim's|
|11|5.045|Strongly Connected Components — Tarjan's and Kosaraju's|
|12|5.050|Non-Comparison Sorting — Counting, Radix, Bucket Sort|
|13|5.051|Sorting in .NET — Array.Sort, List.Sort, Custom Comparers, Stability|
|14|5.062|Interval DP — Burst Balloons, Palindromic Substrings, Matrix Chain|
|15|5.063|DP on Trees and Graphs|

### Tier 4 — Reference (3 topics) — Generate Last

|#|ID|Topic|
|---|---|---|
|1|5.030|Binary Indexed Tree (Fenwick Tree)|
|2|5.043|Floyd-Warshall — All-Pairs Shortest Path|

---

## Full Topic Index (Alphabetical)

|ID|Topic|Group|Priority|
|---|---|---|---|
|5.004|Arrays — Fixed, Dynamic, and In-Place Operations|Arrays and Strings|1|
|5.046|Binary Search — Classic Implementation and Off-by-One Discipline|Binary Search|1|
|5.047|Binary Search on the Answer|Binary Search|2|
|5.048|Binary Search Variants — Rotated Array, 2D Matrix, Peak Element|Binary Search|2|
|5.030|Binary Indexed Tree (Fenwick Tree)|Trees|4|
|5.023|Binary Tree Traversals — Pre, In, Post, Level-Order|Trees|1|
|5.024|Binary Search Tree — Operations and Validation|Trees|1|
|5.028|Binary Tree — Diameter, Serialize/Deserialize, Path Problems|Trees|2|
|5.049|Comparison-Based Sorting — Merge Sort, Quick Sort, Heap Sort|Sorting|1|
|5.054|Common Greedy Patterns — Jump Game, Gas Station, Task Scheduler|Greedy Algorithms|2|
|5.018|Deque — Double-Ended Queue and Sliding Window Maximum|Stacks and Queues|3|
|5.038|DFS — Cycle Detection, Connected Components, Islands|Graphs|1|
|5.061|2D Dynamic Programming|Dynamic Programming|2|
|5.059|DP Fundamentals — Recognizing Problems, Memoization vs Tabulation|Dynamic Programming|1|
|5.063|DP on Trees and Graphs|Dynamic Programming|3|
|5.011|Fast and Slow Pointers — Floyd's Cycle Detection|Linked Lists|2|
|5.043|Floyd-Warshall — All-Pairs Shortest Path|Graphs|4|
|5.036|Graph Representation — Adjacency List and Matrix|Graphs|2|
|5.052|Greedy Choice Property and Optimal Substructure|Greedy Algorithms|2|
|5.019|Hash Maps and Hash Sets — Design and Collision Handling|Hash Maps and Sets|1|
|5.062|Interval DP — Burst Balloons, Palindromic Substrings, Matrix Chain|Dynamic Programming|3|
|5.053|Interval Scheduling — Activity Selection and Merging Overlapping Intervals|Greedy Algorithms|2|
|5.008|Kadane's Algorithm — Maximum Subarray|Arrays and Strings|2|
|5.012|Linked List Reversal|Linked Lists|2|
|5.027|Lowest Common Ancestor|Trees|2|
|5.034|Merge K Sorted Lists|Heaps and Priority Queues|2|
|5.013|Merge Two Sorted Lists|Linked Lists|3|
|5.035|Median of a Data Stream — Two Heaps|Heaps and Priority Queues|2|
|5.031|Min-Heap and Max-Heap — Structure and Heapify|Heaps and Priority Queues|1|
|5.044|Minimum Spanning Tree — Kruskal's and Prim's|Graphs|3|
|5.017|Monotonic Stack Pattern|Stacks and Queues|2|
|5.050|Non-Comparison Sorting — Counting, Radix, Bucket Sort|Sorting|3|
|5.056|Permutations and Combinations|Backtracking|2|
|5.007|Prefix Sums|Arrays and Strings|2|
|5.003|Problem-Solving Framework|Foundations|2|
|5.032|PriorityQueue in .NET — Correct Usage and Patterns|Heaps and Priority Queues|3|
|5.016|Queue — FIFO and BFS Applications|Stacks and Queues|2|
|5.002|Recursion and the Call Stack|Foundations|1|
|5.029|Segment Trees|Trees|3|
|5.010|Singly and Doubly Linked Lists|Linked Lists|3|
|5.006|Sliding Window|Arrays and Strings|1|
|5.022|Sliding Window with Hash Map|Hash Maps and Sets|2|
|5.051|Sorting in .NET — Array.Sort, List.Sort, Custom Comparers, Stability|Sorting|3|
|5.015|Stack — LIFO Applications and Balanced Parentheses|Stacks and Queues|1|
|5.009|String Manipulation and Pattern Problems|Arrays and Strings|2|
|5.045|Strongly Connected Components — Tarjan's and Kosaraju's|Graphs|3|
|5.057|Subsets and Power Set|Backtracking|2|
|5.039|Topological Sort — Kahn's and DFS-Based|Graphs|1|
|5.033|Top-K and K-th Element Problems|Heaps and Priority Queues|2|
|5.005|Two Pointers|Arrays and Strings|1|
|5.020|Two-Sum Pattern and Generalizations|Hash Maps and Sets|1|
|5.026|Tries — Prefix Trees|Trees|2|
|5.037|BFS — Shortest Path, Level-Order, Multi-Source|Graphs|1|
|5.001|Big-O Notation and Complexity Analysis|Foundations|1|
|5.025|Balanced BSTs — AVL and Red-Black (Conceptual)|Trees|3|
|5.055|Backtracking Template — Choose, Explore, Unchoose|Backtracking|1|
|5.042|Bellman-Ford Algorithm|Graphs|3|
|5.041|Dijkstra's Algorithm|Graphs|1|
|5.014|Find Middle Node and Remove Nth from End|Linked Lists|3|
|5.040|Union-Find (Disjoint Set Union)|Graphs|1|
|5.021|Frequency Counting and Grouping|Hash Maps and Sets|2|
|5.058|Grid and Board Problems — N-Queens, Sudoku, Word Search|Backtracking|2|
|5.060|1D Dynamic Programming|Dynamic Programming|1|

---

_Domain 5 — Data Structures & Algorithms | 63 topics | 13 groups | Last updated: June 2026_ _Tags: #engineering #knowledge-base #dsa #algorithms #data-structures #csharp #interviews_