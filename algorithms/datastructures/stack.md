# Stack

> A last-in, first-out (LIFO) data structure where elements are added and removed from the same end.

---

## Quick Reference

| | |
|---|---|
| **What it is** | LIFO container — push and pop same end |
| **Use when** | Reversed processing, nested structure, undo |
| **Avoid when** | Arbitrary access or FIFO ordering needed |
| **C# version** | C# 2.0 (`Stack<T>`) |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Stack<T>` |

---

## When To Use It

Use a stack when the order of processing is the reverse of the order of arrival — undo systems, expression parsing, call stacks, DFS traversal, bracket matching. It's also the right mental model any time you find yourself thinking "I need to come back to this later, after I've handled what's inside." Whenever you see a problem involving nested structure — parentheses, HTML tags, recursive depth — a stack is almost always the tool.

Avoid it when you need access to arbitrary elements (a stack only exposes the top), when you need FIFO ordering (use a queue), or when you need to query the minimum or maximum efficiently (use a heap). A plain `List<T>` can simulate a stack with `Add` and `RemoveAt(Count - 1)`, but `Stack<T>` communicates intent more clearly and has a dedicated `Peek` method.

---

## Core Concept

A stack has two core operations: **push** (add to top) and **pop** (remove from top). Both are O(1). The LIFO property isn't a limitation — it's a deliberate design that mirrors how nested work actually gets done.

The clearest analogy is the call stack itself: when function A calls B, B's frame goes on top. B must complete and return before A can continue. The deepest call is always the first to finish. That's LIFO. When you see a problem where the most recently opened thing must be the first closed (parentheses, XML tags, undo operations, directory traversal), you're seeing the call-stack pattern in disguise — and a stack data structure is the direct implementation.

The other non-obvious use is the **monotonic stack**: a stack that maintains elements in a consistent increasing or decreasing order by popping elements that violate the invariant as new ones arrive. This turns a whole class of "next greater/smaller element" problems from O(n²) naive to O(n) — because each element is pushed and popped at most once across the entire run.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Non-generic `Stack` in `System.Collections` — stores `object`, requires casting |
| C# 2.0 | .NET 2.0 | Generic `Stack<T>` introduced — type-safe, no boxing for value types |
| C# 5.0 | .NET 4.5 | No structural change; LINQ methods (`stack.Any()`, `stack.Count()`) work via `IEnumerable<T>` |
| C# 10.0 | .NET 6 | `Stack<T>` gains `TryPeek` and `TryPop` — safe non-throwing alternatives |

*Before `Stack<T>`, developers used the non-generic `Stack` which stored `object` and required casting on every pop. Boxing value types in that era was a real performance concern.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Push | O(1) amortised | Backed by an internal array; occasional O(n) resize |
| Pop | O(1) | Decrements internal pointer — no deallocation |
| Peek | O(1) | Reads top without removing |
| Contains | O(n) | Linear scan — no index structure |
| Iterate | O(n) | `foreach` visits top-to-bottom (LIFO order) |

**Allocation behaviour:** `Stack<T>` is backed by a resizing array, identical in strategy to `List<T>`. The initial capacity is 4; each resize doubles it. For value types (`int`, `struct`), elements are stored inline with no boxing. For reference types, the array stores managed references.

**Benchmark notes:** Under normal usage, push and pop are as fast as array index writes. The practical threshold where stack overhead becomes measurable is well above 100,000 operations. For extreme throughput on a hot path (e.g. a recursive descent parser processing millions of tokens), consider a `T[]` with a manual index counter to avoid `Stack<T>`'s bounds checks — but profile first.

---

## The Code

**Basic push, peek, pop**
```csharp
var stack = new Stack<int>();
stack.Push(1);
stack.Push(2);
stack.Push(3);

int top = stack.Peek();    // 3 — look without removing, O(1)
int val = stack.Pop();     // 3 — remove top, O(1)
Console.WriteLine(stack.Count); // 2

// Safe versions (C# 10 / .NET 6+)
if (stack.TryPop(out int result))
    Console.WriteLine(result);   // 2 — no exception on empty stack
```

