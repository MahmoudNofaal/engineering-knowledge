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
```csharp
public class TrieNode
{
    public Dictionary<char, TrieNode> Children { get; set; } = new();
    public bool IsEnd { get; set; } = false;  // marks a complete word
}

public class Trie
{
    private readonly TrieNode _root = new();

    public void Insert(string word)  // O(L)
    {
        var node = _root;
        foreach (char ch in word)
        {
            if (!node.Children.ContainsKey(ch))
                node.Children[ch] = new TrieNode();
            node = node.Children[ch];
        }
        node.IsEnd = true;
    }

    public bool Search(string word)  // O(L)
    {
        var node = _root;
        foreach (char ch in word)
        {
            if (!node.Children.ContainsKey(ch))
                return false;
            node = node.Children[ch];
        }
        return node.IsEnd;  // must land on a complete word
    }

    public bool StartsWith(string prefix)  // O(L)
    {
        var node = _root;
        foreach (char ch in prefix)
        {
            if (!node.Children.ContainsKey(ch))
                return false;
            node = node.Children[ch];
        }
        return true;  // any node reached is a valid prefix
    }
}
```

**Autocomplete — collect all words with a given prefix**
```csharp
public List<string> Autocomplete(string prefix)
{
    var node = _root;
    foreach (char ch in prefix)
    {
        if (!node.Children.ContainsKey(ch))
            return new List<string>();
        node = node.Children[ch];
    }
    // DFS from the prefix endpoint to collect all completions
    var results = new List<string>();
    Dfs(node, prefix, results);
    return results;
}

private void Dfs(TrieNode node, string path, List<string> results)
{
    if (node.IsEnd)
        results.Add(path);
    foreach (var kvp in node.Children)
    {
        Dfs(kvp.Value, path + kvp.Key, results);
    }
}
```

**Word search in a grid using trie pruning — O(m × n × 4^L)**
```csharp
public List<string> FindWords(char[][] board, string[] words)
{
    var trie = new Trie();
    foreach (string word in words)
        trie.Insert(word);

    int rows = board.Length, cols = board[0].Length;
    var found = new HashSet<string>();

    void Dfs(TrieNode node, int r, int c, string path)
    {
        char ch = board[r][c];
        if (!node.Children.ContainsKey(ch))
            return;   // prune — no words start with this path
        node = node.Children[ch];
        path += ch;
        if (node.IsEnd)
            found.Add(path);
        board[r][c] = '#';    // mark visited
        foreach (var (dr, dc) in new[] { (-1, 0), (1, 0), (0, -1), (0, 1) })
        {
            int nr = r + dr, nc = c + dc;
            if (0 <= nr && nr < rows && 0 <= nc && nc < cols && board[nr][nc] != '#')
                Dfs(node, nr, nc, path);
        }
        board[r][c] = ch;     // restore
    }

    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            Dfs(trie._root, r, c, "");
    return found.ToList();
}
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