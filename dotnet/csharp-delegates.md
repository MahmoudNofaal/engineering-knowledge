# C# Delegates

> A delegate is a type-safe function pointer — a variable that holds a reference to a method and can invoke it later.

---

## When To Use It

Use delegates when you need to pass behaviour as an argument, store a callback, or let callers inject logic into a method without knowing the implementation at compile time. They are the foundation of events, LINQ, and the `Func`/`Action` family. Do not define a custom delegate type when `Func<>`, `Action<>`, or `Predicate<>` already match your signature — the built-in types communicate intent more clearly and require no extra declaration.

---

## Core Concept

A delegate is a type that describes a method signature — its return type and parameters. Once you have a delegate type, you can create an instance of it that points to any method matching that signature, then call it through the delegate without knowing or caring which method is actually behind it. This is how you pass methods around like values. Multicast delegates extend this: a single delegate instance can point to a chain of methods, all of which get called in order when you invoke it. Events in C# are just a multicast delegate wrapped with add/remove access control so external code can only subscribe and unsubscribe, not replace or invoke the list outright.

---

## The Code
```csharp
// --- Custom delegate type ---
public delegate int Transform(int input);

Transform doubler = x => x * 2;
Transform squarer = x => x * x;

Console.WriteLine(doubler(5));  // 10
Console.WriteLine(squarer(5));  // 25

// Pass a delegate as a parameter
int ApplyTwice(Transform t, int value) => t(t(value));
Console.WriteLine(ApplyTwice(doubler, 3)); // 12

// --- Func / Action / Predicate: prefer these over custom delegates ---
Func<int, int>       double2   = x => x * 2;       // has return value
Action<string>       log       = msg => Console.WriteLine(msg); // void return
Predicate<string>    isEmpty   = s => s.Length == 0; // bool return, sugar for Func<T, bool>

Func<int, int, string> format  = (a, b) => $"{a}+{b}={a+b}"; // multiple params

// --- Multicast delegate: chain multiple methods ---
Action<string> pipeline = null;
pipeline += s => Console.WriteLine(s.ToUpper());
pipeline += s => Console.WriteLine(s.Length);
pipeline += s => Console.WriteLine(s.Reverse());

pipeline("hello"); // all three run in order

// Remove a method from the chain
Action<string> upper = s => Console.WriteLine(s.ToUpper());
pipeline -= upper; // removes the first matching method in the chain

// --- Delegate as a callback (strategy pattern) ---
public class Sorter
{
    public int[] Sort(int[] data, Func<int, int, int> compare)
    {
        return data.OrderBy(x => x, Comparer<int>.Create((a, b) => compare(a, b))).ToArray();
    }
}

var sorter = new Sorter();
int[] result = sorter.Sort(new[] { 3, 1, 4, 1, 5 }, (a, b) => a.CompareTo(b));

// --- Event: multicast delegate with access control ---
public class Button
{
    public event Action<string>? Clicked; // external code can only += and -=

    public void Click(string label)
    {
        Clicked?.Invoke(label); // null-check because no subscribers means null
    }
}

var btn = new Button();
btn.Clicked += label => Console.WriteLine($"Button '{label}' was clicked");
btn.Click("Submit");

// --- Delegate stored as a field (without event keyword) ---
// Exposes full assignment — callers can replace the entire chain or invoke it directly
public class Processor
{
    public Func<string, string>? Middleware; // caller can set, replace, or invoke

    public string Process(string input)
    {
        return Middleware?.Invoke(input) ?? input;
    }
}
```

---

## Gotchas

- **Multicast delegate invocation stops on the first unhandled exception.** If the chain has three subscribers and the second throws, the third never runs. There is no built-in try/catch per subscriber. If you need resilient fan-out, get the invocation list with `del.GetInvocationList()` and invoke each delegate individually inside a try/catch.
- **Closures capture the variable, not the value at the time of capture.** A lambda that closes over a loop variable captures the variable itself, so by the time the delegate is invoked all captured copies may reflect the final loop value. Assign the loop variable to a local inside the loop body before capturing it.
- **`event` prevents callers from invoking or replacing the delegate; a bare `Func` field does not.** If you expose a `public Func<string, string> Transform`, any caller can call `obj.Transform("x")` directly or do `obj.Transform = null`, wiping out every subscriber. Use `event` when external code should only subscribe and unsubscribe.
- **Removing a lambda with `-=` only works if it is the same delegate instance.** `pipeline -= s => Console.WriteLine(s)` creates a new lambda object, which does not match the one added earlier. Store the lambda in a variable first, then add and remove that variable.
- **`Delegate.Combine` and multicast work for `void`-returning delegates, but return value semantics are lossy.** For a multicast `Func<int>`, only the return value of the last method in the chain is kept — all others are silently discarded. If you need all return values, use `GetInvocationList` and collect results manually.

---

## Interview Angle

**What they're really testing:** Whether you understand delegates as the mechanism behind events, callbacks, and LINQ — and the difference between exposing a raw delegate field versus an `event`.

**Common question form:** "What is a delegate?" or "What's the difference between a delegate and an event?" or "How do closures work with lambda expressions?"

**The depth signal:** A junior says "a delegate is a pointer to a method" and "an event is a special delegate." A senior explains that `event` is an access modifier on a multicast delegate that restricts external callers to `+=`/`-=` only — preventing them from invoking the delegate or replacing the entire subscription list with `=`; knows that multicast exception propagation stops at the first throw and how to work around it with `GetInvocationList`; and can explain the closure variable-capture gotcha concretely — that a lambda captures the variable binding, not the value, which is why loop-variable captures inside `Task.Run` or LINQ projections frequently surprise people.

---

## Related Topics

- [[dotnet/csharp-linq.md]] — LINQ is built entirely on delegates; every `Where`, `Select`, and `OrderBy` takes a `Func<>` argument whose implementation you provide as a lambda.
- [[dotnet/csharp-events.md]] — Events are multicast delegates with restricted access; understanding delegates first makes the event model obvious rather than magical.
- [[dotnet/csharp-task-parallel-library.md]] — `Task.Run`, `Parallel.For`, and `ContinueWith` all accept `Action` or `Func` delegates as their work units.
- [[dotnet/csharp-expression-trees.md]] — Expression trees are the compile-time representation of a lambda as data rather than code; they sit directly on top of the delegate model and are how EF Core translates LINQ to SQL.

---

## Source

[https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/)

---
*Last updated: 2026-03-23*