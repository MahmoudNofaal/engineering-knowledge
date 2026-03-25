# Stack
> A last-in, first-out (LIFO) data structure where elements are added and removed from the same end.

---

## When To Use It
Use a stack when the order of processing is the reverse of the order of arrival — undo systems, expression parsing, call stacks, DFS traversal, bracket matching. It's also the right mental model any time you find yourself thinking "I need to come back to this later." Avoid it when you need access to arbitrary elements; a stack only exposes the top.

---

## Core Concept
A stack has two operations: push (add to top) and pop (remove from top). Both are O(1). The LIFO property is the point — the last thing you pushed is the first thing you'll get back. This mirrors how function calls work: the most recent call must return before the one that invoked it. When you see a problem involving nested structure (parentheses, HTML tags, recursive depth), a stack is almost always the tool.

---

## The Code

**Using C#'s Stack as a stack**
```csharp
var stack = new Stack<int>();
stack.Push(1);   // push — O(1) amortized
stack.Push(2);
stack.Push(3);

int top = stack.Peek();   // peek without removing — O(1)
int val = stack.Pop();    // pop — O(1) amortized
```

**Bracket matching — classic stack application**
```csharp
public static bool IsValid(string s)
{
    var stack = new Stack<char>();
    var pairs = new Dictionary<char, char> { { ')', '(' }, { ']', '[' }, { '}', '{' } };
    
    foreach (var ch in s)
    {
        if (ch == '(' || ch == '[' || ch == '{')
            stack.Push(ch);
        else if (ch == ')' || ch == ']' || ch == '}')
        {
            if (stack.Count == 0 || stack.Peek() != pairs[ch])
                return false;
            stack.Pop();
        }
    }
    return stack.Count == 0;  // unmatched opens left = invalid
}
```

**Monotonic stack — next greater element in O(n)**
```csharp
public static List<int> NextGreater(List<int> items)
{
    var result = Enumerable.Repeat(-1, items.Count).ToList();
    var stack = new Stack<int>();  // stores indices
    
    for (int i = 0; i < items.Count; i++)
    {
        // pop everything the current value is greater than
        while (stack.Count > 0 && items[stack.Peek()] < items[i])
            result[stack.Pop()] = items[i];
        stack.Push(i);
    }
    return result;
}
```

**DFS using an explicit stack instead of recursion**
```csharp
public static List<int> DfsIterative(Dictionary<int, List<int>> graph, int start)
{
    var visited = new HashSet<int>();
    var stack = new Stack<int>();
    var order = new List<int>();
    
    stack.Push(start);
    while (stack.Count > 0)
    {
        int node = stack.Pop();
        if (!visited.Contains(node))
        {
            visited.Add(node);
            order.Add(node);
            if (graph.ContainsKey(node))
            {
                foreach (var neighbor in graph[node])
                    stack.Push(neighbor);
            }
        }
    }
    return order;
}
```

---

## Gotchas

- **Always check for empty before popping or peeking.** Popping an empty stack raises an exception. Every real-world stack usage needs a guard.
- **Python's `list` is fine as a stack; `collections.deque` is not necessary.** Deque is better for queues. For stack-only usage, `list.append()` and `list.pop()` are both O(1) amortized and idiomatic.
- **Monotonic stacks are underused.** A huge class of "next greater/smaller element" and "largest rectangle" problems collapse from O(n²) to O(n) with a monotonic stack. Most candidates don't reach for it.
- **Recursive algorithms have an implicit stack.** When recursion depth is a risk, convert to an explicit stack. Same logic, same order, no stack overflow.
- **Stack space in recursion is O(depth), not O(n) in general.** For a balanced binary tree of n nodes, depth is O(log n). For a skewed tree or a linear linked list, depth is O(n). Know the difference.

---

## Interview Angle

**What they're really testing:** Pattern recognition — can you see that a problem with nested or reversed structure maps to a stack?

**Common question form:** Valid parentheses, evaluate postfix expression, largest rectangle in histogram, implement a min-stack that returns the minimum in O(1).

**The depth signal:** A junior solves bracket matching. A senior knows the monotonic stack pattern and can apply it to "next greater element," "daily temperatures," or "largest rectangle in histogram" — and explains that the stack maintains a decreasing (or increasing) invariant, eliminating the need for a nested loop.

---

## Related Topics

- [[algorithms/queue.md]] — The FIFO counterpart; both are often compared in the same interview context.
- [[algorithms/graph.md]] — DFS is naturally stack-based; knowing this lets you convert recursion to iteration.
- [[algorithms/recursion-and-stack.md]] — Every recursive call is implicitly using the call stack.

---

## Source

https://docs.python.org/3/tutorial/datastructures.html#using-lists-as-stacks

---

*Last updated: 2026-03-24*