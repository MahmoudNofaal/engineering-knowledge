---
id: "5.015"
studied_well: false
title: "Stack — LIFO Applications and Balanced Parentheses"
domain: "Data Structures & Algorithms"
domain_id: 5
group: "Stacks and Queues"
tags: [dsa, algorithms, data-structures, stack, csharp, interviews, lifo]
priority: 1
prerequisites:
  - "[[5.001 — Big-O Notation and Complexity Analysis]]"
  - "[[5.004 — Arrays, Fixed, Dynamic, and In-Place Operations]]"
related:
  - "[[5.002 — Recursion and the Call Stack]]"
  - "[[5.017 — Monotonic Stack Pattern]]"
  - "[[5.038 — DFS — Cycle Detection, Connected Components, Islands]]"
  - "[[2.XXX — Stack<T> in .NET]]"
created: 2026-06-15
---


> [!success] Mastery Check
> - [ ] **Studied Well**
> - [ ] **Can explain the concept without notes**
> - [ ] **Can answer interview questions confidently**
> - [ ] **Can implement it in a real project**


## Navigation

**Domain:** [[5 — Data Structures & Algorithms]] > **Group:** Stacks and Queues
**Previous:** [[5.006 — Sliding Window]] | **Next:** [[5.019 — Hash Maps and Hash Sets — Design and Collision Handling]]

### Prerequisites
- [[5.001 — Big-O Notation and Complexity Analysis]] — stack operations (push, pop, peek) are O(1) and their derivation depends on understanding amortized array resizing.
- [[5.004 — Arrays, Fixed, Dynamic, and In-Place Operations]] — `Stack<T>` in .NET is backed by an array; the resizing behavior determines push amortized cost.

### Where This Fits
The stack is the most constrained data structure in common use — only the top element is accessible. This constraint makes it the perfect tool for problems with a "last in, first out" ordering requirement: parsing nested structures (parentheses, HTML/XML), evaluating arithmetic expressions (postfix, Shunting Yard), implementing DFS traversal where the call stack is the implicit data structure, and maintaining a history of decisions for backtracking. In senior interviews, the stack is a baseline expectation — failing to recognize the stack in a problem like "Valid Parentheses" or "Daily Temperatures" indicates a gap in pattern recognition.

---

## Core Mental Model

A stack is a collection where elements are added and removed from the same end (the top), enforcing Last-In-First-Out (LIFO) order. The core insight is that a stack models any process where the most recent unprocessed item must be resolved before earlier items can be processed — like nested function calls, nested parentheses, or undo/redo history. The stack defers processing of older items until newer items at the same nesting level are resolved.

### Classification

Stacks implement `ICollection<T>` and `IEnumerable<T>` in .NET. `Stack<T>` is the built-in generic implementation, backed by a `T[]` array with the same doubling-resize strategy as `List<T>`. The key operations are `Push(T)`, `Pop()`, and `Peek()`.

```mermaid
graph TD
    A[Stack Operations] --> B[Push: Add to top]
    A --> C[Pop: Remove from top]
    A --> D[Peek: View top without removal]
    B --> E[O(1) amortized — array resize when full]
    C --> F[O(1) — decrement index]
    D --> F
    A --> G[Stack in .NET]
    G --> H["Stack<T> — array-backed, generic"]
    G --> I[Push: O(1) amortized]
    G --> J[Pop: O(1)]
    G --> K[Peek: O(1)]
    G --> L[Contains: O(n) — scan]

```

### Key Properties

|Property|Value|Derivation|
|---|---|---|
|Push|O(1) amortized|Append to end of array; resize O(n) when full, amortized over n pushes = O(1)|
|Pop|O(1)|Decrement top index and return element at that position|
|Peek|O(1)|Return element at top index without decrementing|
|Search / Contains|O(n)|Must scan from top to bottom — no index-based access|
|Space|O(n)|Array-backed; unused capacity is wasted space (configurable via TrimExcess)|

---

## Deep Mechanics

### How It Works

