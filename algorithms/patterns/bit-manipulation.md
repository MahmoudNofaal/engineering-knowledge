# Bit Manipulation
> Operating directly on the binary representation of integers using bitwise operators to solve problems in O(1) time and O(1) space.

---

## When To Use It
Use bit manipulation when you need O(1) operations on sets of flags, when the problem involves powers of two, when you need to extract or toggle individual bits, or when XOR properties can eliminate pairs. Common signals: "find the single number," "count set bits," "check if power of 2," "generate all subsets." Avoid it when the code becomes unreadable without meaningful performance gain — bit tricks have a high maintenance cost.

---

## Core Concept
Every integer is stored in binary. Bitwise operators work on each bit position independently. The six operators: AND (`&`), OR (`|`), XOR (`^`), NOT (`~`), left shift (`<<`), right shift (`>>`). The properties that make them useful in algorithms: XOR is its own inverse (a^a=0, a^0=a), AND with a mask extracts specific bits, shifts multiply and divide by powers of 2 in O(1), and `n & (n-1)` clears the lowest set bit.

---

## The Code

**Core operations reference**
```csharp
int n = 0b1010;  // 10 in decimal

// Check if bit i is set
bool IsSet(int n, int i) => ((n >> i) & 1) == 1;

// Set bit i
int SetBit(int n, int i) => n | (1 << i);

// Clear bit i
int ClearBit(int n, int i) => n & ~(1 << i);

// Toggle bit i
int ToggleBit(int n, int i) => n ^ (1 << i);

// Clear lowest set bit — key trick
int ClearLowest(int n) => n & (n - 1);

// Isolate lowest set bit
int LowestSetBit(int n) => n & (-n);
```

**Check power of 2 — O(1)**
```csharp
public static bool IsPowerOfTwo(int n)
{
    return n > 0 && (n & (n - 1)) == 0;
    // A power of 2 has exactly one set bit.
    // n-1 flips all bits below that bit and clears it.
    // n & (n-1) == 0 only when n has exactly one set bit.
}
```

**Count set bits (Hamming weight) — Brian Kernighan**
```csharp
public static int CountBits(int n)
{
    int count = 0;
    while (n > 0)
    {
        n &= n - 1;    // clear lowest set bit
        count++;
    }
    return count;      // O(number of set bits), not O(32)
}
```

**Single number — XOR to find unpaired element**
```csharp
public static int SingleNumber(int[] nums)
{
    int result = 0;
    foreach (int n in nums)
        result ^= n;   // paired numbers cancel (a^a=0), lone number remains
    return result;
}
```

**Single number III — two distinct unpaired elements**
```csharp
public static int[] SingleNumberIII(int[] nums)
{
    int xor = 0;
    foreach (int n in nums) 
        xor ^= n;                   // xor = a ^ b (the two single numbers)
    
    int diffBit = xor & (-xor);     // isolate any bit where a and b differ
    int a = 0, b = 0;
    
    foreach (int n in nums)
    {
        if ((n & diffBit) != 0)
            a ^= n;                 // group by the differing bit
        else
            b ^= n;
    }
    return new[] { a, b };
}
```

**Subsets via bitmask — enumerate all 2^n subsets**
```csharp
public static List<List<int>> SubsetsBitmask(int[] nums)
{
    int n = nums.Length;
    var result = new List<List<int>>();
    
    for (int mask = 0; mask < (1 << n); mask++)
    {
        var subset = new List<int>();
        for (int i = 0; i < n; i++)
        {
            if ((mask & (1 << i)) != 0)
                subset.Add(nums[i]);
        }
        result.Add(subset);
    }
    return result;
}
```

**Reverse bits of a 32-bit integer**
```csharp
public int ReverseBits(int n)
{
    int result = 0;
    for (int i = 0; i < 32; i++)
    {
        result = (result << 1) | (n & 1);  // take LSB of n, append to result
        n >>= 1;
    }
    return result;
}
```

---

## Gotchas

- **Python integers are arbitrary precision — no 32-bit overflow.** Most bit manipulation problems assume 32-bit unsigned integers. In Python, you may need to mask with `& 0xFFFFFFFF` to simulate fixed-width behavior or handle negative numbers correctly.
- **`~n` in Python is `-(n+1)`, not a bitmask flip.** Python's `~` uses two's complement on arbitrary-precision integers, so `~0` is -1, not `0xFFFFFFFF`. Use `n ^ 0xFFFFFFFF` if you want a 32-bit NOT.
- **`n & (n-1)` requires n > 0.** `0 & -1 = 0`, which is technically fine, but your loop condition must guard against n=0 or the loop doesn't terminate.
- **XOR is associative and commutative — order doesn't matter.** This is what makes the single-number trick work. All paired elements cancel regardless of order, leaving only the unpaired element.
- **Bitmask DP is a real technique.** For small n (typically ≤ 20), you can represent subsets as bitmasks and DP over them. TSP with bitmask DP is O(n² × 2^n) — exponential but tractable for n ≤ 20.

---

## Interview Angle

**What they're really testing:** Whether you know the core XOR properties and `n & (n-1)` trick, and whether you can apply them without having to re-derive from first principles under pressure.

**Common question form:** Single number, number of 1 bits, power of two, reverse bits, missing number, sum of two integers without `+`.

**The depth signal:** A junior knows XOR cancels duplicates. A senior knows why: XOR is commutative, associative, and self-inverse — so any value XOR'd with itself is 0, and 0 XOR'd with anything is that thing. They apply `n & (n-1)` for counting bits (Brian Kernighan — O(set bits), not O(32)), know the single-number III trick using the differing bit to partition the array, and can explain bitmask subset enumeration as an alternative to recursive backtracking.

---

## Related Topics

- [[algorithms/dynamic-programming.md]] — Bitmask DP uses bitmasks as DP state for subset enumeration problems.
- [[algorithms/backtracking.md]] — Bitmask subset generation is an alternative to recursive backtracking for subsets.
- [[algorithms/common-patterns-map.md]] — Bit manipulation appears in optimization patterns across multiple domains.

---

## Source

https://en.wikipedia.org/wiki/Bit_manipulation

---

*Last updated: 2026-03-24*