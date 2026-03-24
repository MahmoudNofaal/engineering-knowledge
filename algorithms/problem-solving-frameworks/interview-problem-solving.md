# Interview Problem Solving
> A repeatable process for approaching any algorithm problem in an interview — from reading the problem to writing clean, correct code.

---

## When To Use It
Every time you sit down for a technical interview. This isn't an algorithm — it's a meta-process. The purpose is to avoid the two most common failure modes: jumping to code before understanding the problem, and freezing when you don't immediately see the solution. A structured approach signals seniority regardless of whether you solve the problem.

---

## Core Concept
Interviewers evaluate process as much as correctness. A candidate who talks through their reasoning, catches edge cases before coding, and iterates clearly is more valuable than one who silently produces a correct solution. The process has six phases: understand, examples, approach, complexity, code, test. Never skip phases — especially understand and approach. Coding before you have a plan is the most common interview mistake.

---

## The Code

**The six-phase framework**
```python
# PHASE 1: UNDERSTAND (2-3 minutes)
# - Restate the problem in your own words
# - Clarify constraints: input size, value ranges, nulls, duplicates
# - Ask: sorted? unique? integers only? what if empty input?
# - Don't assume — ask. Wrong assumptions waste 20 minutes.

# PHASE 2: EXAMPLES (2-3 minutes)
# - Work through 2-3 concrete examples by hand, including edge cases
# - Edge cases: empty input, single element, all same, already sorted,
#   negatives, max/min values, no valid answer
# - This often reveals the algorithm before you even think about it

# PHASE 3: APPROACH (3-5 minutes)
# - Verbalize the brute-force solution first, with its complexity
# - Then ask: can I sort first? can I use a hash map? can I use two pointers?
# - Identify the pattern: see common-patterns-map.md
# - Agree on approach with interviewer BEFORE writing code
# - State time and space complexity of your planned approach

# PHASE 4: CODE (10-15 minutes)
# - Write clean, readable code — name variables clearly
# - Handle edge cases as you go, don't defer them
# - Narrate what you're doing: "I'm using a sliding window here because..."
# - If stuck: restate what you know, work a small example by hand

# PHASE 5: VERIFY (3-5 minutes)
# - Trace through your code with a simple example — not just mentally, on paper
# - Check: does the loop terminate? are indices correct? does it handle empty?
# - Fix bugs you find — interviewers want to see you catch your own mistakes

# PHASE 6: OPTIMIZE (if time allows)
# - Can time complexity be reduced?
# - Can space complexity be reduced?
# - Are there any edge cases still unhandled?
```

**Pattern recognition — the first question to ask**
```python
def identify_pattern(problem_description: str) -> str:
    signals = {
        "sorted array + find pair/triplet":       "two pointers",
        "subarray sum/length with constraint":    "sliding window",
        "linked list cycle/midpoint":             "fast/slow pointers",
        "shortest path, unweighted":              "BFS",
        "shortest path, weighted, non-negative":  "Dijkstra",
        "all paths / cycle detection / DFS":      "DFS / backtracking",
        "top-k / streaming min-max":              "heap",
        "sorted lookup / boundary search":        "binary search",
        "count ways / optimal value":             "dynamic programming",
        "interval overlap / scheduling":          "greedy + sort by end",
        "prefix/common string operations":        "trie",
        "XOR / flags / subset enumeration":       "bit manipulation",
        "range query on mutable array":           "segment tree",
    }
    # This isn't code — it's a mental map.
    # The real skill is pattern-matching on first read.
```

**The brute-force-first discipline**
```python
def two_sum_brute(nums: list, target: int) -> tuple:
    # Always state this first: O(n²) time, O(1) space
    for i in range(len(nums)):
        for j in range(i + 1, len(nums)):
            if nums[i] + nums[j] == target:
                return (i, j)
    return (-1, -1)

# Then say: "I can do better — hash map gives O(n) time, O(n) space"
def two_sum_optimal(nums: list, target: int) -> tuple:
    seen = {}
    for i, num in enumerate(nums):
        complement = target - num
        if complement in seen:
            return (seen[complement], i)
        seen[num] = i
    return (-1, -1)
```

**What to say when stuck**
```python
# DO say:
# "Let me restate what I know: I have a sorted array and need to find..."
# "Let me try a small example — if nums = [1,2,3], target = 4..."
# "I'm thinking about using a hash map to trade space for time..."
# "I know the brute force is O(n²) — I'm looking for a way to eliminate the inner loop..."
# "I don't know the optimal solution yet, but let me start with brute force
#  and see if the structure suggests an improvement..."

# DON'T:
# Go silent for more than 30 seconds
# Start coding before you have an approach
# Say "I don't know" and stop — always have a next step
# Skip to the "clever" solution without stating brute force first
```

---

## Gotchas

- **Jumping to code is the most common mistake.** Interviewers have seen hundreds of candidates. The ones who spend 5 minutes talking before writing signal they think before they act. Start coding immediately and you signal the opposite.
- **Misreading a constraint invalidates your entire solution.** "Find a subarray" (contiguous) vs "find a subsequence" (non-contiguous) requires completely different algorithms. Read the problem again after forming your approach.
- **Stating complexity is not optional.** Every solution should be followed by "this runs in O(n log n) time and O(n) space." If you don't know the complexity, you don't understand the solution.
- **Interviewers expect bugs.** The difference between junior and senior is not zero bugs — it's catching your own bugs before being told about them. Always trace through your code after writing it.
- **"Let me know if I'm going in the wrong direction" is a power move.** It invites the interviewer to course-correct without you wasting 10 minutes on a dead end. Treat the interviewer as a collaborator, not an oracle to impress.

---

## Interview Angle

**What they're really testing:** Communication, problem decomposition, and self-correction — not just whether you memorized the right algorithm.

**Common question form:** Every algorithm problem in existence. The framework applies universally.

**The depth signal:** A junior hears the problem and starts coding. A senior restates the problem, confirms constraints, works an example, states brute force with complexity, identifies an optimization, agrees on the approach, then codes — and narrates throughout. The senior asks exactly one clarifying question per assumption, not twenty. The real separator is handling the "can you optimize this?" follow-up: a senior already knows the current solution's complexity and has a candidate optimization in mind before the question is asked.

---

## Related Topics

- [[algorithms/common-patterns-map.md]] — The pattern recognition map this process depends on.
- [[algorithms/complexity-analysis.md]] — Required for stating complexity in Phase 3 and Phase 6.
- [[algorithms/big-o-notation.md]] — The notation used when communicating complexity to interviewers.

---

## Source

https://leetcode.com/explore/interview/card/leetcodes-interview-crash-course-data-structures-and-algorithms/

---

*Last updated: 2026-03-24*