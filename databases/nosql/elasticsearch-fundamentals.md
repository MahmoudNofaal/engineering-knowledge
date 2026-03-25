# Elasticsearch Fundamentals

> A distributed search and analytics engine built on Apache Lucene that indexes documents as JSON, makes them searchable in near real-time, and scales horizontally across nodes — purpose-built for full-text search, log analytics, and observability workloads.

---

## When To Use It

Use Elasticsearch when you need sub-second full-text search across millions of documents with typo tolerance, relevance ranking, faceted filtering, and autocomplete — things Postgres FTS and MongoDB text indexes can't do at scale or quality. Also the default choice for log aggregation and observability (the ELK stack). Don't use it as a primary database — it has no transactions, eventual consistency on writes, and historically lossy behavior during network partitions. The standard pattern is Postgres or MongoDB as the source of truth, Elasticsearch as the search layer synced via events or CDC.

---

## Core Concept

Elasticsearch stores documents in an index. Each index is split into shards — independent Lucene instances — that are distributed across nodes. Each shard has replica shards on other nodes for redundancy. When you search, the request fans out to all shards in parallel, each returns its top N hits, and the coordinating node merges and re-ranks them. The core data structure is an inverted index: for each term in the corpus, a list of which documents contain it and where. This is why full-text search is fast — looking up a term is O(1), not a scan. Relevance is scored using BM25 by default — a function of term frequency in the document and inverse document frequency across the corpus.

---

## The Code

**Index setup — mappings define field types**
```csharp
using Nest;

var connectionSettings = new ConnectionSettings(new Uri("http://localhost:9200"));
var client = new ElasticClient(connectionSettings);

// Mappings are like a schema — define before indexing
// Wrong field types cause silent mis-indexing
var createIndexResponse = client.Indices.Create("articles", c => c
    .Settings(s => s
        .NumberOfShards(2)      // more shards = more parallelism, more overhead
        .NumberOfReplicas(1)    // replicas for redundancy, not speed on writes
        .Analysis(a => a
            .Analyzers(aa => aa
                .Standard("english_analyzer", sa => sa
                    .StopwordsPath("_english_")
                )
            )
        )
    )
    .Map(m => m
        .Properties(p => p
            .Text(t => t.Name("title").Analyzer("english_analyzer"))
            .Text(t => t.Name("body").Analyzer("english_analyzer"))
            .Keyword(k => k.Name("author"))  // exact match, not analyzed
            .Keyword(k => k.Name("tags"))    // array of exact-match strings
            .Date(d => d.Name("published"))
            .Integer(i => i.Name("view_count"))
            .Completion(c => c.Name("title_suggest").Analyzer("simple"))  // for autocomplete
        )
    )
);
```

**Indexing documents**
```csharp
// Single document
var response = client.IndexDocument(new
{
    title = "PostgreSQL Full-Text Search",
    body = "Postgres has built-in FTS using tsvector...",
    author = "ali",
    tags = new[] { "postgres", "databases", "search" },
    published = new DateTime(2026, 1, 15),
    view_count = 1240,
    title_suggest = new[] { "PostgreSQL Full-Text Search", "Postgres FTS" }
});

// Bulk indexing — always use bulk for more than a few documents
var bulkRequest = new BulkDescriptor();
foreach (var doc in documents)
{
    bulkRequest.Index<Document>(i => i
        .Index("articles")
        .Id(doc.Id)
        .Document(doc)
    );
}
var bulkResponse = client.Bulk(b => bulkRequest);
```

