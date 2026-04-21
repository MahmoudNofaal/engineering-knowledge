# Bit Manipulation

> Operating directly on the binary representation of integers using bitwise operators to solve problems in O(1) time and O(1) space.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Boolean algebra on individual bits of integers |
| **Use when** | Flags, powers-of-two checks, XOR elimination, bitmask DP (n ≤ 20) |
| **Avoid when** | Code becomes unreadable without meaningful performance gain |
| **C# version** | C# 1.0+ for operators; `BitOperations` class in C# 9+ / .NET 5 |
| **Namespace** | `System.Numerics` for `BitOperations.PopCount`, `LeadingZeroCount` |
| **Key types** | `int`, `uint`, `long`, `ulong`; `BitOperations` (static) |

---

## When To Use It

Use bit manipulation when you need O(1) operations on sets of flags, when the problem involves powers of two, when you need to extract or toggle individual bits, or when XOR properties can eliminate pairs. Common signals: "find the single number," "count set bits," "check if power of 2," "generate all subsets." Avoid it when the code becomes unreadable without meaningful performance gain — bit tricks have a high maintenance cost. Always leave a comment explaining what each bit operation does.

---

## Core Concept

Every integer is stored in binary. Bitwise operators work on each bit position independently. The six operators: AND (`&`), OR (`|`), XOR (`^`), NOT (`~`), left shift (`<<`), right shift (`>>`). The properties that make them useful in algorithms:

- XOR is its own inverse: `a ^ a = 0`, `a ^ 0 = a` → cancels pairs
- AND with a mask extracts specific bits: `n & 1` checks the lowest bit
- `n & (n-1)` clears the lowest set bit — the foundation of fast bit counting
- `n & (-n)` isolates the lowest set bit — used in Fenwick trees
- Left shift `<<` multiplies by powers of 2 in O(1)

---

## Algorithm History

| Year | Development |
|---|---|
| 1940s | Shannon's information theory — bits as fundamental unit of information |
| 1960s | Hardware instruction sets expose bitwise ops to programmers |
| 1978 | Brian Kernighan's bit-counting trick published (in K&R C) |
| 1987 | Henry Warren documents bit manipulation tricks (later "Hacker's Delight") |
| 2003 | Hacker's Delight published — definitive reference on bit algorithms |
| 2019 | .NET 5 / C# 9 introduces `System.Numerics.BitOperations` with hardware-accelerated popcount |

---

## Performance

| Operation | Time | Notes |
|---|---|---|
| Check bit i | O(1) | `(n >> i) & 1` |
| Set bit i | O(1) | `n \| (1 << i)` |
| Clear bit i | O(1) | `n & ~(1 << i)` |
| Toggle bit i | O(1) | `n ^ (1 << i)` |
| Count set bits (Kernighan) | O(k) | k = number of set bits, not 32 |
| Count set bits (hardware popcount) | O(1) | `BitOperations.PopCount(n)` |
| Isolate lowest set bit | O(1) | `n & (-n)` |
| Clear lowest set bit | O(1) | `n & (n-1)` |
| Check power of 2 | O(1) | `n > 0 && (n & (n-1)) == 0` |

**Allocation behaviour:** All operations are register-level — zero heap allocation, zero GC pressure. Bit manipulation is the most allocation-free pattern in the entire catalogue.

**Benchmark notes:** `BitOperations.PopCount` (hardware POPCNT instruction) is ~10× faster than Kernighan's loop on modern CPUs. Use the hardware version in hot paths. For n ≤ 20 bitmask DP problems, all operations are O(1) — the bottleneck is always the O(2^n × n) outer loop, not the bit operations themselves.

---

## The Code

**Scenario 1 — core operations reference**
```csharp
using System.Numerics;

// Check if bit i is set
bool IsSet(int n, int i)  => ((n >> i) & 1) == 1;

// Set bit i
int SetBit(int n, int i)   => n | (1 << i);

// Clear bit i
int ClearBit(int n, int i) => n & ~(1 << i);

// Toggle bit i
int Toggle(int n, int i)   => n ^ (1 << i);

// Clear the lowest set bit — key trick
int ClearLowest(int n)     => n & (n - 1);

// Isolate the lowest set bit
int IsolateLowest(int n)   => n & (-n);

// Count set bits — hardware-accelerated in .NET 5+
int PopCount(uint n) => BitOperations.PopCount(n);

// Count set bits — Kernighan's loop (for older targets)
int PopCountManual(int n)
{
    int count = 0;
    while (n > 0) { n &= n - 1; count++; } // each iteration clears one set bit
    return count;
}
```