**Array-backed storage:** `Stack<T>` maintains an internal `T[]` array and an integer `_size` tracking the number of elements. The "top" of the stack is at index `_size - 1`. Push increments `_size` and writes to that position. Pop reads from `_size - 1`, decrements, and optionally nulls the slot (to avoid memory leaks for reference types).

**Array resizing:** Same doubling strategy as `List<T>`. When `_size == _array.Length`, a new array of double the capacity is allocated and elements are copied. This means a single Push can be O(n), but the amortized cost is O(1).

**LIFO invariant:** The last element pushed is always at index `_size - 1`. The first element pushed is at index 0 (bottom of stack). This ordering is the core property — it means the stack can only access the most recently added element.

### Complexity Derivation

**Time — Balanced parentheses:** For a string of length n, each character is processed once. Opening brackets are pushed (O(1)). Closing brackets trigger a pop (O(1)) and a comparison (O(1)). Total: O(n). No character is visited twice.

**Time — Evaluate postfix expression:** Each token is read once. Operands are pushed (O(1)). Operators pop two operands (O(1)), compute, and push the result (O(1)). Total: O(n).

**Space — Stack depth for nested parentheses:** In the worst case (all opening brackets), the stack grows to O(n). In the average case (mixed), the stack depth equals the current nesting depth.

### .NET Runtime Notes

- **`Stack<T>` vs `List<T>` as a stack:** `List<T>` can be used as a stack by treating the end as the top (Add = Push, RemoveAt(Count-1) = Pop). `Stack<T>` is preferred because it communicates intent and has a cleaner API. Performance is equivalent since both are array-backed.
- **`Stack<T>.TrimExcess()`:** After many pushes and pops, the internal array may be much larger than the current count. `TrimExcess()` resizes the array to match the current count (or the default capacity), reducing memory usage at the cost of an O(n) copy.
- **Stack overflow:** The call stack is a stack (not `Stack<T>`). Explicit `Stack<T>` instances are heap-allocated and do not cause stack overflow — only the implicit call stack does. This means you can safely push millions of items onto a `Stack<T>` as long as you have sufficient heap memory.

---

## Implementation and Problem Patterns

### C# Implementation

