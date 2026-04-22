# Stack

> A LIFO (Last-In-First-Out) data structure that supports O(1) push, pop, and peek — the foundation of DFS, expression parsing, and undo systems.

---

## Quick Reference

| | |
|---|---|
| **What it is** | LIFO collection — last pushed is first popped |
| **Use when** | DFS, expression evaluation, undo/redo, matching brackets, monotonic stack |
| **Avoid when** | FIFO ordering needed (use Queue); random access needed (use List) |
| **C# version** | `Stack<T>` since C# 2.0 |
| **Namespace** | `System.Collections.Generic` |
| **Key types** | `Stack<T>` |

---

## When To Use It

Use a stack when you need to process elements in reverse order of arrival, or when you need to "undo" a sequence of operations. DFS on graphs and trees uses the call stack implicitly — converting to iterative DFS means using an explicit `Stack<T>`. Expression parsing (valid parentheses, evaluate RPN), monotonic stack problems (next greater element), and backtracking all rely on LIFO semantics. Don't use a stack when order of arrival (FIFO) is what you need — that's a queue.

---

## Core Concept

A stack restricts access to one end. Push adds to the top; pop removes from the top; peek reads the top without removing it. All three operations are O(1). The LIFO property means the most recently pushed item is always the first to be retrieved — exactly the semantics of a function call stack, which is why DFS maps naturally onto a stack.

C#'s `Stack<T>` is backed by a dynamic array (not a linked list), so iteration is cache-friendly. `Push` is O(1) amortised (occasional resize), `Pop` and `Peek` are O(1) always.

---

## Algorithm History

| Year | Development |
|---|---|
| 1946 | Alan Turing describes the concept of a "bury" / "unbury" mechanism (hardware stack) |
| 1955 | Klaus Samelson and Friedrich Bauer patent the stack principle for expression evaluation |
| 1960 | Algol 60 uses call stacks for procedure calls — stacks enter mainstream programming |
| 2005 | C# 2.0 introduces generic `Stack<T>` |

---

## Performance

| Operation | Time | Notes |
|---|---|---|
| Push | O(1) amortised | O(n) on backing array resize |
| Pop | O(1) | Throws `InvalidOperationException` if empty |
| Peek | O(1) | |
| Count | O(1) | |
| Contains | O(n) | Linear scan — avoid in hot paths |
| Iteration | O(n) | Top-to-bottom order |

**Allocation behaviour:** Backed by a `T[]`. Grows by doubling, same as `List<T>`. Pre-size with `new Stack<T>(expectedCapacity)` to avoid resizes.

---

## The Code

**Scenario 1 — valid parentheses**
```csharp
public bool IsValid(string s)
{
    var stack = new Stack<char>();
    foreach (char c in s)
    {
        if (c is '(' or '[' or '{')
        {
            stack.Push(c);
        }
        else
        {
            if (stack.Count == 0) return false;
            char top = stack.Pop();
            if (c == ')' && top != '(') return false;
            if (c == ']' && top != '[') return false;
            if (c == '}' && top != '{') return false;
        }
    }
    return stack.Count == 0;
}
```

**Scenario 2 — iterative DFS using explicit stack**
```csharp
public List<int> DfsIterative(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var stack   = new Stack<int>();
    var order   = new List<int>();
    stack.Push(start);

    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (!visited.Add(node)) continue; // Add returns false if already present
        order.Add(node);
        // Push neighbours in reverse order to match recursive DFS traversal order
        var neighbours = graph[node];
        for (int i = neighbours.Count - 1; i >= 0; i--)
            if (!visited.Contains(neighbours[i]))
                stack.Push(neighbours[i]);
    }
    return order;
}
```

**Scenario 3 — min stack (O(1) getMin)**
```csharp
public class MinStack
{
    private readonly Stack<int> _stack = new();
    private readonly Stack<int> _minStack = new(); // tracks current min at each level

    public void Push(int val)
    {
        _stack.Push(val);
        int currentMin = _minStack.Count == 0 ? val : Math.Min(val, _minStack.Peek());
        _minStack.Push(currentMin);
    }

    public void Pop()       { _stack.Pop(); _minStack.Pop(); }
    public int Top()        => _stack.Peek();
    public int GetMin()     => _minStack.Peek(); // O(1)
}
```