**Scenario 2 — single number (XOR to find the unpaired element)**
```csharp
public static int SingleNumber(int[] nums)
{
    int result = 0;
    foreach (int n in nums)
        result ^= n; // paired numbers cancel (a^a=0), lone number remains
    return result;
    // Works because XOR is commutative and associative — order doesn't matter
}

// Extension: find TWO single numbers in an array where all others appear twice
public static (int, int) TwoSingleNumbers(int[] nums)
{
    int xor = nums.Aggregate(0, (acc, n) => acc ^ n); // xor = a ^ b
    int diffBit = xor & (-xor);                        // isolate one bit where a ≠ b
    int a = 0, b = 0;
    foreach (int n in nums)
    {
        if ((n & diffBit) != 0) a ^= n; // group by the differing bit
        else                     b ^= n;
    }
    return (a, b);
}
```

**Scenario 3 — bitmask subset enumeration (alternative to backtracking for small n)**
```csharp
public static List<List<int>> SubsetsBitmask(int[] nums)
{
    int n = nums.Length; // works for n ≤ 20 (2^20 = 1M subsets)
    var result = new List<List<int>>(1 << n);

    for (int mask = 0; mask < (1 << n); mask++)
    {
        var subset = new List<int>();
        for (int i = 0; i < n; i++)
            if ((mask & (1 << i)) != 0) // bit i set → include nums[i]
                subset.Add(nums[i]);
        result.Add(subset);
    }
    return result;
}
```

**Scenario 4 — what NOT to do: using division/modulo for power-of-2 checks**
```csharp
// BAD: O(log n) repeated division — verbose and slow
public static bool IsPowerOfTwoBad(int n)
{
    if (n <= 0) return false;
    while (n > 1)
    {
        if (n % 2 != 0) return false;
        n /= 2;
    }
    return true;
}

// GOOD: O(1) — a power of 2 has exactly one set bit; n-1 flips all bits below it
public static bool IsPowerOfTwoGood(int n) => n > 0 && (n & (n - 1)) == 0;
// Proof: if n = 0b001000, then n-1 = 0b000111, so n & (n-1) = 0.
// Any non-power-of-2 has ≥2 set bits; n & (n-1) clears only the lowest one → result ≠ 0.
```

---

## Real World Example

The `FeatureFlagService` in a multi-tenant SaaS platform stores per-tenant feature enablement as a bitmask. With 32 features fitting in a single `int`, querying, enabling, and disabling features are all O(1) with zero allocations — compared to a `HashSet<string>` which allocates per operation. The bitmask is persisted as a single integer column in the database.

```csharp
public class FeatureFlagService
{
    // Feature definitions — each is a power of 2 (one bit)
    [Flags]
    public enum Feature : uint
    {
        None           = 0,
        DarkMode       = 1 << 0,   // 0b00000001
        ExportToCsv    = 1 << 1,   // 0b00000010
        AdvancedSearch = 1 << 2,   // 0b00000100
        ApiAccess      = 1 << 3,   // 0b00001000
        AuditLog       = 1 << 4,   // 0b00010000
        BetaFeatures   = 1 << 5,   // 0b00100000
    }

    private readonly Dictionary<int, uint> _tenantFlags = new();

    // O(1) — bitwise OR sets the feature bit
    public void Enable(int tenantId, Feature feature)
    {
        _tenantFlags[tenantId] = _tenantFlags.GetValueOrDefault(tenantId) | (uint)feature;
    }

    // O(1) — bitwise AND with NOT clears the feature bit
    public void Disable(int tenantId, Feature feature)
    {
        _tenantFlags[tenantId] = _tenantFlags.GetValueOrDefault(tenantId) & ~(uint)feature;
    }

    // O(1) — bitwise AND checks if the bit is set
    public bool IsEnabled(int tenantId, Feature feature)
    {
        return (_tenantFlags.GetValueOrDefault(tenantId) & (uint)feature) != 0;
    }

    // O(1) — returns count of enabled features for billing purposes
    public int EnabledFeatureCount(int tenantId)
    {
        return BitOperations.PopCount(_tenantFlags.GetValueOrDefault(tenantId));
    }

    // Returns all enabled features for a tenant — O(k) where k = number of features defined
    public List<Feature> GetEnabledFeatures(int tenantId)
    {
        uint flags = _tenantFlags.GetValueOrDefault(tenantId);
        var result = new List<Feature>();
        foreach (Feature f in Enum.GetValues<Feature>())
            if (f != Feature.None && (flags & (uint)f) != 0)
                result.Add(f);
        return result;
    }
}
```