```csharp
/// <summary>
/// Scratch implementation of a stack using a dynamic array.
/// </summary>
public class SimpleStack<T>
{
    private T[] _items;
    private int _count;

    public SimpleStack(int capacity = 4)
    {
        _items = new T[capacity];
    }

    public int Count => _count;

    public void Push(T item)
    {
        if (_count == _items.Length)
            Array.Resize(ref _items, _items.Length * 2);
        _items[_count++] = item;
    }

    public T Pop()
    {
        if (_count == 0) throw new InvalidOperationException("Stack is empty");
        T item = _items[--_count];
        _items[_count] = default!;
        return item;
    }

    public T Peek()
    {
        if (_count == 0) throw new InvalidOperationException("Stack is empty");
        return _items[_count - 1];
    }

    public bool IsEmpty => _count == 0;
}

public static class StackProblems
{
    /// <summary>
    /// Valid Parentheses: check if string has balanced brackets.
    /// </summary>
    public static bool IsValid(string s)
    {
        var stack = new Stack<char>();
        var map = new Dictionary<char, char>
        {
            { ')', '(' },
            { ']', '[' },
            { '}', '{' }
        };

        foreach (char c in s)
        {
            if (!map.ContainsKey(c))
            {
                stack.Push(c);
            }
            else
            {
                if (stack.Count == 0 || stack.Pop() != map[c])
                    return false;
            }
        }
        return stack.Count == 0;
    }

    /// <summary>
    /// Evaluate Reverse Polish Notation (postfix expression).
    /// Operators: +, -, *, /
    /// </summary>
    public static int EvalRPN(string[] tokens)
    {
        var stack = new Stack<int>();
        foreach (string token in tokens)
        {
            if (int.TryParse(token, out int num))
            {
                stack.Push(num);
            }
            else
            {
                int b = stack.Pop();
                int a = stack.Pop();
                stack.Push(token switch
                {
                    "+" => a + b,
                    "-" => a - b,
                    "*" => a * b,
                    "/" => a / b,
                    _ => throw new ArgumentException($"Unknown operator: {token}")
                });
            }
        }
        return stack.Pop();
    }

    /// <summary>
    /// Simplify absolute path (Unix-like).
    /// ".." pops the stack; "." and "" are ignored.
    /// </summary>
    public static string SimplifyPath(string path)
    {
        var stack = new Stack<string>();
        foreach (string segment in path.Split('/', StringSplitOptions.RemoveEmptyEntries))
        {
            if (segment == "..")
            {
                if (stack.Count > 0) stack.Pop();
            }
            else if (segment != ".")
            {
                stack.Push(segment);
            }
        }
        return "/" + string.Join("/", stack.Reverse());
    }

    /// <summary>
    /// Daily Temperatures: for each day, days until a warmer temperature.
    /// Monotonic decreasing stack stores indices.
    /// </summary>
    public static int[] DailyTemperatures(int[] temperatures)
    {
        int n = temperatures.Length;
        int[] result = new int[n];
        var stack = new Stack<int>(); // stores indices

        for (int i = 0; i < n; i++)
        {
            while (stack.Count > 0 && temperatures[i] > temperatures[stack.Peek()])
            {
                int prevIndex = stack.Pop();
                result[prevIndex] = i - prevIndex;
            }
            stack.Push(i);
        }
        // Remaining indices in stack never see a warmer day — result stays 0
        return result;
    }

    /// <summary>
    /// Asteroid Collision: simulate collisions between asteroids travelling left/right.
    /// </summary>
    public static int[] AsteroidCollision(int[] asteroids)
    {
        var stack = new Stack<int>();
        foreach (int ast in asteroids)
        {
            bool destroyed = false;
            while (stack.Count > 0 && ast < 0 && stack.Peek() > 0)
            {
                if (stack.Peek() < -ast)
                {
                    stack.Pop();
                    continue;
                }
                else if (stack.Peek() == -ast)
                {
                    stack.Pop();
                }
                destroyed = true;
                break;
            }
            if (!destroyed) stack.Push(ast);
        }
        return stack.ToArray().Reverse().ToArray();
    }
}
```

### The .NET Idiomatic Version

```csharp
public static class StackIdiomatic
{
    // Use Stack<T> directly — the .NET implementation is production-optimized.
    // For thread-safe stacks, use ConcurrentStack<T> from System.Collections.Concurrent.

    // For "Valid Parentheses", no LINQ alternative — the stack is the natural fit.

    // For Reverse Polish Notation, a stack is the only correct approach.

    // For evaluating infix expressions, use the Shunting Yard algorithm:
    // Two stacks: one for operators, one for operands (or output queue).

    // If you need to peek at multiple elements (e.g., peek second from top),
    // convert to array or use List<T> as a stack (treat end as top):
    public static T PeekSecond<T>(Stack<T> stack)
    {
        T top = stack.Pop();
        T second = stack.Peek();
        stack.Push(top);
        return second;
    }
}
```

### Classic Problem Patterns

1. **Balanced parentheses** — Check if brackets are properly nested and closed. Key insight: opening brackets go on the stack; each closing bracket must match the most recent opening bracket (top of stack).
2. **Expression evaluation (Postfix/RPN)** — Evaluate arithmetic in postfix notation. Key insight: operands go on the stack; each operator pops the correct number of operands and pushes the result.
3. **Monotonic stack (Next Greater Element, Daily Temperatures)** — Find the next element satisfying a comparison in a single pass. Key insight: the stack maintains a monotonic sequence; when a new element breaks the monotonicity, it resolves entries on the stack.

### Template / Skeleton