**Scenario 4 — what NOT to do: using List as a stack**
```csharp
// BAD: List.RemoveAt(Count-1) works but is semantically wrong and O(1) only by accident
var stackBad = new List<int>();
stackBad.Add(1); stackBad.Add(2); stackBad.Add(3);
int top = stackBad[^1];
stackBad.RemoveAt(stackBad.Count - 1); // "pop" — unintuitive and fragile

// GOOD: Stack<T> makes intent explicit and is optimised for this access pattern
var stack = new Stack<int>();
stack.Push(1); stack.Push(2); stack.Push(3);
int topGood = stack.Pop(); // clear, correct, O(1)
```

---

## Real World Example

The `UndoRedoService` in a document editor maintains two stacks — one for undo history, one for redo history. Each user action pushes a command onto the undo stack. Pressing Ctrl+Z pops from undo and pushes onto redo. Pressing Ctrl+Y does the reverse.

```csharp
public class UndoRedoService<T>
{
    private readonly Stack<T> _undoStack = new();
    private readonly Stack<T> _redoStack = new();

    public void Execute(T command)
    {
        _undoStack.Push(command);
        _redoStack.Clear(); // any new action clears the redo history
    }

    public T? Undo()
    {
        if (_undoStack.Count == 0) return default;
        var command = _undoStack.Pop();
        _redoStack.Push(command);
        return command;
    }

    public T? Redo()
    {
        if (_redoStack.Count == 0) return default;
        var command = _redoStack.Pop();
        _undoStack.Push(command);
        return command;
    }

    public bool CanUndo => _undoStack.Count > 0;
    public bool CanRedo => _redoStack.Count > 0;
    public int  UndoDepth => _undoStack.Count;
}
```

*The key insight: the LIFO property maps perfectly to undo/redo — the most recent action is always the first to be undone. Two stacks model the full undo/redo state machine with O(1) per operation.*

---

## Common Misconceptions

**"The call stack and Stack<T> are the same thing"**
The call stack is a hardware/OS concept — a contiguous memory region managed by the runtime. `Stack<T>` is a heap-allocated data structure backed by a dynamic array. They share LIFO semantics but are completely different in implementation. Recursive algorithms use the call stack implicitly; iterative DFS uses `Stack<T>` explicitly on the heap.

**"Stack.Peek() and Stack.Pop() throw on empty — I should check Count first"**
`TryPeek` and `TryPop` (added in .NET Core 2.0) return `false` instead of throwing. Use those in code where an empty stack is an expected state, not an error.

**"Iterating a Stack<T> goes bottom-to-top"**
No — `foreach` on a `Stack<T>` goes top-to-bottom (most recently pushed first). If you need bottom-to-top order, `stack.Reverse()` (LINQ) or convert to an array with `stack.ToArray()` (also top-to-bottom — note this too) and reverse.

---

## Gotchas

- **`stack.ToArray()` returns elements top-to-bottom**, not the order they were pushed. `stack.ToArray()[0]` is the top element, same as `stack.Peek()`.
- **Pop on empty stack throws `InvalidOperationException`**, not returns null. Always check `stack.Count > 0` or use `TryPop`.
- **Monotonic stack stores indices, not values.** For next-greater-element problems, push the index so you can compute distances. Access the value via `nums[stack.Peek()]`.
- **Iterative DFS traversal order may differ from recursive.** Push neighbours in reverse order to match recursive DFS traversal sequence.

---

## Interview Angle

**What they're really testing:** Whether you reach for a stack for DFS, expression parsing, and monotonic stack problems — and whether you can implement it iteratively.

**Common question forms:** Valid parentheses. Min stack. Evaluate reverse Polish notation. Iterative inorder traversal. Daily temperatures (monotonic stack).

**The depth signal:** A junior validates brackets with a stack. A senior implements iterative DFS with an explicit stack, explains the call-stack analogy, builds a min stack, and knows the monotonic stack pattern for next-greater-element.

---

## Related Topics

- [[algorithms/searching/depth-first-search.md]] — Iterative DFS uses an explicit Stack<T>.
- [[algorithms/patterns/monotonic-stack.md]] — A disciplined usage pattern built on Stack<T>.
- [[algorithms/datastructures/queue.md]] — The FIFO counterpart; BFS uses a queue where DFS uses a stack.

---

## Source

https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.stack-1

---

*Last updated: 2026-04-21*