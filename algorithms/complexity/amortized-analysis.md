# Amortized Analysis
> A technique for measuring the *average* cost of operations in a sequence, used when individual operations have variable costs that balance out over time.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Averaging operation cost over a sequence, not per-call |
| **Use when** | Individual operations have wildly different costs (e.g. resize events) |
| **Avoid when** | Each operation is independent and same cost — just use Big-O directly |
| **Key data structures** | `List<T>`, `Dictionary<K,V>`, `Stack<T>`, `StringBuilder` |
| **Methods** | Aggregate, Accounting (banker's), Potential (physicist's) |
| **Key result** | `List<T>.Add` is O(1) amortized despite occasional O(n) resizes |

---

## When To Use It

Use amortized analysis when an operation's cost varies dramatically across a sequence of calls — mostly cheap, occasionally expensive — and you want to know the *guaranteed average* cost per operation over n calls. This is different from average-case analysis (which assumes a random input distribution). Amortized is a worst-case guarantee about sequences, not a probabilistic statement.

The most common scenario in C#: any dynamically-resizing data structure (`List<T>`, `Dictionary<K,V>`, `HashSet<T>`, `StringBuilder`) has amortized-O(1) operations despite periodic O(n) resize events. Understanding this is table stakes for senior-level interviews and for correctly analyzing service performance under load.

---

## Core Concept