**Full-text search — match query**
```csharp
// Basic full-text search — analyzed, stemmed, scored
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .Query(q => q
        .Match(m => m
            .Field("title")
            .Query("postgres indexing")
            .Operator(Operator.And)  // both terms must appear; default is Or
        )
    )
);

// Multi-field search with boosting
var result2 = client.Search<dynamic>(s => s
    .Index("articles")
    .Query(q => q
        .MultiMatch(mm => mm
            .Query("postgres indexing")
            .Fields(f => f
                .Field("title", 3)  // title match worth 3x body match
                .Field("body")
            )
            .Type(TextQueryType.BestFields)  // score = best single field match
        )
    )
);

// Access hits
foreach (var hit in result.Hits)
{
    Console.WriteLine($"{hit.Score}: {hit.Source}");
}
```

**Bool query — combine clauses**
```csharp
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .Query(q => q
        .Bool(b => b
            // must: must match, affects score
            .Must(m => m
                .Match(mt => mt
                    .Field("body")
                    .Query("distributed systems")
                )
            )
            // filter: must match, does NOT affect score, cached
            .Filter(f => f
                .Term(t => t.Field("author").Value("ali"))
                , f => f
                .Terms(t => t.Field("tags").Terms("databases", "search"))
                , f => f
                .DateRange(dr => dr.Field("published").GreaterThanOrEquals("2025-01-01"))
                , f => f
                .Range(r => r.Field("view_count").GreaterThanOrEquals(100))
            )
            // must_not: must not match
            .MustNot(mn => mn
                .Term(t => t.Field("tags").Value("draft"))
            )
            // should: nice to have, boosts score if present
            .Should(sh => sh
                .Match(mt => mt
                    .Field("title")
                    .Query("distributed systems")
                )
            )
            .MinimumShouldMatch(0)  // 0 = should is optional
        )
    )
);
```

**Aggregations — analytics over search results**
```csharp
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .Size(0)   // don't return documents, only aggregations
    .Query(q => q
        .DateRange(dr => dr
            .Field("published")
            .GreaterThanOrEquals("2025-01-01")
        )
    )
    .Aggregations(a => a
        // Terms aggregation — top N values
        .Terms("top_authors", t => t
            .Field("author")
            .Size(10)
        )
        // Date histogram — group by time bucket
        .DateHistogram("articles_per_month", dh => dh
            .Field("published")
            .CalendarInterval(DateInterval.Month)
        )
        // Nested aggregation — avg views per author
        .Terms("by_author", t => t
            .Field("author")
            .Aggregations(aa => aa
                .Average("avg_views", av => av.Field("view_count"))
            )
        )
        // Range aggregation — bucket by value ranges
        .Range("view_ranges", r => r
            .Field("view_count")
            .Ranges(
                (null, 100),
                (100, 1000),
                (1000, null)
            )
        )
    )
);

// Access aggregation results
var topAuthors = result.Aggregations.Terms("top_authors");
foreach (var bucket in topAuthors.Buckets)
{
    Console.WriteLine($"{bucket.Key}: {bucket.DocCount}");
}
```

**Fuzzy search and autocomplete**
```csharp
// Fuzzy — handles typos (fuzziness = max edit distance)
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .Query(q => q
        .Match(m => m
            .Field("title")
            .Query("postgress")  // typo
            .Fuzziness(Fuzziness.Auto)  // AUTO: 0 edits for 1-2 chars,
                                          //       1 edit for 3-5 chars,
                                          //       2 edits for 6+ chars
        )
    )
);

// Autocomplete using completion suggester
var result2 = client.Search<dynamic>(s => s
    .Index("articles")
    .Suggest(su => su
        .Completion("title_autocomplete", c => c
            .Field("title_suggest")
            .Prefix("postgr")
            .Size(5)
        )
    )
);
```

**Highlighting matched terms**
```csharp
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .Query(q => q
        .Match(m => m
            .Field("body")
            .Query("distributed systems")
        )
    )
    .Highlight(h => h
        .Fields(f => f
            .Field("body")
            .FragmentSize(150)                   // chars per snippet
            .NumberOfFragments(3)                // max snippets per doc
            .PreTags("<mark>")
            .PostTags("</mark>")
        )
    )
);

foreach (var hit in result.Hits)
{
    if (hit.Highlight.ContainsKey("body"))
    {
        foreach (var highlightedSnippet in hit.Highlight["body"])
        {
            Console.WriteLine(highlightedSnippet);
        }
    }
}
```

