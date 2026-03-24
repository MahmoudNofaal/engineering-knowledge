# Search Autocomplete

> A system that returns ranked completion suggestions for a search query prefix in real time as the user types.

---

## When To Use It

Build a dedicated autocomplete system when you have a large query corpus and need sub-100ms suggestions at high QPS. Don't build this for small datasets — a simple DB LIKE query works fine at small scale. The design challenge is serving prefix lookups across millions of possible completions faster than a user can type, while keeping suggestions ranked by popularity and freshness.

---

## Core Concept

The core data structure is a **trie** (prefix tree): each node represents a character, and every path from root to a node represents a prefix. You store the top-K completions at each node so you never have to traverse the entire subtree at query time. The trie is pre-built offline from query logs (aggregated and ranked by frequency). At query time, you walk the trie to the node matching the input prefix and return the stored top-K results — no traversal needed. In production, you don't store this trie in a DB: you serialize it and load it into memory (or use Redis sorted sets as an approximation that's easier to update incrementally).

---

## The Code

```python
# Trie node with top-K completions stored at each node
from collections import defaultdict
import heapq

class TrieNode:
    def __init__(self):
        self.children: dict[str, "TrieNode"] = {}
        self.top_completions: list[tuple[int, str]] = []  # (score, word)

class AutocompleteTrie:
    def __init__(self, k: int = 5):
        self.root = TrieNode()
        self.k = k  # Store top-K at every node

    def insert(self, word: str, score: int):
        """Insert a word with its popularity score."""
        node = self.root
        for char in word:
            if char not in node.children:
                node.children[char] = TrieNode()
            node = node.children[char]

            # Maintain top-K completions at this node (min-heap)
            heapq.heappush(node.top_completions, (score, word))
            if len(node.top_completions) > self.k:
                heapq.heappop(node.top_completions)

    def search(self, prefix: str) -> list[str]:
        """Return top-K completions for the given prefix."""
        node = self.root
        for char in prefix:
            if char not in node.children:
                return []  # No completions exist
            node = node.children[char]

        # Return sorted descending by score
        results = sorted(node.top_completions, reverse=True)
        return [word for score, word in results]

# Usage
trie = AutocompleteTrie(k=3)
trie.insert("apple", 100)
trie.insert("application", 80)
trie.insert("apply", 60)
trie.insert("apt", 40)
trie.insert("banana", 90)

print(trie.search("app"))   # → ['apple', 'application', 'apply']
print(trie.search("ban"))   # → ['banana']
print(trie.search("xyz"))   # → []
```

```python
# Redis sorted set approach — easier incremental updates than trie
# Each prefix maps to a sorted set of (score, completion) pairs

import redis

r = redis.Redis(host='localhost', port=6379, db=0)

def index_query(query: str, score: int):
    """Index all prefixes of a query with its score."""
    for i in range(1, len(query) + 1):
        prefix = query[:i]
        r.zadd(f"autocomplete:{prefix}", {query: score})

def get_suggestions(prefix: str, k: int = 5) -> list[str]:
    """Fetch top-K completions for a prefix, sorted by score desc."""
    results = r.zrevrange(f"autocomplete:{prefix}", 0, k - 1)
    return [r.decode() for r in results]

# Index some queries
index_query("apple", 100)
index_query("application", 80)
index_query("apply", 60)

print(get_suggestions("app"))   # → ['apple', 'application', 'apply']
```

```python
# Query log aggregation — offline job to update scores
from collections import Counter
import json

def aggregate_query_logs(log_file: str) -> list[tuple[str, int]]:
    """
    Read raw query logs, count frequency, return sorted list.
    This runs as a batch job (e.g., Spark, daily cron).
    """
    counts = Counter()
    with open(log_file) as f:
        for line in f:
            entry = json.loads(line)
            query = entry["query"].lower().strip()
            counts[query] += 1
    return counts.most_common()
```

---

## Gotchas

- **Top-K at each node must be pre-computed**: If you walk the trie to a prefix node and then DFS the subtree to find top completions at query time, you've made the lookup O(subtree size) — completely defeats the purpose. Store top-K at every node during build time.
- **Trie rebuild vs incremental update**: A full trie rebuild from query logs is slow (minutes). If you need near-real-time ranking updates (trending searches), use Redis sorted sets for incremental updates and rebuild the trie nightly for serving.
- **Typo tolerance requires a different data structure**: A trie returns nothing for "appel" (misspelled "apple"). If you need fuzzy matching, you need a different approach: BK-tree, edit distance search, or a search engine like Elasticsearch with fuzziness enabled.
- **Character set matters**: A trie built on ASCII breaks on Unicode queries. Decide upfront whether you're operating on characters or tokens, and normalize inputs (lowercase, strip punctuation) consistently at both index and query time.
- **CDN caching for popular prefixes**: The top 1000 most-typed prefixes (single characters, two-character combinations) account for a huge percentage of autocomplete traffic. Cache responses for short prefixes at the CDN edge to drastically reduce backend load.

---

## Interview Angle

**What they're really testing:** Trie data structure, read optimization, and the offline/online pipeline split.

**Common question form:** "Design a search autocomplete system for Google Search that needs to return top 5 suggestions in under 100ms."

**The depth signal:** A junior answer describes a DB `LIKE 'prefix%'` query with an index. A senior answer introduces the trie, explains why top-K must be stored at each node (not computed at query time), discusses the offline aggregation pipeline for computing scores vs the online serving path, addresses how to handle updates without a full rebuild (Redis sorted sets as a live layer on top of a static trie snapshot), and notes that single-character and two-character prefixes get CDN-cached because they're hot enough to warrant it.

---

## Related Topics

- [[system-design/design-distributed-cache]] — Autocomplete completions for hot prefixes must be cached in-memory
- [[algorithms/trie]] — The core data structure powering prefix search
- [[system-design/design-url-shortener]] — Contrast: URL shortener optimizes for exact-key lookup; autocomplete optimizes for prefix scan

---

## Source

[System Design Interview – An Insider's Guide, Chapter 13 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*