**Bracket matching — the canonical stack application**
```csharp
public static bool IsValidBrackets(string s)
{
    var stack = new Stack<char>();
    var pairs = new Dictionary<char, char>
    {
        { ')', '(' }, { ']', '[' }, { '}', '{' }
    };

    foreach (char ch in s)
    {
        if (ch == '(' || ch == '[' || ch == '{')
        {
            stack.Push(ch);
        }
        else if (pairs.TryGetValue(ch, out char expected))
        {
            if (stack.Count == 0 || stack.Peek() != expected)
                return false;
            stack.Pop();
        }
    }
    return stack.Count == 0;   // unmatched opens remaining = invalid
}
// IsValidBrackets("({[]})") → true
// IsValidBrackets("({[})") → false
```

**Monotonic stack — next greater element in O(n)**
```csharp
// For each element, find the next element to its right that is greater.
// Returns -1 if no such element exists.
public static int[] NextGreaterElement(int[] nums)
{
    var result = new int[nums.Length];
    Array.Fill(result, -1);
    var stack = new Stack<int>();   // stores indices, not values

    for (int i = 0; i < nums.Length; i++)
    {
        // Pop everything the current element is greater than
        while (stack.Count > 0 && nums[stack.Peek()] < nums[i])
            result[stack.Pop()] = nums[i];
        stack.Push(i);
    }
    return result;
}
// NextGreaterElement([2,1,2,4,3]) → [4,2,4,-1,-1]
```

**What NOT to do — and the fix**
```csharp
// BAD: popping an empty stack throws InvalidOperationException
public static int UnsafePop(Stack<int> stack)
{
    return stack.Pop();   // throws if empty — no guard
}

// GOOD: always guard before popping, or use TryPop
public static bool SafePop(Stack<int> stack, out int value)
{
    return stack.TryPop(out value);   // returns false instead of throwing
}

// ALSO GOOD: explicit check when you need the value inline
if (stack.Count > 0)
{
    int v = stack.Pop();
    // use v
}
```

---

## Real World Example

A code editor needs to implement "go to matching bracket" — when the cursor is on a `{`, jump to the corresponding `}`, navigating correctly through nested structures. A straightforward stack processes the file character by character: opening brackets push their index; closing brackets pop the most recently pushed opener, recording the pair. After one pass, every bracket pair is mapped.

```csharp
public class BracketMatcher
{
    // Returns a dictionary mapping each opening bracket index
    // to its corresponding closing bracket index.
    public static Dictionary<int, int> FindMatchingPairs(string source)
    {
        var pairs  = new Dictionary<int, int>();
        var stack  = new Stack<int>();   // indices of unmatched opens
        var openers = new HashSet<char> { '(', '[', '{' };
        var closers = new Dictionary<char, char>
        {
            { ')', '(' }, { ']', '[' }, { '}', '{' }
        };

        for (int i = 0; i < source.Length; i++)
        {
            char ch = source[i];

            if (openers.Contains(ch))
            {
                stack.Push(i);
            }
            else if (closers.TryGetValue(ch, out char expectedOpener))
            {
                if (stack.Count == 0)
                    throw new FormatException($"Unmatched closing bracket at index {i}.");

                int openIdx = stack.Pop();
                if (source[openIdx] != expectedOpener)
                    throw new FormatException(
                        $"Mismatched brackets: '{source[openIdx]}' at {openIdx} closed by '{ch}' at {i}.");

                pairs[openIdx] = i;
                pairs[i] = openIdx;    // bidirectional — jump either way
            }
        }

        if (stack.Count > 0)
            throw new FormatException($"Unmatched opening bracket at index {stack.Peek()}.");

        return pairs;
    }
}

// Usage
string code = "function f(a, b) { return (a + b) * [1, 2][0]; }";
var matchMap = BracketMatcher.FindMatchingPairs(code);
// matchMap[10] → index of ')' that closes the '(' at 10
// matchMap[18] → index of '}' that closes the '{' at 18
```

*The key insight is that the stack gives us the "most recently unmatched opener" for free — LIFO naturally tracks nesting depth, which is exactly what bracket matching requires.*

---

## Common Misconceptions

**"A stack is just a list with restricted access — nothing special"**
The restriction is the point. By only exposing the top, you enforce a contract that makes certain algorithms correct by construction. The monotonic stack pattern, for instance, relies on the fact that nothing can sneak in between the top and the element below it. A list with arbitrary access would break that invariant. Restricted access is a feature, not a limitation.

