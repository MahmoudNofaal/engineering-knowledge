# Elasticsearch Queries

> The complete query DSL reference — every query type you'll actually use in production, how scoring works, and how to combine clauses to express any search requirement precisely.

---

## When To Use It

Use this when you know Elasticsearch is your search layer and need to express a specific search requirement: filtered keyword search, fuzzy matching, phrase proximity, boosted fields, nested object queries, or combining multiple signals into a single relevance score. The wrong query type doesn't just return bad results — it silently skips indexes, scores incorrectly, or times out under load.

---

## Core Concept

Every query in Elasticsearch is either a leaf query (matches against a field) or a compound query (combines other queries). The other axis is query context vs filter context. Queries in query context compute a `_score` — how well the document matches. Queries in filter context are binary yes/no — they don't score, they use a bitset cache, and they're dramatically faster. The rule: anything that affects relevance ranking goes in `must` or `should`. Anything that's a hard constraint goes in `filter` or `must_not`. Mixing these up either slows your queries (scoring when you don't need to) or corrupts your ranking (filtering when you should be scoring).

---

## The Code

**The Bool query — the backbone of everything**
```csharp
using Elasticsearch.Net;
using Nest;

var client = new ElasticClient(new ConnectionSettings(
    new Uri("http://localhost:9200")
));

// Bool is how you compose all other queries
// Each clause type has different scoring and caching behavior
var result = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Bool(b => b
        .Must()      // must match + contributes to score
        .Filter()    // must match + NO score + cached (fast)
        .Should()    // optional + boosts score if matches
        .MustNot()   // must not match + NO score + cached
    ))
);
```

**Leaf queries — text fields**
```csharp
// match: standard full-text, analyzed
// Use for: user-typed search input on text fields
var result = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Match(m => m
        .Field(f => f.Title)
        .Query("database indexing")
        .Operator(Operator.And)     // default is "or" — use "and" for precision
        .Fuzziness(Fuzziness.Auto)  // optional typo tolerance
    ))
);

// match_phrase: terms must appear in order, adjacent
// Use for: exact phrase search
var phraseResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.MatchPhrase(mp => mp
        .Field(f => f.Body)
        .Query("inverted index")
        .Slop(2)  // allow 2 words between terms and still match
    ))
);

// match_phrase_prefix: last term is a prefix — autocomplete on body text
// Use for: search-as-you-type on text fields (completion suggester is better for titles)
var prefixResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.MatchPhrasePrefix(mpp => mpp
        .Field(f => f.Title)
        .Query("elasticsearch qu")
        .MaxExpansions(20)  // limit how many prefix variations to try
    ))
);

// multi_match: same query across multiple fields
// type controls how scores from multiple fields are combined
var multiResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.MultiMatch(mm => mm
        .Query("sharding replication")
        .Fields(f => f
            .Field(f => f.Title, boost: 3)
            .Field(f => f.Body)
            .Field(f => f.Tags, boost: 2)
        )
        .Type(TextQueryType.BestFields)  // score = best single field
        // TextQueryType.MostFields      — sum all field scores (rewards multiple field matches)
        // TextQueryType.CrossFields     — treat all fields as one big field (good for name search)
        // TextQueryType.Phrase          — match_phrase across fields
    ))
);
```

**Leaf queries — keyword/exact fields**
```csharp
// term: exact match on keyword field — case-sensitive
// Use for: filtering on IDs, statuses, enum values
var termResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Term(t => t
        .Field(f => f.Status)
        .Value("published")
    ))
);

// terms: match any value in a list
var termsResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Terms(t => t
        .Field(f => f.Author)
        .Terms(new[] { "ali", "sara", "john" })
    ))
);

// range: numeric, date, keyword ranges
var rangeResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Range(r => r
        .Field(f => f.Published)
        .GreaterThanOrEquals("2025-01-01")
        .LessThanOrEquals("2025-12-31")
    ))
);

// exists: field is present and not null
var existsResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Exists(e => e.Field(f => f.ThumbnailUrl)))
);

// ids: fetch specific documents by ID — faster than term query on _id
var idsResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Ids(i => i.Values(new[] { "1", "2", "3" })))
);
```

