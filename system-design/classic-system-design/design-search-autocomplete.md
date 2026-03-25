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

```csharp
// Trie node with top-K completions stored at each node
using System;
using System.Collections.Generic;
using System.Linq;

public class TrieNode
{
    public Dictionary<char, TrieNode> Children { get; set; } = new();
    public List<(int Score, string Word)> TopCompletions { get; set; } = new();
}

public class AutocompleteTrie
{
    private readonly TrieNode _root;
    private readonly int _k;

    public AutocompleteTrie(int k = 5)
    {
        _root = new TrieNode();
        _k = k;
    }

    public void Insert(string word, int score)
    {
        var node = _root;
        foreach (var ch in word)
        {
            if (!node.Children.ContainsKey(ch))
                node.Children[ch] = new TrieNode();
            node = node.Children[ch];

            // Maintain top-K completions at this node (min-heap simulation via List)
            node.TopCompletions.Add((score, word));
            node.TopCompletions = node.TopCompletions.OrderByDescending(x => x.Score).Take(_k).ToList();
        }
    }

    public List<string> Search(string prefix)
    {
        var node = _root;
        foreach (var ch in prefix)
        {
            if (!node.Children.ContainsKey(ch))
                return new List<string>();
            node = node.Children[ch];
        }

        // Return sorted descending by score
        return node.TopCompletions.OrderByDescending(x => x.Score)
            .Select(x => x.Word).ToList();
    }
}

// Usage
var trie = new AutocompleteTrie(k: 3);
trie.Insert("apple", 100);
trie.Insert("application", 80);
trie.Insert("apply", 60);
trie.Insert("apt", 40);
trie.Insert("banana", 90);

Console.WriteLine(string.Join(", ", trie.Search("app")));   // → apple, application, apply
Console.WriteLine(string.Join(", ", trie.Search("ban")));   // → banana
Console.WriteLine(string.Join(", ", trie.Search("xyz")));   // → (empty)
```

```csharp
// Redis sorted set approach — easier incremental updates than trie
// Each prefix maps to a sorted set of (score, completion) pairs

using StackExchange.Redis;

var redis = ConnectionMultiplexer.Connect("localhost:6379");
var db = redis.GetDatabase();

void IndexQuery(string query, int score)
{
    // Index all prefixes of a query with its score
    for (int i = 1; i <= query.Length; i++)
    {
        var prefix = query.Substring(0, i);
        db.SortedSetAdd($"autocomplete:{prefix}", query, score);
    }
}

List<string> GetSuggestions(string prefix, int k = 5)
{
    // Fetch top-K completions for a prefix, sorted by score desc
    var results = db.SortedSetRangeByRankWithScores($"autocomplete:{prefix}", 0, k - 1, Order.Descending);
    return results.Select(x => x.Element.ToString()).ToList();
}

// Index some queries
IndexQuery("apple", 100);
IndexQuery("application", 80);
IndexQuery("apply", 60);

Console.WriteLine(string.Join(", ", GetSuggestions("app")));   // → apple, application, apply
```

```csharp
// Query log aggregation — offline job to update scores
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

public List<(string Query, int Count)> AggregateQueryLogs(string logFile)
{
    // Read raw query logs, count frequency, return sorted list.
    // This runs as a batch job (e.g., Spark, daily cron).
    var counts = new Dictionary<string, int>();
    
    foreach (var line in File.ReadLines(logFile))
    {
        var entry = JsonSerializer.Deserialize<Dictionary<string, object>>(line);
        var query = entry["query"].ToString().ToLower().Trim();
        
        if (counts.ContainsKey(query))
            counts[query]++;
        else
            counts[query] = 1;
    }
    
    return counts.OrderByDescending(x => x.Value).Select(x => (x.Key, x.Value)).ToList();
}
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