```csharp
// Stack Processing Template
// When to use: sequential data where elements must be matched to a previous element
// Time: O(n) | Space: O(n) worst-case stack depth

public static int StackTemplate(string input)
{
    var stack = new Stack<char>(); // or Stack<int>, depending on element type

    foreach (char c in input)
    {
        // TODO: handle opening elements — push onto stack
        if (/* is opening element */)
        {
            stack.Push(c);
        }
        else
        {
            // TODO: handle closing element — check stack state
            if (stack.Count == 0) return -1; // or throw

            char top = stack.Pop();
            // TODO: validate that top matches closing element
            if (/* mismatch */) return -1;
        }
    }

    // At end, stack should be empty if all elements were matched
    return stack.Count == 0 ? 0 : -1;
}
```

---

## Gotchas and Edge Cases

### Forgetting to Check Stack is Non-Empty on Pop

**Mistake:** Calling `stack.Pop()` without checking if the stack has elements.

```csharp
// ❌ Wrong — crashes on unbalanced input with extra closing bracket
foreach (char c in s)
{
    if (c == '(') stack.Push(c);
    else if (c == ')') stack.Pop(); // InvalidOperationException if empty
}
```

**Fix:** Always check `stack.Count > 0` before Pop or Peek.

```csharp
// ✅ Correct — check before pop
else if (c == ')')
{
    if (stack.Count == 0) return false;
    stack.Pop();
}
```

**Consequence:** `InvalidOperationException` at runtime — interview failure.

### Returning True When Stack is Non-Empty

**Mistake:** Returning `true` after processing all characters without checking if the stack is empty.

```csharp
// ❌ Wrong — returns true for "(((" (all opening, never closed)
foreach (char c in s) { /* process */ }
return true; // stack still has 3 items
```

**Fix:** Return `stack.Count == 0`.

```csharp
// ✅ Correct — check that all openings were matched
return stack.Count == 0;
```

**Consequence:** Wrong answer — false positive for unbalanced input.

### Forgetting Division and Subtraction Order in RPN

**Mistake:** Popping operands in the wrong order for non-commutative operators.

```csharp
// ❌ Wrong — b should be the second operand, a the first
int b = stack.Pop();
int a = stack.Pop();
return a / b; // Correct — but many write b / a
```

**Fix:** First pop is the second operand (right side), second pop is the first (left side).

```csharp
// ✅ Correct — a is the left operand, b is the right operand
int b = stack.Pop();
int a = stack.Pop();
stack.Push(token switch { "/" => a / b, "-" => a - b, ... });
```

**Consequence:** Wrong arithmetic result. For division: 6 / 2 becomes 0 (integer division of 2 / 6).

### Integer Overflow in Expression Evaluation

**Mistake:** Using `int` for intermediate results that can overflow.

```csharp
// ❌ Wrong — overflow on large int operations
int a = stack.Pop();
int b = stack.Pop();
stack.Push(a + b); // Can overflow
```

**Fix:** Use `long` for evaluation, then check overflow or cast back.

```csharp
// ✅ Correct — use long for intermediate values
long b = stack.Pop();
long a = stack.Pop();
long result = token switch { "+" => a + b, ... };
if (result < int.MinValue || result > int.MaxValue)
    throw new OverflowException("Result out of int range");
stack.Push((int)result);
```

**Consequence:** Silent overflow yields wrong answer; uncaught in unchecked context.

---

## Complexity Analysis and Benchmarks

### Operation Complexity Table

|Operation|Time (Best)|Time (Average)|Time (Worst)|Space|Notes|
|---|---|---|---|---|---|
|Push|O(1)|O(1) amortized|O(n) resize|O(n) resize|Amortized O(1) due to doubling strategy|
|Pop|O(1)|O(1)|O(1)|O(1)|Decrement index, null slot|
|Peek|O(1)|O(1)|O(1)|O(1)|Read without removal|
|Valid Parentheses|O(n)|O(n)|O(n)|O(n)|Stack grows to n in worst case (all opening)|
|RPN Evaluation|O(n)|O(n)|O(n)|O(n/2)|Stack grows to approx operands/2|

**Derivation for the non-obvious entries:** Push has worst-case O(n) when the internal array is full and doubles. The copy cost is O(n) but happens every n pushes, giving O(1) amortized. The derivation is identical to `List<T>.Add`.