**Fuzzy and wildcard**
```csharp
// fuzzy: handles typos via edit distance
// Use for: single-term search where user input may be misspelled
var fuzzyResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Fuzzy(f => f
        .Field(f => f.Title)
        .Value("elasticsearh")  // typo
        .Fuzziness(Fuzziness.EditDistance(2))  // max edit distance
        .PrefixLength(2)  // first N chars must match exactly — prevents massive term expansion
    ))
);

// wildcard: pattern matching — expensive, avoid leading wildcards
// Use for: controlled internal queries, never raw user input
var wildcardResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Wildcard(w => w
        .Field(f => f.Author)
        .Value("a*")  // fine — no leading wildcard
        // .Value("*li")  // bad — scans entire term dictionary
    ))
);

// regexp: regex on keyword field — use sparingly
var regexResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Regexp(r => r
        .Field(f => f.Tags)
        .Value("data.*")
    ))
);
```

**Compound queries — combining and controlling scores**
```csharp
// Full production search query — the real pattern
var result = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Bool(b => b
        // Full-text relevance — scored
        .Must(m => m.MultiMatch(mm => mm
            .Query("database sharding")
            .Fields(f => f
                .Field(fa => fa.Title, boost: 3)
                .Field(fa => fa.Body)
            )
            .Type(TextQueryType.BestFields)
        ))
        // Hard constraints — not scored, cached
        .Filter(f => f.Term(t => t.Status, "published"))
        .Filter(f => f.DateRange(dr => dr
            .Field(fa => fa.Published)
            .GreaterThanOrEquals("2024-01-01")
        ))
        .Filter(f => f.Terms(t => t.Tags, new[] { "databases", "systems" }))
        // Soft signals — boost score but not required
        .Should(s => s.Term(t => t.IsFeatured, true))
        .Should(s => s.Range(r => r
            .Field(fa => fa.ViewCount)
            .GreaterThanOrEquals(1000)
        ))
        .MinimumShouldMatch(0)  // 0 = should clauses optional
        .MustNot(mn => mn.Term(t => t.Status, "draft"))
    ))
);

// function_score — inject custom signals into relevance score
// Use for: recency boost, popularity boost, personalization
var functionResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.FunctionScore(fs => fs
        .Query(fq => fq.Match(m => m
            .Field(f => f.Body)
            .Query("distributed systems")
        ))
        .Functions(fn => fn
            // Decay function — score drops as date moves away from now
            .Gauss(g => g
                .Field(f => f.Published)
                .Origin("now")
                .Scale("30d")     // half-score at 30 days old
                .Decay(0.5)
            )
            // Field value factor — multiply score by view_count signal
            .FieldValueFactor(fvf => fvf
                .Field(f => f.ViewCount)
                .Factor(0.1)
                .Modifier(FieldValueFactorModifier.Log1p)    // log(1 + view_count) — dampens outliers
                .Missing(1)
            )
        )
        .ScoreMode(FunctionScoreMode.Sum)      // how to combine function scores
        .BoostMode(FunctionBoostMode.Multiply) // how to combine with query score
    ))
);
```

**Function score and nested queries**
```csharp
// function_score — inject custom signals into relevance score
// Use for: recency boost, popularity boost, personalization
var functionResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.FunctionScore(fs => fs
        .Query(fq => fq.Match(m => m.Field(f => f.Body).Query("distributed systems")))
        .Functions(f => f
            // Decay function — score drops as date moves away from now
            .GaussDate(g => g
                .Field(f => f.Published)
                .Origin("now")
                .Scale("30d")  // half-score at 30 days old
                .Decay(0.5)
            )
        )
        .Functions(f => f
            // Field value factor — multiply score by view_count signal
            .FieldValueFactor(fvf => fvf
                .Field(f => f.ViewCount)
                .Factor(0.1)
                .Modifier(FieldValueFactorModifier.Log1p)  // log(1 + view_count) — dampens outliers
                .Missing(1)
            )
        )
        .ScoreMode(FunctionScoreMode.Sum)   // how to combine function scores
        .BoostMode(FunctionBoostMode.Multiply)  // how to combine with query score
    ))
);

// Nested queries — objects in arrays
// Without nested mapping, array objects are flattened and lose correlation
// Mapping — declare field as nested (done during index setup)
// Query — nested context preserves object correlation
var nestedResult = client.Search<Product>(s => s
    .Index("products")
    .Query(q => q.Nested(n => n
        .Path(p => p.Reviews)
        .Query(nq => nq.Bool(b => b
            .Must(m => m.Term(t => t.Field(f => f.Reviews.First().User).Value("ali")))
            .Must(m => m.Range(r => r.Field(f => f.Reviews.First().Score).GreaterThanOrEquals(4)))
        ))
        .ScoreMode(NestedScoreMode.Max)  // how nested hits contribute to parent score
    ))
);
```

