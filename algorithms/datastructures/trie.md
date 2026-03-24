# Trie
> A tree where each path from root to node spells out a prefix, built for fast prefix-based string lookup.

---

## When To Use It
Use a trie when you need to search, insert, or autocomplete strings by prefix. Classic cases: autocomplete, spell checkers, IP routing tables, word games. Avoid it when your keys aren't strings or when memory is tight — a trie storing n words of average length L uses O(n × L) space, and each node is a dict or array, which is heavier than a flat hash map.

---

## Core Concept
A trie stores strings character by character, sharing prefixes. "cat" and "car" share the path c → a before diverging. This means searching for a prefix is O(L) where L is the prefix length — completely independent of how many words are stored. Each node has up to 26 children (for lowercase English), and a boolean flag marking whether that node completes a valid word. Insertion and lookup are both O(L) — just walk the characters one by one.

---

## The Code

**Trie implementation**
```python
class TrieNode:
    def __init__(self):
        self.children = {}   # char → TrieNode
        self.is_end = False  # marks a complete word

class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word: str) -> None:  # O(L)
        node = self.root
        for ch in word:
            if ch not in node.children:
                node.children[ch] = TrieNode()
            node = node.children[ch]
        node.is_end = True

    def search(self, word: str) -> bool:  # O(L)
        node = self.root
        for ch in word:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return node.is_end  # must land on a complete word

    def starts_with(self, prefix: str) -> bool:  # O(L)
        node = self.root
        for ch in prefix:
            if ch not in node.children:
                return False
            node = node.children[ch]
        return True  # any node reached is a valid prefix
```

**Autocomplete — collect all words with a given prefix**
```python
def autocomplete(self, prefix: str) -> list:
    node = self.root
    for ch in prefix:
        if ch not in node.children:
            return []
        node = node.children[ch]
    # DFS from the prefix endpoint to collect all completions
    results = []
    self._dfs(node, prefix, results)
    return results

def _dfs(self, node: TrieNode, path: str, results: list) -> None:
    if node.is_end:
        results.append(path)
    for ch, child in node.children.items():
        self._dfs(child, path + ch, results)
```

**Word search in a grid using trie pruning — O(m × n × 4^L)**
```python
def find_words(board: list, words: list) -> list:
    trie = Trie()
    for word in words:
        trie.insert(word)

    rows, cols = len(board), len(board[0])
    found = set()

    def dfs(node, r, c, path):
        ch = board[r][c]
        if ch not in node.children:
            return           # prune — no words start with this path
        node = node.children[ch]
        path += ch
        if node.is_end:
            found.add(path)
        board[r][c] = '#'    # mark visited
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and board[nr][nc] != '#':
                dfs(node, nr, nc, path)
        board[r][c] = ch     # restore

    for r in range(rows):
        for c in range(cols):
            dfs(trie.root, r, c, "")
    return list(found)
```

---

## Gotchas

- **`search` and `starts_with` have different terminal conditions.** `search` requires `is_end = True` at the last character. `starts_with` returns True as long as you can walk the full prefix without falling off — `is_end` is irrelevant.
- **Memory usage is high.** Each node stores a dict or a 26-element array. For sparse datasets, a hash map of full strings may be more memory-efficient than a trie despite worse prefix-search performance.
- **Deletion is tricky.** You must walk back up and remove nodes that are no longer on any word's path. Most interview problems avoid deletion — but know it's non-trivial.
- **A trie can replace a hash set for string lookups, but only when prefix queries are needed.** If you only ever do exact match, a hash set is simpler and uses less memory.
- **The array-based trie (26-element array per node) is faster than dict-based but wastes memory for sparse alphabets.** Use dict-based nodes unless performance is critical and the character set is small and known.

---

## Interview Angle

**What they're really testing:** Whether you recognize prefix-search problems as trie problems and can implement insert/search cleanly.

**Common question form:** Implement a trie, word search II, autocomplete system, replace words with their shortest prefix.

**The depth signal:** A junior implements a trie but conflates `search` and `starts_with`. A senior distinguishes them clearly, knows the memory trade-off vs a hash set, and sees that trie-based pruning in grid search is what turns a TLE solution into an accepted one — the trie kills branches early rather than letting DFS explore paths that can't form any valid word.

---

## Related Topics

- [[algorithms/tree.md]] — A trie is a tree — the same recursive DFS patterns apply.
- [[algorithms/hash-table.md]] — The flat alternative to a trie; simpler but no prefix support.
- [[algorithms/graph.md]] — Word search in a grid is a graph DFS problem that benefits from trie pruning.

---

## Source

https://en.wikipedia.org/wiki/Trie

---

*Last updated: 2026-03-24*