### Comparison with Alternatives

|Structure / Algorithm|Push/Pop|Peek|Best When|
|---|---|---|---|
|Stack<T>|O(1) amortized|O(1)|LIFO access pattern, no random access needed|
|List<T> (as stack)|O(1) amortized|O(1)|Need occasional index access into the stack|
|LinkedList<T> (as stack)|O(1) push/pop|O(1)|Avoid array resize spikes; known node references|
|Queue<T>|Enqueue O(1)|Dequeue O(1)|FIFO access — different problem class|

### BenchmarkDotNet

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class StackBenchmark
{
    [Params(1_000, 10_000)]
    public int N { get; set; }

    private string _parentheses = null!;

    [GlobalSetup]
    public void Setup()
    {
        var sb = new System.Text.StringBuilder(N);
        for (int i = 0; i < N / 2; i++)
        {
            sb.Append('(');
            sb.Append(')');
        }
        _parentheses = sb.ToString();
    }

    [Benchmark(Baseline = true)]
    public bool ValidParenthesesStack()
    {
        var stack = new Stack<char>();
        foreach (char c in _parentheses)
        {
            if (c == '(') stack.Push(c);
            else if (stack.Count == 0) return false;
            else stack.Pop();
        }
        return stack.Count == 0;
    }

    [Benchmark]
    public bool ValidParenthesesCounter()
    {
        int count = 0;
        foreach (char c in _parentheses)
        {
            if (c == '(') count++;
            else if (count == 0) return false;
            else count--;
        }
        return count == 0;
    }
}
```

**Expected results (approximate, .NET 9, x64):**

|Method|N|Mean|Allocated|
|---|---|---|---|
|ValidParenthesesStack|1,000|~5 μs|~8 KB|
|ValidParenthesesStack|10,000|~50 μs|~80 KB|
|ValidParenthesesCounter|1,000|~1 μs|0 B|
|ValidParenthesesCounter|10,000|~10 μs|0 B|

**Interpretation:** The counter approach (for single-type parentheses) is 5× faster and allocates nothing — the stack is unnecessary overhead when there is only one bracket type. The stack is required only when there are multiple bracket types or when the context (which type of opening bracket) must be preserved.

---

## Interview Arsenal

### Question Bank

1. [Definition] What is a stack and what property does it enforce?
2. [Complexity] Derive the amortized O(1) cost of Push for Stack<T>.
3. [Implementation] Implement `Valid Parentheses` allowing (), {}, [].
4. [Recognition] Given a problem involving nested structures or undo history, would you use a stack?
5. [Comparison] Compare Stack<T>, List<T> as a stack, and LinkedList<T> as a stack.
6. [Trick] Can you solve `Valid Parentheses` without a stack? What are the tradeoffs?
7. [System Design] How would you implement an undo/redo system using two stacks?
8. [Optimization] How would you optimize a stack that frequently pushes and pops the same size elements?

### Spoken Answers

**Q: Derive the amortized O(1) cost of Push for Stack<T>.**

> **Average answer:** Stack<T> uses an array that doubles when full, so pushes are O(1) most of the time.

> **Great answer:** `Stack<T>` is backed by an internal `T[]` array with a doubling resize strategy. Starting with a default capacity of 4, the first 4 pushes are O(1). On the 5th push, the array doubles to capacity 8 — allocating a new array and copying the 4 existing elements: O(4). Then pushes 5-8 are O(1). On the 9th push, double to capacity 16 — copy 8 elements: O(8). The total copy cost across n pushes is the geometric series 4 + 8 + 16 + ... + n/2 < 2n. So the total cost across n pushes is O(n + 2n) = O(3n) = O(n), giving O(1) amortized per push. The key point: the geometric doubling ensures the copy cost is amortized. The `.NET `Stack<T>` uses the same doubling strategy as `List<T>`, though the default initial capacity may differ. For interview purposes, either the array-based or the linked-list-based implementation of a stack is acceptable, but the .NET standard library uses the array-based version for cache locality.

