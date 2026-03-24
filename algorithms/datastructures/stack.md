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

**Using Python's list as a stack**
```python
stack = []
stack.append(1)   # push — O(1) amortized
stack.append(2)
stack.append(3)

top = stack[-1]   # peek without removing — O(1)
val = stack.pop() # pop — O(1) amortized
```

**Bracket matching — classic stack application**
```python
def is_valid(s: str) -> bool:
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    for char in s:
        if char in '([{':
            stack.append(char)
        elif char in ')]}':
            if not stack or stack[-1] != pairs[char]:
                return False
            stack.pop()
    return len(stack) == 0  # unmatched opens left = invalid
```

**Monotonic stack — next greater element in O(n)**
```python
def next_greater(items: list) -> list:
    result = [-1] * len(items)
    stack = []  # stores indices
    for i, val in enumerate(items):
        # pop everything the current value is greater than
        while stack and items[stack[-1]] < val:
            result[stack.pop()] = val
        stack.append(i)
    return result
```

**DFS using an explicit stack instead of recursion**
```python
def dfs_iterative(graph: dict, start: int) -> list:
    visited, stack, order = set(), [start], []
    while stack:
        node = stack.pop()
        if node not in visited:
            visited.add(node)
            order.append(node)
            stack.extend(graph[node])  # push neighbors
    return order
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