Amortized analysis charges expensive operations against a "credit" built up by earlier cheap operations. There are three equivalent methods: the **aggregate method** (total cost of n operations ÷ n), the **accounting method** (charge cheap operations extra to "bank" credit for expensive ones), and the **potential method** (define a potential function that measures stored energy, prove each operation's real cost + change in potential ≤ amortized cost).

For practical purposes, the aggregate method is the most intuitive. For `List<T>`: across n `.Add()` calls, each element is copied at most once per doubling — roughly log₂(n) doublings, each copying O(n/2) elements. Total copy work: n/2 + n/4 + n/8 + ... < n. Total `.Add()` work across n calls: O(n) copies + O(n) insertions = O(n). Per operation: O(n) / n = **O(1) amortized**.

---

## Version History

| Concept | Introduced By | Year | Notes |
|---|---|---|---|
| Amortized analysis | Robert Tarjan | 1985 | Formalized in "Amortized Complexity" paper |
| Potential method | Sleator & Tarjan | 1985 | Used to analyze splay trees |
| List<T> doubling strategy | Common in .NET | .NET 1.0+ | Capacity doubles at 4 → 8 → 16 → ... |
| Dictionary<K,V> resize | Common in .NET | .NET 1.0+ | Resizes when load factor exceeds 0.72 |

*The doubling strategy (capacity × 2 on resize) is critical — it ensures amortized O(1). A fixed-increment strategy (capacity + k) would make Add O(n) amortized, not O(1). The geometric growth is the mathematical requirement.*

---

## Performance

| Operation | Worst-case per call | Amortized | Notes |
|---|---|---|---|
| `List<T>.Add()` | O(n) — resize | O(1) | Doubling strategy |
| `List<T>[i]` | O(1) | O(1) | No variability |
| `Dictionary.Add()` | O(n) — rehash | O(1) amortized | Rehash at ~72% load |
| `Dictionary.TryGetValue()` | O(1) amortized | O(1) | Hash collision degrades to O(n) |
| `StringBuilder.Append()` | O(n) — resize | O(1) | Same doubling strategy |
| `Stack<T>.Push()` | O(n) — resize | O(1) | Backed by array, same pattern |
| Splay tree operation | O(n) | O(log n) | Classic potential method result |

**Allocation behaviour:** The resize events in amortized-O(1) structures allocate new backing arrays on the heap. For `List<T>` going from capacity 1 to n, it allocates arrays of size 1, 2, 4, 8, ..., n — the old arrays become garbage. Total garbage created: O(n) bytes over n operations. This is usually fine but relevant in high-throughput GC analysis.

**Benchmark notes:** If you pre-size a `List<T>` with `new List<T>(expectedCapacity)`, you avoid all resize events and the `Add` cost becomes truly O(1) — no amortization needed. Pre-sizing is a simple, high-value optimization in bulk processing paths.

---

## The Code

**Demonstrating the doubling strategy in List<T>**
```csharp
var list = new List<int>();   // starts with capacity 0

for (int i = 0; i < 17; i++)
{
    list.Add(i);
    Console.WriteLine($"Count={list.Count}, Capacity={list.Capacity}");
}
// Output:
// Count=1,  Capacity=4     ← initial allocation
// Count=4,  Capacity=4
// Count=5,  Capacity=8     ← first resize: copy 4 elements
// Count=8,  Capacity=8
// Count=9,  Capacity=16    ← resize: copy 8 elements
// Count=16, Capacity=16
// Count=17, Capacity=32    ← resize: copy 16 elements
//
// Total copy operations across 17 adds: 4 + 8 + 16 = 28
// All adds + copies: 17 + 28 = 45 operations
// Per add: 45 / 17 ≈ 2.6 → O(1) amortized
```

**Aggregate method — prove O(1) amortized for n Add operations**
```csharp
// Mathematical argument (not runnable — demonstrating the proof structure)
//
// For n Add operations on a List starting empty:
// - Resize 1: copy 1 elements (capacity 0 → 1)  [actually skipped, starts at 4 in .NET]
// - Resize 2: copy 4 elements (capacity 4 → 8)
// - Resize 3: copy 8 elements (capacity 8 → 16)
// - Resize k: copy 2^k elements
//
// Total copies = 4 + 8 + 16 + ... + n/2 + n
//             = n + n/2 + n/4 + ... (geometric series)
//             < 2n
//
// Total work for n Adds = n insertions + < 2n copies = O(n)
// Amortized cost per Add = O(n) / n = O(1) ✓
```

**Accounting method — charging extra on cheap operations**
```csharp
// Conceptual demonstration of the accounting method:
//
// Each Add is charged 3 "tokens" instead of 1:
//   - 1 token pays for the actual insertion
//   - 2 tokens are "saved" in the element itself
//
// When a resize occurs (copying n elements):
//   - Each element pays its 2 saved tokens to cover its own copy
//   - The n elements collectively pay the entire O(n) resize cost
//
// Result: every Add pays ≤ 3 tokens regardless of whether a resize happens
// 3 tokens per Add × n Adds = 3n = O(n) total → O(1) amortized per Add

// In code: pre-allocating demonstrates the optimization this enables
var list = new List<int>(capacity: 100_000);  // pay the resize cost upfront
for (int i = 0; i < 100_000; i++)
    list.Add(i);  // every Add is now genuinely O(1) — no resize events at all
```

**Dictionary amortized O(1) with load factor trigger**
```csharp
var dict = new Dictionary<int, string>();

// Dictionary resizes when Count / Capacity exceeds ~0.72 (load factor)
// Each resize: rehashes all existing entries into a new, larger backing array
// Amortized over n insertions: O(1) per insertion (same geometric argument)

for (int i = 0; i < 10; i++)
    dict[i] = i.ToString();

// Watch the internal capacity double on each resize:
// (No direct Capacity property, but you can observe via reflection or debugger)
// The resize events are invisible to callers — they just see O(1) amortized

// Pre-size to avoid all resize events — O(1) guaranteed per insertion:
var preSized = new Dictionary<int, string>(expectedCount: 10_000);
```

**StringBuilder — same amortized guarantee**
```csharp
// BAD: string concatenation in loop — O(n²) time AND O(n) garbage
string result = "";
for (int i = 0; i < 10_000; i++)
    result += i.ToString();  // creates new string each iteration!

// GOOD: StringBuilder has amortized O(1) Append — total O(n)
var sb = new StringBuilder();
for (int i = 0; i < 10_000; i++)
    sb.Append(i);
string final = sb.ToString();

// Why StringBuilder is O(1) amortized: same doubling strategy as List<T>
// Internal char buffer doubles on resize → total copy work is O(n)
```

---

## Real World Example

An event processing pipeline buffered incoming events into a list before batching them to a downstream service. The initial implementation used `string += event.Serialize()` to build the batch payload. At 10,000 events per batch, the concatenation loop allocated a new string for each of the 10,000 iterations — O(n²) allocations in total. GC pause times made P99 latency exceed SLAs.

```csharp
// BAD: O(n²) time, O(n²) total allocation due to string immutability
public string BuildBatchPayload_Naive(List<Event> events)
{
    string payload = "[";
    foreach (var ev in events)
    {
        payload += ev.Serialize();   // allocates NEW string each iteration
        payload += ",";              // allocates ANOTHER new string
    }
    return payload.TrimEnd(',') + "]";
    // For 10,000 events: ~20,000 string allocations, sizes growing from ~10 to ~500KB
    // Total allocations: sum of 1+2+3+...+n ≈ n²/2 characters
}

// GOOD: O(n) time, O(n) total allocation — StringBuilder amortized O(1) Append
public string BuildBatchPayload_Fast(List<Event> events)
{
    // Pre-size with estimated capacity to avoid even the resize events
    var sb = new StringBuilder(capacity: events.Count * 64);
    sb.Append('[');
    for (int i = 0; i < events.Count; i++)
    {
        if (i > 0) sb.Append(',');
        sb.Append(events[i].Serialize());
    }
    sb.Append(']');
    return sb.ToString();
    // One backing array, doubled geometrically on resize → O(n) total work
}
```

*The key insight: string concatenation is O(n) per operation because strings are immutable in C# — every `+=` creates a new string by copying all previous content. StringBuilder's amortized O(1) Append is what makes building large strings feasible.*

---

## Common Misconceptions

**"Amortized O(1) means some calls are slow — it's unreliable for latency-sensitive code"**
The amortized guarantee is about *total work over many operations*, not individual call latency. A single `List<T>.Add()` that triggers a resize is genuinely O(n) in wall time — it can cause jitter. For latency-sensitive systems (real-time, SLA-bound), pre-sizing eliminates resize events entirely: `new List<T>(knownCapacity)`. Amortized analysis proves the aggregate is efficient; pre-sizing proves every individual call is efficient.

**"Amortized O(1) and average-case O(1) are the same claim"**
They're different types of guarantees. Amortized O(1) is a *worst-case guarantee over a sequence* — it holds regardless of input values, regardless of how adversarial the sequence is. Average-case O(1) is a *probabilistic claim over random inputs* — it can be defeated by adversarial inputs. `Dictionary<K,V>` lookups are amortized O(1) for insertions and average-case O(1) for lookups; a pathological hash collision can make a specific lookup O(n).

**"The doubling strategy is just an implementation detail — any growth strategy works"**
The doubling factor is mathematically necessary for amortized O(1). A fixed increment (`capacity + k`) gives amortized O(n) per Add — you do n/k resizes, each copying O(n) elements, total O(n²/k) = O(n²) work, O(n) amortized per Add. A growth factor < 2 still gives amortized O(1) (e.g., ×1.5) but with a larger constant. Any constant factor > 1 gives O(1) amortized; any fixed increment gives O(n) amortized.

---

## Gotchas

- **Pre-size when you know the count.** `new List<T>(n)` and `new Dictionary<K,V>(n)` skip all resize events, converting amortized O(1) into actual O(1) per operation. In bulk insert paths, this is one of the simplest high-value optimizations.

- **Amortized analysis assumes the full sequence.** If you use a `List<T>` and only ever call `.Add()` once then discard it, the amortized argument doesn't apply — you're paying for capacity you never use. In practice this is rarely a problem but matters for precise analysis.

- **GC sees the intermediate garbage, not just the final state.** When `List<T>` resizes from capacity 8 to 16, the old 8-element backing array is garbage. Over n Adds, the garbage created is O(n) total bytes — usually fine, but significant in high-frequency bulk processing. `ArrayPool<T>` avoids this for cases where you know the final size.

- **`Dictionary.TryGetValue()` is amortized O(1) for inserts but can degrade for lookups.** If all keys hash to the same bucket (adversarial `GetHashCode()`), all lookups become O(n). In production, use well-distributed hash codes and avoid exposing dictionary key types to external input without validation.

- **`StringBuilder.ToString()` is O(n) — it's the one non-O(1) operation.** Building incrementally is amortized O(1) per Append, but the final `ToString()` copies all content to a new immutable string. This is expected and unavoidable — just don't call it inside a loop.

---

## Interview Angle

**What they're really testing:** Whether you understand that "O(1)" sometimes means "O(1) amortized" — and that you can explain the difference without confusing it with average-case. Conflating the two is a common gap.

**Common question forms:**
- "What's the time complexity of `List.Add()`?"
- "Why is `List.Add()` O(1) if resizing is O(n)?"
- "Explain the difference between amortized O(1) and average-case O(1)"

**The depth signal:** A junior says "Add is O(1)." A senior says "Add is O(1) amortized — each individual Add can be O(n) during a resize, but over n Adds, the total work is O(n), so per-operation it averages to O(1). This is guaranteed regardless of input, unlike average-case which depends on input distribution. If you need guaranteed O(1) per call, pre-size the list."

**Follow-up questions to expect:**
- "What growth strategy produces amortized O(1)? Would a fixed increment work?"
- "How does this affect GC pressure in a .NET service?"
- "If you knew you were adding exactly 10,000 elements, how would you optimize?"

---

## Related Topics

- [[algorithms/complexity/big-o-notation.md]] — The notation and the difference between O (worst-case) and amortized.
- [[algorithms/complexity/complexity-analysis.md]] — Where amortized analysis fits in the broader analysis toolkit.
- [[dotnet/csharp/csharp-collections-list.md]] — How List<T> uses doubling and when to pre-size.
- [[dotnet/csharp/csharp-collections-dictionary.md]] — Dictionary load factor, rehashing, and hash collision degradation.
- [[dotnet/csharp/csharp-garbage-collector.md]] — Why intermediate allocations from resizes affect GC pressure.

---

## Source

https://en.wikipedia.org/wiki/Amortized_analysis

---

*Last updated: 2026-04-12*