**Q: Can you solve Valid Parentheses without a stack? What are the tradeoffs?**

> **Average answer:** No, you need a stack because you need to match the most recent opening bracket.

> **Great answer:** It depends on the number of bracket types. For a single bracket type (only parentheses), a simple counter works — increment on '(', decrement on ')', fail if count goes negative, ensure count is zero at the end. This is O(n) time, O(1) space. For multiple bracket types, a counter cannot distinguish which type of bracket is being closed — you need a stack to preserve the nesting context. However, there is a clever alternative: keep a "string" that tracks the opening brackets seen so far, removing the last character on each closing bracket. This is functionally equivalent to a stack but using string immutability makes it O(n²) — avoid it. So the answer is: for single-type brackets, a counter is better (O(1) space). For multiple types, a stack is required and is optimal.

**Q: [Trick] Stack<T>.ToArray() returns the top at index 0 or the bottom at index 0?**

> **Average answer:** The top is at the end of the array.

> **Great answer:** `Stack<T>.ToArray()` returns the top at index 0. That is, `ToArray()[0]` is the result of `Peek()`. This is the opposite of the natural order — the internal array stores the bottom of the stack at index 0 and the top at `_size - 1`, but `ToArray()` reverses the order. This is documented but often forgotten, leading to subtle bugs when iterating the result. If you need the stack order (bottom first), use `stack.ToArray().Reverse()`. The trap is that candidates assume `ToArray()` preserves internal ordering, but it does not.

### Trick Question

**"You have a Stack<T> with elements [1, 2, 3] (3 is the top). After calling stack.ToArray(), what is the array?"**

Why it is a trap: Candidates often think `ToArray()` preserves the internal array layout (bottom at 0, top at end), but `Stack<T>.ToArray()` reverses it — returning [3, 2, 1] with the top at index 0.

Correct answer: `[3, 2, 1]`. The `ToArray()` method returns elements in LIFO order — top of stack first.

### Pattern Recognition Table

|If the problem has...|Then consider...|Because...|
|---|---|---|
|Nested structures (brackets, HTML)|Stack|LIFO matches nesting — innermost must close first|
|Expression evaluation|Stack (or two stacks)|Shunting Yard for infix; single stack for postfix|
|Undo/redo functionality|Two stacks|Undo pops from history stack, pushes to redo stack|
|Monotonic constraint (next greater, smaller)|Monotonic stack|Elements are resolved when a newer element breaks the monotonic sequence|
|DFS traversal (tree, graph)|Stack (explicit or implicit call stack)|LIFO matches depth-first exploration order|

---

## Decision Framework

### When to Apply

```mermaid
flowchart TD
    A[Problem involves sequential processing with deferred resolution] --> B{Does the resolution order match LIFO?}
    B -->|Yes: most recent first| C[Use Stack]
    B -->|No: oldest first| D[Use Queue]
    B -->|Maybe: depends on comparison direction| E[Use Monotonic Stack]
    C --> F{Multiple bracket types?}
    F -->|Yes| G[Need Stack to track bracket type context]
    F -->|No, single type| H[Counter may suffice for O(1) space]
    G --> I[O(n) time, O(n) space]
    H --> J[O(n) time, O(1) space]
```

### Recognition Checklist

Indicators that a Stack is the right choice:

- [ ] "Most recent" or "innermost" must be processed first
- [ ] Nested structures need validation or transformation
- [ ] Expression involves operators and operands (RPN, Shunting Yard)
- [ ] Need to reverse or undo recent operations
- [ ] DFS traversal — explicit stack to avoid call stack overflow

Counter-indicators — do NOT apply here:

- [ ] "First" or "earliest" must be processed first (use Queue)
- [ ] Random access by position is required (use List<T>)
- [ ] Need access to the "minimum" element quickly (use Min-Heap or Min-Stack design)

### Tradeoff Summary

|What You Gain|What You Give Up|
|---|---|
|O(1) push/pop/peek operations|Only the top element is accessible|
|Perfect for LIFO-ordered problems|Cannot search or insert at arbitrary positions efficiently|
|Array-backed cache locality|Array resize spikes (amortized away)|

