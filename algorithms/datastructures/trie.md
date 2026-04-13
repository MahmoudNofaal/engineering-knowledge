# Trie

> A tree where each path from root to node spells out a prefix, built for fast prefix-based string lookup.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Prefix tree — character-by-character string storage |
| **Use when** | Prefix search, autocomplete, spell checking |
| **Avoid when** | Memory is tight or keys aren't strings |
| **C# version** | C# 2.0+ (custom implementation) |
| **Namespace** | Custom implementation — no BCL trie |
| **Key types** | Custom `TrieNode`, `Dictionary<char, TrieNode>` children |

---

## When To Use It

Use a trie when you need to search, insert, or autocomplete strings by prefix. Classic cases: autocomplete systems, spell checkers, IP routing tables (CIDR prefix matching), and word games (Boggle, Scrabble solver). The key advantage is that searching for all words with a given prefix is O(L + k) — where L is the prefix length and k is the number of results — completely independent of how many total words are stored.

Avoid it when your keys aren't strings or prefix relationships don't matter. If you only need exact-match lookup, a `HashSet<string>` is simpler, faster in practice, and uses less memory. Also avoid it when memory is constrained — a trie storing n words of average length L uses O(n × L) nodes, and each node is a dictionary or array, which is heavier per element than a flat hash map entry.

---

## Core Concept

A trie stores strings character by character, sharing common prefixes. "cat" and "car" share the path `c → a` before diverging at `t` vs `r`. This sharing is what makes prefix queries efficient — you walk the shared path once, then fan out only from the divergence point.

Each node has up to 26 children (for lowercase ASCII) and a boolean flag marking whether that node completes a valid word. Insertion and exact lookup are both O(L) where L is the string length. The critical distinction: `Search` requires the end node to have `IsEnd = true`; `StartsWith` succeeds as long as you can walk the full prefix without falling off the tree — `IsEnd` is irrelevant.

The key decision in implementation is children storage: a 26-element `char[]` gives O(1) child lookup but wastes memory for sparse alphabets. A `Dictionary<char, TrieNode>` uses only as much memory as the actual children present but adds dictionary overhead per node. For interview code, use the dictionary — it handles any character set and is easier to read.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 1.0 | .NET 1.0 | Custom tries using `Hashtable` — non-generic, casting required |
| C# 2.0 | .NET 2.0 | `Dictionary<char, TrieNode>` becomes idiomatic — generic, type-safe |
| C# 8.0 | .NET Core 3.0 | `ReadOnlySpan<char>` allows zero-allocation prefix walks |
| C# 9.0 | .NET 5 | `record` types and `init` properties simplify node definitions |
| C# 12.0 | .NET 8 | Primary constructors further reduce node boilerplate |

*The .NET BCL has never shipped a trie implementation. Every production trie in C# is hand-written or pulled from a library.*

---

## Performance

| Operation | Complexity | Notes |
|---|---|---|
| Insert | O(L) | L = string length; one node per character |
| Search (exact) | O(L) | Walk characters; check `IsEnd` at final node |
| StartsWith (prefix) | O(L) | Walk characters; no `IsEnd` check needed |
| Autocomplete | O(L + k) | L to reach prefix, k to collect all completions |
| Space | O(n × L) | n = number of strings, L = average length |

**Allocation behaviour:** Each `TrieNode` is a separate heap-allocated object. For n words of average length L, you allocate up to n × L nodes (shared prefixes reduce this). Each node carries a dictionary (additional allocation) and a bool. A million-word dictionary with average 8-character words can consume hundreds of MB — profile before deploying a trie in memory-constrained environments.

**Benchmark notes:** For exact-match lookup, a `HashSet<string>` beats a trie on both speed and memory. The trie wins when prefix queries are needed. If your dataset is static (no insertions after construction), a compressed trie (Patricia trie / radix tree) collapses chains of single-child nodes and significantly reduces memory.

---

## The Code