*The key insight: the `[Flags]` attribute and power-of-2 enum values make the bit meaning explicit and auditable in code, while the underlying storage remains a single `uint` — one integer column, O(1) all operations, zero allocation.*

---

## Common Misconceptions

**"~n gives the bitwise complement in C#"**
In C#, `~n` gives `-(n+1)` in two's complement — not a 32-bit bitmask flip. `~0` is `-1`, not `0xFFFFFFFF`. If you want a 32-bit NOT, use `n ^ 0xFFFFFFFF` or operate with `uint`. This trips up programmers coming from languages with unsigned-by-default integers.

**"XOR is just addition without carry — order matters"**
XOR is commutative (`a ^ b = b ^ a`) and associative (`(a ^ b) ^ c = a ^ (b ^ c)`). Order never matters. This is what makes the single-number trick work — all paired elements cancel regardless of their position in the array. If you're unsure about this, verify: `3 ^ 5 ^ 3 = 5`, `5 ^ 3 ^ 3 = 5`.

**"Bitmask DP is exponential — always too slow"**
For n ≤ 20, bitmask DP is O(2^n × n) = ~20 million operations — fast enough for competitive programming and many real-world small-n problems (TSP with ≤ 15 cities, assignment problems). The constraint "n ≤ 20" in a problem statement is an explicit signal that bitmask DP is the intended approach.

---

## Gotchas

- **`1 << i` is `int` — overflows for i ≥ 31.** Use `1L << i` for 64-bit masks or `1u << i` for unsigned. In C#, `1 << 32` is 1 (undefined behaviour in C/C++, defined as rotation in C#) — always cast when the bit index could reach 31+.

- **`n & (n-1)` requires n > 0.** If n = 0, `n-1` underflows to `int.MaxValue` for `uint` or wraps to -1 for `int`. The loop condition must guard against n = 0 explicitly.

- **Signed right shift (`>>`) fills with the sign bit in C#.** `(-8) >> 1` is `-4`, not `2147483644`. Use `>>>` (unsigned right shift, C# 11+) or cast to `uint` first when you want zero-fill.

- **C# unsigned right shift `>>>` was added in C# 11.** For older targets, use `(uint)n >> i` to get logical (zero-fill) right shift behaviour.

- **`BitOperations.PopCount` requires `uint` or `ulong`.** Passing a signed `int` requires an explicit cast: `BitOperations.PopCount((uint)n)`. The cast preserves the bit pattern — the -1 signed `int` (all bits set) correctly gives popcount 32.

---

## Interview Angle

**What they're really testing:** Whether you know the core XOR properties and `n & (n-1)` trick, and whether you can apply them without re-deriving from first principles under pressure.

**Common question forms:**
- "Find the single number in an array where all others appear twice."
- "Number of 1 bits (Hamming weight)."
- "Is this number a power of two?"
- "Reverse bits of a 32-bit integer."
- "Missing number in [0..n]."
- "Sum of two integers without using + or -."

**The depth signal:** A junior knows XOR cancels duplicates. A senior knows why: XOR is commutative, associative, and self-inverse. They apply `n & (n-1)` for bit counting (Kernighan — O(set bits), not O(32)), know the two-singles trick using the differing bit to partition the array, and can explain bitmask subset enumeration as an alternative to recursive backtracking. They also know `BitOperations.PopCount` is hardware-accelerated and should be preferred over manual loops in .NET 5+.

**Follow-up questions to expect:**
- "Why does `n & (n-1)` clear the lowest set bit?" → n-1 flips all bits from the lowest set bit downward; AND with n clears that bit and preserves the rest.
- "How would you find the missing number in [0..n] in O(1) space?" → XOR all numbers 0..n with all array elements — paired values cancel, leaving the missing one.

---

## Related Topics

- [[algorithms/patterns/dynamic-programming.md]] — Bitmask DP uses bitmasks as DP state for subset enumeration problems.
- [[algorithms/patterns/backtracking.md]] — Bitmask subset generation is a non-recursive alternative to backtracking for small n.
- [[algorithms/datastructures/array.md]] — Bit arrays (boolean arrays as packed integers) are the memory-efficient alternative to `bool[]`.

---

## Source

https://en.wikipedia.org/wiki/Bit_manipulation

---

*Last updated: 2026-04-21*