---

## Self-Check

### Conceptual Questions

1. What is the LIFO property and what types of processes does it model?
2. Derive the amortized O(1) cost of Push for Stack<T> using the doubling argument.
3. Recognizing from a problem: "Given a string of brackets, determine if it is valid." What is the first step?
4. When would you use a counter instead of a stack for balanced parentheses?
5. What specific edge case causes Valid Parentheses to return a false positive?
6. What is the order of elements returned by `Stack<T>.ToArray()`?
7. What invariant must hold for the stack after processing a valid parentheses string?
8. How does the answer change if the parentheses problem includes wildcards ('*' that can be '(' or ')' or empty)?
9. In a production system, why might you prefer `ConcurrentStack<T>` over `Stack<T>` with locking?
10. What is the trap question about `Stack<T>.ToArray()` order?

<details>
<summary>Answers</summary>

1. LIFO (Last-In-First-Out) means the most recently added element is the first removed. It models function calls, expression evaluation, undo/redo, and nested structures.
2. Starting at capacity 4, resizes at 4, 8, 16, ..., n/2. Total copy cost: 4 + 8 + ... + n/2 < 2n. Total n pushes + < 2n copies = O(3n) = O(n). Amortized: O(1) per push.
3. Use a stack. Push opening brackets; when a closing bracket is encountered, pop and verify it matches the most recent opening bracket.
4. When there is only one bracket type (e.g., only parentheses). A counter is O(1) space and simpler.
5. Returning `true` when the stack is non-empty (some opening brackets were never closed). Always check `stack.Count == 0` at the end.
6. Top of stack at index 0 (LIFO order). So `ToArray()[0]` equals `Peek()`.
7. The stack must be empty after processing all characters, and no Pop should occur on an empty stack.
8. Wildcard problems (e.g., "Valid Parenthesis String" with '*') require two counters (low and high range of possible open counts) or two stacks (one for '(' positions, one for '*' positions).
9. `ConcurrentStack<T>` uses lock-free operations (CAS) and avoids the contention and complexity of manual locking around every Push/Pop.
10. The trap is assuming `ToArray()` preserves the internal array order (bottom at 0). It actually reverses to LIFO order (top at 0).

</details>

---

### Coding Challenges

**Challenge 1 — Implement from scratch**

Implement a stack using a singly linked list instead of an array.

```csharp
public class LinkedStack<T>
{
    private class Node
    {
        public T Value;
        public Node? Next;
        public Node(T value) { Value = value; }
    }

    private Node? _top;

    public void Push(T item)
    {
        // Your implementation here
    }

    public T Pop()
    {
        // Your implementation here
    }

    public T Peek()
    {
        // Your implementation here
    }

    public bool IsEmpty => _top == null;
}
```

<details> <summary>Solution</summary>

```csharp
public class LinkedStack<T>
{
    private class Node
    {
        public T Value;
        public Node? Next;
        public Node(T value) { Value = value; }
    }

    private Node? _top;

    public void Push(T item)
    {
        var node = new Node(item) { Next = _top };
        _top = node;
    }

    public T Pop()
    {
        if (_top == null) throw new InvalidOperationException("Stack is empty");
        T value = _top.Value;
        _top = _top.Next;
        return value;
    }

    public T Peek()
    {
        if (_top == null) throw new InvalidOperationException("Stack is empty");
        return _top.Value;
    }

    public bool IsEmpty => _top == null;
}
```

**Complexity:** Time O(1) for all operations | Space O(n) nodes **Key insight:** Each node stores a value and a reference to the next node down. No array resizing means each push is truly O(1), not amortized — at the cost of per-node allocation and pointer indirection.

</details>

---

**Challenge 2 — Trace the execution**

Given expression `"2 1 + 3 *"` in RPN, trace the evaluation.

<details> <summary>Solution</summary>

Initial stack: []