**Highlighting and debugging**
```csharp
// highlight — show matched terms in context
var highlightResult = client.Search<Article>(s => s
    .Index("articles")
    .Query(q => q.Match(m => m.Field(f => f.Body).Query("inverted index")))
    .Highlight(h => h
        .Fields(f => f
            .Field(f => f.Body)
            .FragmentSize(200)
            .NumberOfFragments(2)
            .PreTags("<mark>")
            .PostTags("</mark>")
        )
    )
);

// explain — show why a document got its score
var explainResult = client.Explain<Article>(new DocumentPath<Article>("1"), e => e
    .Index("articles")
    .Query(q => q.Match(m => m.Field(f => f.Title).Query("postgres")))
);
// Returns: idf, tf, field length norm — the three BM25 components
```

---

## Gotchas

- **`filter` clauses don't affect score but `must` does — mixing them up corrupts ranking silently.** A hard status filter in `must` instead of `filter` forces score computation unnecessarily and skips the bitset cache. Move all non-relevance constraints to `filter`.
- **`match` on a `keyword` field doesn't analyze the query but the field is stored as-is.** `{"match": {"author": "Ali"}}` on a keyword field does an analyzed query against an unanalyzed field — it will lowercase "Ali" to "ali" and may or may not match depending on your analyzer. Use `term` for keyword fields, `match` for text fields.
- **`function_score` with `field_value_factor` and a missing field defaults to 1 unless you set `missing`.** If `view_count` is absent on some documents and you multiply by it, those documents get a factor of 1 — which may rank them higher or lower than intended. Always set `missing` explicitly.
- **Leading wildcards in `wildcard` and `regexp` queries disable index optimization and scan every term.** `"value": "*postgres"` forces Elasticsearch to evaluate every term in the field's term dictionary. On a large index this causes query timeouts. Disallow leading wildcards in user-facing search entirely.
- **`nested` queries are required when querying inside arrays of objects.** Without the `nested` field type and `nested` query, Elasticsearch flattens array objects into parallel arrays — a query for `user=ali AND score=5` can match a document where ali gave score=1 and someone else gave score=5. This is the most common silent correctness bug in ES document modeling.

---

## Interview Angle

**What they're really testing:** Whether you understand query context vs filter context, how BM25 scoring works, and can design a search query that's both correct and performant.

**Common question form:** *"How would you build a relevance-ranked product search with category filtering?"* or *"Why are some queries faster than others in Elasticsearch?"* or *"How does Elasticsearch score documents?"*

**The depth signal:** A junior puts everything in `must` and wonders why filters are slow. A senior separates scoring signals (`must`, `should`) from hard constraints (`filter`, `must_not`), knows that filter clauses use a roaring bitmap cache that makes repeated filters near-free, and can explain BM25 in plain terms: a document scores higher when the search term appears frequently in it (TF) but rarely across the corpus (IDF), adjusted for document length. At senior+ level: they know when to reach for `function_score` to blend textual relevance with popularity or recency signals, can explain why `nested` queries are necessary for correlated array object matching, and know that `explain` + `profile` are the tools for diagnosing scoring and performance problems.

---

## Related Topics

- [[databases/elasticsearch-fundamentals.md]] — Index setup, mappings, and the inverted index structure that makes these queries fast.
- [[databases/postgres-full-text-search.md]] — Postgres FTS query syntax vs ES DSL — parallel concepts, different capabilities.
- [[databases/mongodb-aggregation.md]] — ES aggregations vs MongoDB pipeline for analytics — both are multi-stage but differ in expressiveness.
- [[system-design/search-architecture.md]] — How queries route across shards, merge at the coordinator, and why deep pagination is expensive at the cluster level.

---

## Source

[Elasticsearch Query DSL documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html)

---
*Last updated: 2026-03-24*