**Full trie implementation**
```csharp
public class TrieNode
{
    public Dictionary<char, TrieNode> Children { get; } = new();
    public bool IsEnd { get; set; }
}

public class Trie
{
    private readonly TrieNode _root = new();

    public void Insert(string word)                        // O(L)
    {
        TrieNode node = _root;
        foreach (char ch in word)
        {
            if (!node.Children.TryGetValue(ch, out TrieNode? child))
            {
                child = new TrieNode();
                node.Children[ch] = child;
            }
            node = child;
        }
        node.IsEnd = true;
    }

    public bool Search(string word)                        // O(L)
    {
        TrieNode? node = Walk(word);
        return node != null && node.IsEnd;                 // must land on a complete word
    }

    public bool StartsWith(string prefix)                  // O(L)
    {
        return Walk(prefix) != null;                       // any node = valid prefix
    }

    private TrieNode? Walk(string s)
    {
        TrieNode node = _root;
        foreach (char ch in s)
        {
            if (!node.Children.TryGetValue(ch, out TrieNode? child))
                return null;
            node = child;
        }
        return node;
    }
}
```

**Autocomplete — collect all words with a given prefix**
```csharp
public List<string> Autocomplete(string prefix)
{
    TrieNode? node = Walk(prefix);
    if (node == null) return new List<string>();

    var results = new List<string>();
    Dfs(node, new System.Text.StringBuilder(prefix), results);
    return results;
}

private void Dfs(TrieNode node, System.Text.StringBuilder path, List<string> results)
{
    if (node.IsEnd)
        results.Add(path.ToString());

    foreach (var (ch, child) in node.Children)
    {
        path.Append(ch);
        Dfs(child, path, results);
        path.Length--;              // backtrack
    }
}
// Use StringBuilder with backtracking — avoids O(L) string allocation per path step
```

**Word search in a grid with trie pruning — O(m × n × 4^L)**
```csharp
public static List<string> FindWords(char[][] board, string[] words)
{
    var trie  = new Trie();
    foreach (string w in words) trie.Insert(w);

    int rows = board.Length, cols = board[0].Length;
    var found = new HashSet<string>();

    void Dfs(TrieNode node, int r, int c, System.Text.StringBuilder path)
    {
        char ch = board[r][c];
        if (!node.Children.TryGetValue(ch, out TrieNode? next)) return;  // prune
        path.Append(ch);
        if (next.IsEnd) found.Add(path.ToString());
        board[r][c] = '#';    // mark visited
        int[,] dirs = { { -1,0 }, { 1,0 }, { 0,-1 }, { 0,1 } };
        for (int d = 0; d < 4; d++)
        {
            int nr = r + dirs[d,0], nc = c + dirs[d,1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc] != '#')
                Dfs(next, nr, nc, path);
        }
        board[r][c] = ch;     // restore
        path.Length--;
    }

    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            Dfs(trie._root, r, c, new System.Text.StringBuilder());

    return new List<string>(found);
}
```

**What NOT to do — and the fix**
```csharp
// BAD: confusing Search and StartsWith — returns true for prefixes that aren't words
public bool SearchBad(string word)
{
    TrieNode node = _root;
    foreach (char ch in word)
    {
        if (!node.Children.TryGetValue(ch, out TrieNode? child)) return false;
        node = child;
    }
    return true;          // wrong: this is StartsWith, not Search
}

// GOOD: Search must check IsEnd at the final node
public bool SearchGood(string word)
{
    TrieNode? node = Walk(word);
    return node != null && node.IsEnd;    // IsEnd = true only at complete words
}
```

---

## Real World Example

A code editor needs to implement "IntelliSense-style" symbol autocomplete. When the user types a partial identifier, the editor must return all known symbols (variables, methods, classes) that begin with the typed prefix — in under 10 ms for a project with 50,000 symbols. A `HashSet<string>` would require scanning all 50,000 entries for every keystroke. A trie navigates to the prefix endpoint in O(L) and then DFS-collects completions — total work proportional to L plus the number of results, not the dictionary size.

```csharp
public class SymbolIndex
{
    private readonly Trie _trie = new();
    private readonly Dictionary<string, SymbolInfo> _metadata = new();

    public record SymbolInfo(string FullName, string Kind, string FilePath, int Line);

    public void Index(IEnumerable<SymbolInfo> symbols)
    {
        foreach (var sym in symbols)
        {
            _trie.Insert(sym.FullName);
            _metadata[sym.FullName] = sym;
        }
    }

    // Returns up to maxResults completions for the given prefix, sorted by name
    public List<SymbolInfo> Complete(string prefix, int maxResults = 20)
    {
        return _trie.Autocomplete(prefix)
            .OrderBy(name => name)
            .Take(maxResults)
            .Select(name => _metadata[name])
            .ToList();
    }

    // Exact lookup — still O(L) via the trie, no need to hash separately
    public SymbolInfo? Find(string name)
    {
        if (!_trie.Search(name)) return null;
        return _metadata.GetValueOrDefault(name);
    }
}
```