**"DFS requires recursion — I need the call stack"**
Recursive DFS uses the implicit call stack, but you can always replace it with an explicit `Stack<T>`. The two are equivalent. An explicit stack is preferable when input depth could cause a stack overflow (the CLR default stack is ~1 MB — around 10,000–15,000 frames for typical methods), or when you need to pause and resume traversal.

```csharp
// Recursive DFS — uses call stack implicitly
void DfsRecursive(int node, HashSet<int> visited, Dictionary<int, List<int>> graph)
{
    visited.Add(node);
    foreach (int neighbour in graph[node])
        if (!visited.Contains(neighbour))
            DfsRecursive(neighbour, visited, graph);
}

// Iterative DFS — explicit Stack<T>, same traversal order
void DfsIterative(int start, HashSet<int> visited, Dictionary<int, List<int>> graph)
{
    var stack = new Stack<int>();
    stack.Push(start);
    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (visited.Contains(node)) continue;
        visited.Add(node);
        foreach (int neighbour in graph[node])
            if (!visited.Contains(neighbour))
                stack.Push(neighbour);
    }
}
```

**"Iterating a Stack<T> with foreach gives me elements in push order"**
It doesn't. `foreach` on a `Stack<T>` visits elements in LIFO order — top first. If you need push (insertion) order, convert to an array first: `stack.ToArray()` gives elements from top to bottom, so reverse it if you need oldest-first.

---

## Gotchas

- **Always guard before popping or peeking.** Both `Pop()` and `Peek()` throw `InvalidOperationException` on an empty stack. Use `stack.Count > 0` or `stack.TryPop(out var v)` / `stack.TryPeek(out var v)` (.NET 6+) to handle the empty case gracefully.

- **Monotonic stacks are underused.** A large class of "next greater/smaller element" and "largest rectangle in histogram" problems collapse from O(n²) to O(n) with a monotonic stack. Each element is pushed once and popped once — O(n) total work. Most candidates don't reach for this pattern during interviews.

- **Stack space in recursion is O(depth), not O(n) in general.** For a balanced binary tree of n nodes, depth is O(log n). For a degenerate (skewed) tree or a linked list traversed recursively, depth is O(n) — stack overflow risk. The fix is an explicit stack.

- **`Stack<T>` iteration order surprises people.** `foreach (var item in stack)` visits the top first. If your algorithm needs FIFO output from a stack, you must reverse — either with `stack.Reverse()` (LINQ, allocates) or by copying into a `Queue<T>` or `List<T>`.

- **Don't use a stack when a queue is correct.** A BFS implemented with a stack becomes DFS — the traversal order changes completely. These are the two fundamental graph traversal strategies and the data structure determines which one you get.

---

## Interview Angle

**What they're really testing:** Pattern recognition — can you see that a problem with nested or reversed structure maps to a stack? And do you know the monotonic stack pattern, which is the non-obvious extension?

**Common question forms:**
- "Valid parentheses / bracket matching"
- "Evaluate a postfix (RPN) expression"
- "Largest rectangle in histogram"
- "Daily temperatures / next warmer day" (next greater element)
- "Implement a min-stack that returns the minimum in O(1)"

**The depth signal:** A junior solves bracket matching. A senior knows the monotonic stack pattern and can apply it to "next greater element," "daily temperatures," and "largest rectangle in histogram" — and explains that the stack maintains a decreasing (or increasing) invariant, so each pop reveals the answer for the element being discarded. The min-stack problem is also a strong signal: it requires a second parallel stack tracking the running minimum, which shows the candidate can augment a base structure rather than just use it.

**Follow-up questions to expect:**
- "How would you implement a min-stack?" (Parallel stack of minimums — push the current min alongside each value)
- "Can you do DFS without recursion?" (Yes — explicit stack replaces the call stack)
- "What's the time complexity of the monotonic stack pattern?" (O(n) — each element is pushed and popped at most once)

---

## Related Topics

- [[algorithms/datastructures/monotonic-stack.md]] — The advanced application of a stack that solves next-greater/smaller problems in O(n).
- [[algorithms/datastructures/queue.md]] — The FIFO counterpart; BFS vs DFS is the queue vs stack comparison.
- [[algorithms/searching/depth-first-search.md]] — DFS is naturally stack-based; understanding this lets you convert any recursion to iteration.
- [[algorithms/datastructures/linked-list.md]] — A stack can be implemented as a linked list for O(1) push/pop with no size limit.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.stack-1

---

*Last updated: 2026-04-12*