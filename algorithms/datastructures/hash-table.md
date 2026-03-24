# Hash Table
> A data structure that maps keys to values using a hash function, giving O(1) average-case lookup, insert, and delete.

---

## When To Use It
Use a hash table any time you need to look up, count, or deduplicate by a key in O(1). It's the single most common structure for trading space for time. Avoid it when you need sorted order, range queries, or worst-case O(1) guarantees — hash tables are average-case, and a sorted structure like a BST gives O(log n) with ordering support.

---

## Core Concept
A hash function takes a key and maps it to an index in an array. Ideally each key maps to a unique slot, giving O(1) access. In practice, two keys can hash to the same slot — a collision. The two standard fixes: chaining (each slot holds a linked list of colliding entries) and open addressing (probe for the next empty slot). Python's `dict` uses open addressing with pseudo-random probing. The hash table degrades to O(n) when collisions pile up, but a good hash function and a load factor limit (typically 0.75) keep this rare.

---

## The Code

**Python dict — the standard hash table**
```python
freq = {}
items = ['a', 'b', 'a', 'c', 'b', 'a']

for item in items:
    freq[item] = freq.get(item, 0) + 1  # O(1) average per operation

print(freq)  # {'a': 3, 'b': 2, 'c': 1}
```

**Two-sum — O(n) with a hash map**
```python
def two_sum(nums: list, target: int) -> tuple:
    seen = {}  # value → index
    for i, num in enumerate(nums):
        complement = target - num
        if complement in seen:
            return (seen[complement], i)
        seen[num] = i
    return (-1, -1)
```

**Frequency count and deduplication**
```python
from collections import Counter, defaultdict

# Count frequencies
counter = Counter(['a', 'b', 'a', 'c'])
print(counter.most_common(2))  # [('a', 2), ('b', 1)]

# Group items by key
groups = defaultdict(list)
for word in ['cat', 'car', 'bat', 'can']:
    groups[word[0]].append(word)
# {'c': ['cat', 'car', 'can'], 'b': ['bat']}
```

**Implementing a basic hash table from scratch**
```python
class HashTable:
    def __init__(self, size: int = 16):
        self.buckets = [[] for _ in range(size)]

    def _hash(self, key: str) -> int:
        return hash(key) % len(self.buckets)

    def put(self, key: str, value) -> None:
        bucket = self.buckets[self._hash(key)]
        for i, (k, v) in enumerate(bucket):
            if k == key:
                bucket[i] = (key, value)  # update existing
                return
        bucket.append((key, value))  # new entry via chaining

    def get(self, key: str):
        bucket = self.buckets[self._hash(key)]
        for k, v in bucket:
            if k == key:
                return v
        return None
```

---

## Gotchas

- **O(1) is average-case, not worst-case.** A deliberately crafted input that causes all keys to collide degrades to O(n). Python randomizes its hash seed at startup specifically to prevent algorithmic complexity attacks.
- **Mutable objects cannot be dictionary keys in Python.** Lists, sets, and dicts are unhashable. Use tuples. This trips people up when trying to use a list as a key for memoization.
- **Insertion order is preserved in Python 3.7+ dicts.** This is a language guarantee, not an implementation detail. But it does not make a dict a sorted structure — insertion order ≠ key order.
- **Load factor determines when rehashing occurs.** When the table is too full, every key must be rehashed into a larger array. This is O(n) and happens silently. Python manages this automatically, but it means that occasional insertions cost more than O(1).
- **`defaultdict` and `Counter` solve 80% of hash table interview sub-problems.** Knowing these exist and reaching for them signals fluency. Reimplementing them from scratch in an interview wastes time.

---

## Interview Angle

**What they're really testing:** Whether you instinctively reach for a hash map to convert a nested loop into a single pass.

**Common question form:** Two-sum, group anagrams, longest substring without repeating characters, find duplicate, subarray sum equals k.

**The depth signal:** A junior uses a nested loop and gets O(n²). A senior immediately asks "can I use a hash map?" and restructures to a single pass. The next level up: a senior can explain what happens under the hood — hash function, collision resolution, load factor — and knows why Python dicts use open addressing instead of chaining (better cache locality).

---

## Related Topics

- [[algorithms/array.md]] — Hash maps are commonly used alongside arrays to avoid O(n) lookups inside loops.
- [[algorithms/linked-list.md]] — Chaining uses linked lists at each bucket to resolve collisions.
- [[algorithms/balanced-bst.md]] — When you need sorted keys or range queries, a BST beats a hash table despite worse Big-O.

---

## Source

https://docs.python.org/3/library/stdtypes.html#mapping-types-dict

---

*Last updated: 2026-03-24*