*The key insight is the separation of concerns: the trie handles all prefix-matching logic in O(L), while the metadata dictionary resolves full symbol details in O(1). Neither structure tries to do both jobs.*

---

## Common Misconceptions

**"`Search` and `StartsWith` are basically the same — just check if you can walk the characters"**
They differ at the final step. `StartsWith` returns true the moment you've successfully walked all characters in the prefix — the node you land on doesn't need `IsEnd`. `Search` requires `IsEnd = true` at that same node. This is the most common trie bug in interviews: the candidate implements `StartsWith` and calls it `Search`, accepting prefixes as valid complete words.

**"A trie is always more memory-efficient than a hash set for strings"**
The opposite is often true. A `HashSet<string>` stores each string once. A trie stores each character as a separate node object with a dictionary of children. For short strings with few shared prefixes, the trie uses significantly more memory. The trie's memory efficiency advantage only materialises when many strings share long common prefixes — like all words beginning with "inter" in a dictionary.

**"Tries only work for lowercase letters"**
A 26-element array implementation is limited to lowercase ASCII. A `Dictionary<char, TrieNode>` children implementation works for any character set — Unicode, URLs, DNA sequences (ACGT), IP address octets. The dictionary approach is universally applicable; the array approach is an optimisation for a specific alphabet.

---

## Gotchas

- **`Search` requires `IsEnd = true`; `StartsWith` does not.** This is the most common trie bug — treat it as a constant reminder rather than obvious knowledge.

- **Use `StringBuilder` with backtracking in autocomplete DFS, not string concatenation.** Each `path + ch` in a loop creates a new string — O(L) allocation per step, O(L²) total. `StringBuilder.Append` + `path.Length--` is O(1) per step with O(L) total allocation.

- **Deletion is non-trivial.** To delete a word, you must walk to the end node, clear `IsEnd`, then walk back up removing nodes that are no longer on any word's path. Most interview problems avoid deletion — but know it's not a simple operation.

- **Memory use is proportional to total characters, not unique words.** A trie of 1,000 words averaging 10 characters stores up to 10,000 nodes — before accounting for shared prefixes. Always benchmark memory when storing large vocabularies.

- **Word Search II (grid + trie) requires an optimisation: prune `IsEnd` after finding a word.** Without this, the same word is added to results repeatedly via different paths in the grid. Set `node.IsEnd = false` after collecting a word to prevent duplicates without a visited set.

---

## Interview Angle

**What they're really testing:** Whether you recognise prefix-search problems as trie problems, can implement insert/search/startsWith cleanly, and know the subtle `IsEnd` distinction.

**Common question forms:**
- "Implement a Trie with insert, search, and startsWith"
- "Word search II — find all words from a list in a grid"
- "Replace words — replace each word in a sentence with its shortest root from a dictionary"
- "Design a search autocomplete system"

**The depth signal:** A junior implements a trie but conflates `Search` and `StartsWith` (returns true for prefixes). A senior distinguishes them clearly, knows that trie pruning in Word Search II is what turns a TLE solution into an accepted one (the trie kills branches early rather than letting DFS explore paths that can't form any valid word), and is aware of the memory trade-off vs a hash set. The elite signal is knowing when to use a compressed trie / radix tree for memory efficiency and when `StringBuilder` backtracking is necessary to avoid O(L²) allocation.

**Follow-up questions to expect:**
- "How would you handle deletion?" (Walk to end, clear `IsEnd`, walk back up removing leaf nodes)
- "What if the alphabet is Unicode?" (Use `Dictionary<char, TrieNode>` instead of a 26-element array)
- "How would you make autocomplete return results sorted by frequency?" (Store a hit count per node, or rank the collected completions by a separate frequency map)

---

## Related Topics

- [[algorithms/datastructures/tree.md]] — A trie is a tree — the same recursive DFS patterns apply for traversal and collection.
- [[algorithms/datastructures/hash-table.md]] — The flat alternative: O(1) exact lookup, O(n) prefix search. Simpler but no prefix support.
- [[algorithms/datastructures/graph.md]] — Word search in a grid is a graph DFS problem that benefits from trie pruning.

---

## Source

https://en.wikipedia.org/wiki/Trie

---

*Last updated: 2026-04-12*