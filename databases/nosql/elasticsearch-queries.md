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
```python
from elasticsearch import Elasticsearch
es = Elasticsearch("http://localhost:9200")

# Bool is how you compose all other queries
# Each clause type has different scoring and caching behavior
result = es.search(index="articles", body={
    "query": {
        "bool": {
            "must":     [],    # must match + contributes to score
            "filter":   [],    # must match + NO score + cached (fast)
            "should":   [],    # optional + boosts score if matches
            "must_not": []     # must not match + NO score + cached
        }
    }
})
```

**Leaf queries — text fields**
```python
# match: standard full-text, analyzed
# Use for: user-typed search input on text fields
es.search(index="articles", body={
    "query": {
        "match": {
            "title": {
                "query":    "database indexing",
                "operator": "and",          # default is "or" — use "and" for precision
                "fuzziness": "AUTO"         # optional typo tolerance
            }
        }
    }
})

# match_phrase: terms must appear in order, adjacent
# Use for: exact phrase search
es.search(index="articles", body={
    "query": {
        "match_phrase": {
            "body": {
                "query": "inverted index",
                "slop":  2    # allow 2 words between terms and still match
            }
        }
    }
})

# match_phrase_prefix: last term is a prefix — autocomplete on body text
# Use for: search-as-you-type on text fields (completion suggester is better for titles)
es.search(index="articles", body={
    "query": {
        "match_phrase_prefix": {
            "title": {
                "query":             "elasticsearch qu",
                "max_expansions":    20   # limit how many prefix variations to try
            }
        }
    }
})

# multi_match: same query across multiple fields
# type controls how scores from multiple fields are combined
es.search(index="articles", body={
    "query": {
        "multi_match": {
            "query":    "sharding replication",
            "fields":   ["title^3", "body", "tags^2"],  # ^ = boost multiplier
            "type":     "best_fields",   # score = best single field
            # "most_fields"  — sum all field scores (rewards multiple field matches)
            # "cross_fields" — treat all fields as one big field (good for name search)
            # "phrase"       — match_phrase across fields
        }
    }
})
```

**Leaf queries — keyword/exact fields**
```python
# term: exact match on keyword field — case-sensitive
# Use for: filtering on IDs, statuses, enum values
es.search(index="articles", body={
    "query": {
        "term": {"status": {"value": "published"}}
    }
})

# terms: match any value in a list
es.search(index="articles", body={
    "query": {
        "terms": {"author": ["ali", "sara", "john"]}
    }
})

# range: numeric, date, keyword ranges
es.search(index="articles", body={
    "query": {
        "range": {
            "published": {
                "gte": "2025-01-01",
                "lte": "2025-12-31",
                "format": "yyyy-MM-dd"
            }
        }
    }
})

# exists: field is present and not null
es.search(index="articles", body={
    "query": {"exists": {"field": "thumbnail_url"}}
})

# ids: fetch specific documents by ID — faster than term query on _id
es.search(index="articles", body={
    "query": {"ids": {"values": ["1", "2", "3"]}}
})
```

**Fuzzy and wildcard**
```python
# fuzzy: handles typos via edit distance
# Use for: single-term search where user input may be misspelled
es.search(index="articles", body={
    "query": {
        "fuzzy": {
            "title": {
                "value":       "elasticsearh",   # typo
                "fuzziness":   2,                # max edit distance
                "prefix_length": 2              # first N chars must match exactly
                                                # prevents massive term expansion
            }
        }
    }
})

# wildcard: pattern matching — expensive, avoid leading wildcards
# Use for: controlled internal queries, never raw user input
es.search(index="articles", body={
    "query": {
        "wildcard": {
            "author": {
                "value": "a*",       # fine — no leading wildcard
                # "value": "*li"     # bad — scans entire term dictionary
            }
        }
    }
})

# regexp: regex on keyword field — use sparingly
es.search(index="articles", body={
    "query": {
        "regexp": {
            "tags": {
                "value": "data.*",
                "flags": "ALL"
            }
        }
    }
})
```

**Compound queries — combining and controlling scores**
```python
# Full production search query — the real pattern
result = es.search(index="articles", body={
    "query": {
        "bool": {
            # Full-text relevance — scored
            "must": [
                {
                    "multi_match": {
                        "query":  "database sharding",
                        "fields": ["title^3", "body"],
                        "type":   "best_fields"
                    }
                }
            ],
            # Hard constraints — not scored, cached
            "filter": [
                {"term":  {"status": "published"}},
                {"range": {"published": {"gte": "2024-01-01"}}},
                {"terms": {"tags": ["databases", "systems"]}}
            ],
            # Soft signals — boost score but not required
            "should": [
                {"term":  {"is_featured": True}},
                {"range": {"view_count": {"gte": 1000}}}
            ],
            "minimum_should_match": 0,   # 0 = should clauses optional
            "must_not": [
                {"term": {"status": "draft"}}
            ]
        }
    }
})

# function_score — inject custom signals into relevance score
# Use for: recency boost, popularity boost, personalization
es.search(index="articles", body={
    "query": {
        "function_score": {
            "query": {
                "match": {"body": "distributed systems"}
            },
            "functions": [
                # Decay function — score drops as date moves away from now
                {
                    "gauss": {
                        "published": {
                            "origin": "now",
                            "scale":  "30d",    # half-score at 30 days old
                            "decay":  0.5
                        }
                    }
                },
                # Field value factor — multiply score by view_count signal
                {
                    "field_value_factor": {
                        "field":    "view_count",
                        "factor":   0.1,
                        "modifier": "log1p",    # log(1 + view_count) — dampens outliers
                        "missing":  1
                    }
                }
            ],
            "score_mode":  "sum",      # how to combine function scores
            "boost_mode":  "multiply"  # how to combine with query score
        }
    }
})
```

**Nested queries — objects in arrays**
```python
# Without nested mapping, array objects are flattened and lose correlation
# Document: {reviews: [{user: "ali", score: 5}, {user: "sara", score: 1}]}
# Without nested: query for user=ali AND score=1 incorrectly matches

# Mapping — declare field as nested
es.indices.put_mapping(index="products", body={
    "properties": {
        "reviews": {
            "type": "nested",
            "properties": {
                "user":  {"type": "keyword"},
                "score": {"type": "integer"},
                "text":  {"type": "text"}
            }
        }
    }
})

# Query — nested context preserves object correlation
es.search(index="products", body={
    "query": {
        "nested": {
            "path": "reviews",
            "query": {
                "bool": {
                    "must": [
                        {"term":  {"reviews.user":  "ali"}},
                        {"range": {"reviews.score": {"gte": 4}}}
                    ]
                }
            },
            "score_mode": "max"   # how nested hits contribute to parent score
        }
    }
})
```

**Highlighting, explain, and debugging**
```python
# highlight — show matched terms in context
es.search(index="articles", body={
    "query":     {"match": {"body": "inverted index"}},
    "highlight": {
        "fields": {
            "body": {
                "fragment_size":       200,
                "number_of_fragments": 2,
                "pre_tags":  ["<mark>"],
                "post_tags": ["</mark>"]
            }
        }
    }
})

# explain — show why a document got its score
es.explain(index="articles", id="1", body={
    "query": {"match": {"title": "postgres"}}
})
# Returns: idf, tf, field length norm — the three BM25 components

# profile — show which query parts took how long
es.search(index="articles", body={
    "profile": True,
    "query":   {"match": {"title": "postgres"}}
})
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