**Pagination — search_after over from/size**
```csharp
// from/size is fine for small offsets
var result = client.Search<dynamic>(s => s
    .Index("articles")
    .From(0).Size(10)
    .Query(q => q.MatchAll())
    .Sort(so => so
        .Descending("published")
        .Ascending("_id")
    )
);

// search_after for deep pagination — stateless, uses last hit's sort values
var lastHit = result.Hits.Last();
object[] sortValues = lastHit.Sorts.Cast<object>().ToArray();

var nextPage = client.Search<dynamic>(s => s
    .Index("articles")
    .Size(10)
    .Query(q => q.MatchAll())
    .Sort(so => so
        .Descending("published")
        .Ascending("_id")
    )
    .SearchAfter(sortValues)  // cursor-based — no memory overhead
);
```

---

## Gotchas

- **Mappings are immutable after indexing.** You can add new fields but you cannot change a field's type (e.g., `text` to `keyword`). Changing a type requires creating a new index with the correct mapping and reindexing all documents using the `_reindex` API. Plan your mapping before you put data in.
- **`keyword` vs `text` is the most common mapping mistake.** `text` fields are analyzed (tokenized, lowercased, stemmed) — good for full-text search, useless for exact match, sorting, or aggregations. `keyword` fields are stored as-is — good for filtering, sorting, aggregations, useless for full-text. For a field you need both for, use `fields` to index it twice: `{"type": "text", "fields": {"raw": {"type": "keyword"}}}`.
- **`from + size` pagination has a hard limit of 10,000 by default.** Requesting page 1001 of size 10 hits the `index.max_result_window` setting and throws. Use `search_after` for deep pagination or `scroll` API for bulk export.
- **Writes are near real-time, not immediate.** After indexing a document, it won't appear in search results until the next refresh (default: 1 second). Don't write a document and immediately query for it in the same test without calling `es.indices.refresh()` first.
- **Aggregations on `text` fields throw an error.** `terms` aggregation on a `text` field fails because analyzed fields don't have doc values. Run aggregations on `keyword` fields only — or the `.raw` sub-field if you mapped it.

---

## Interview Angle

**What they're really testing:** Whether you understand inverted indexes and relevance scoring, and can reason about when Elasticsearch is the right layer vs. the primary database.

**Common question form:** *"How would you implement search for an e-commerce site?"* or *"How does Elasticsearch score results?"* or *"How would you handle pagination at scale?"*

**The depth signal:** A junior says "use Elasticsearch for search because it's fast." A senior explains the inverted index structure (term → document list), why `keyword` vs `text` matters for aggregations and filtering, why `filter` clauses are cached and don't affect score while `must` clauses do, and why `from/size` pagination breaks at depth (the coordinating node must fetch `from + size` hits from every shard and merge them — at page 1000 that's 10,000 docs per shard). They also know Elasticsearch is not a source of truth — they'd keep Postgres as primary and sync to ES via CDC or an event-driven pipeline, and handle re-sync on mapping changes with `_reindex`.

---

## Related Topics

- [[databases/postgres-full-text-search.md]] — The Postgres-native alternative; knowing both lets you make the right call on when ES is actually needed.
- [[databases/mongodb-aggregation.md]] — MongoDB aggregation vs ES aggregations for analytics — ES wins on full-text, Mongo wins on document-native queries.
- [[databases/indexing-strategies.md]] — Inverted indexes in ES vs B-tree and GIN in Postgres — different structures, different query strengths.
- [[system-design/search-architecture.md]] — How to wire Elasticsearch into a production system: sync strategies, reindexing, and query routing.

---

## Source

[Elasticsearch documentation — getting started, mapping, query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)

---
*Last updated: 2026-03-24*