Step 1: token="2" → push 2 → stack=[2]
Step 2: token="1" → push 1 → stack=[2, 1]
Step 3: token="+" → pop 1, pop 2, compute 2+1=3, push 3 → stack=[3]
Step 4: token="3" → push 3 → stack=[3, 3]
Step 5: token="*" → pop 3, pop 3, compute 3*3=9, push 9 → stack=[9]
Final: pop 9 = result

**Why:** The stack correctly resolves binary operators: second pop is the left operand, first pop is the right operand.

</details>

---

**Challenge 3 — Fix the bug**

```csharp
// This implementation has a bug that fails on specific input types
public static bool IsValid(string s)
{
    var stack = new Stack<char>();
    foreach (char c in s)
    {
        if (c == '(' || c == '[' || c == '{')
            stack.Push(c);
        else if (c == ')' && stack.Peek() == '(')  // BUG
            stack.Pop();
        else if (c == ']' && stack.Peek() == '[')
            stack.Pop();
        else if (c == '}' && stack.Peek() == '{')
            stack.Pop();
        else
            return false;
    }
    return true;
}
```

<details> <summary>Solution</summary>

**Bug:** `stack.Peek()` throws `InvalidOperationException` when the stack is empty. The code also does not check `stack.Count` before Peek. Additionally, the first `else if` checks matching bracket but does not handle the case where Peek succeeds but does not match — the `else` branch catches all non-matching cases but only after attempting Peek on a possibly empty stack.

**Fix:**

```csharp
public static bool IsValid(string s)
{
    var stack = new Stack<char>();
    var map = new Dictionary<char, char>
    {
        { ')', '(' },
        { ']', '[' },
        { '}', '{' }
    };

    foreach (char c in s)
    {
        if (!map.ContainsKey(c))
        {
            stack.Push(c);
        }
        else
        {
            if (stack.Count == 0 || stack.Pop() != map[c])
                return false;
        }
    }
    return stack.Count == 0;
}
```

**Test case that exposes it:** `s = "]"` → expected `false`, actual `InvalidOperationException`

</details>

---

**Challenge 4 — Recognize and apply**

**Problem:** Given a string containing lowercase letters and backspace characters ('#'), determine if two strings are equal after applying backspaces. For example, "ab#c" == "ac". Which pattern applies? Write the solution.

<details> <summary>Solution</summary>

**Pattern:** Stack-based string building — push letters, pop on backspace (if stack non-empty). Then compare the resulting strings.

```csharp
public static bool BackspaceCompare(string s, string t)
{
    return Build(s) == Build(t);

    static string Build(string str)
    {
        var stack = new Stack<char>();
        foreach (char c in str)
        {
            if (c == '#')
            {
                if (stack.Count > 0) stack.Pop();
            }
            else
            {
                stack.Push(c);
            }
        }
        return new string(stack.Reverse().ToArray());
    }
}
```

**Complexity:** Time O(n + m) | Space O(n + m)

</details>

---

**Challenge 5 — Optimize**

```csharp
// This solution is correct but uses O(n) space
// Optimize it to O(1) space (excluding the stack itself)
public static string RemoveDuplicates(string s)
{
    // Remove adjacent duplicates repeatedly: "abbaca" → "ca"
    var stack = new Stack<char>();
    foreach (char c in s)
    {
        if (stack.Count > 0 && stack.Peek() == c)
            stack.Pop();
        else
            stack.Push(c);
    }
    return new string(stack.Reverse().ToArray());
}
```

<details> <summary>Solution</summary>

**Insight:** Use a StringBuilder as a mutable stack to avoid the reversal and ToArray allocation.

```csharp
public static string RemoveDuplicates(string s)
{
    var sb = new System.Text.StringBuilder();
    foreach (char c in s)
    {
        if (sb.Length > 0 && sb[^1] == c)
            sb.Length--;
        else
            sb.Append(c);
    }
    return sb.ToString();
}
```

**Complexity:** Time O(n) | Space O(n) for result **Key insight:** The StringBuilder's `Length--` acts as a stack pop; `Append` acts as push. This eliminates the separate stack and the final reversal.

</details>
