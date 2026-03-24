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
```python
from elasticsearch import Elasticsearch

es = Elasticsearch("http://localhost:9200")

# Mappings are like a schema — define before indexing
# Wrong field types cause silent mis-indexing
es.indices.create(index="articles", body={
    "settings": {
        "number_of_shards":   2,    # more shards = more parallelism, more overhead
        "number_of_replicas": 1,    # replicas for redundancy, not speed on writes
        "analysis": {
            "analyzer": {
                "english_analyzer": {
                    "type":      "standard",
                    "stopwords": "_english_"
                }
            }
        }
    },
    "mappings": {
        "properties": {
            "title":      {"type": "text", "analyzer": "english_analyzer"},
            "body":       {"type": "text", "analyzer": "english_analyzer"},
            "author":     {"type": "keyword"},   # exact match, not analyzed
            "tags":       {"type": "keyword"},   # array of exact-match strings
            "published":  {"type": "date"},
            "view_count": {"type": "integer"},
            "title_suggest": {                   # for autocomplete
                "type":     "completion",
                "analyzer": "simple"
            }
        }
    }
})
```

**Indexing documents**
```python
# Single document
es.index(index="articles", id="1", document={
    "title":    "PostgreSQL Full-Text Search",
    "body":     "Postgres has built-in FTS using tsvector...",
    "author":   "ali",
    "tags":     ["postgres", "databases", "search"],
    "published": "2026-01-15",
    "view_count": 1240,
    "title_suggest": {"input": ["PostgreSQL Full-Text Search", "Postgres FTS"]}
})

# Bulk indexing — always use bulk for more than a few documents
from elasticsearch.helpers import bulk

actions = [
    {"_index": "articles", "_id": doc["id"], "_source": doc}
    for doc in documents
]
bulk(es, actions)
```

**Full-text search — match query**
```python
# Basic full-text search — analyzed, stemmed, scored
result = es.search(index="articles", body={
    "query": {
        "match": {
            "title": {
                "query":    "postgres indexing",
                "operator": "and"    # both terms must appear; default is "or"
            }
        }
    }
})

# Multi-field search with boosting
result = es.search(index="articles", body={
    "query": {
        "multi_match": {
            "query":  "postgres indexing",
            "fields": ["title^3", "body"],   # title match worth 3x body match
            "type":   "best_fields"          # score = best single field match
        }
    }
})

# Access hits
for hit in result["hits"]["hits"]:
    print(hit["_score"], hit["_source"]["title"])
```

**Bool query — combine clauses**
```python
result = es.search(index="articles", body={
    "query": {
        "bool": {
            # must: must match, affects score
            "must": [
                {"match": {"body": "distributed systems"}}
            ],
            # filter: must match, does NOT affect score, cached
            "filter": [
                {"term":  {"author": "ali"}},
                {"terms": {"tags": ["databases", "search"]}},
                {"range": {"published": {"gte": "2025-01-01"}}},
                {"range": {"view_count": {"gte": 100}}}
            ],
            # must_not: must not match
            "must_not": [
                {"term": {"tags": "draft"}}
            ],
            # should: nice to have, boosts score if present
            "should": [
                {"match": {"title": "distributed systems"}}
            ],
            "minimum_should_match": 0   # 0 = should is optional
        }
    }
})
```

**Aggregations — analytics over search results**
```python
result = es.search(index="articles", body={
    "size": 0,   # don't return documents, only aggregations
    "query": {
        "range": {"published": {"gte": "2025-01-01"}}
    },
    "aggs": {
        # Terms aggregation — top N values
        "top_authors": {
            "terms": {"field": "author", "size": 10}
        },
        # Date histogram — group by time bucket
        "articles_per_month": {
            "date_histogram": {
                "field":             "published",
                "calendar_interval": "month"
            }
        },
        # Nested aggregation — avg views per author
        "by_author": {
            "terms": {"field": "author"},
            "aggs": {
                "avg_views": {"avg": {"field": "view_count"}}
            }
        },
        # Range aggregation — bucket by value ranges
        "view_ranges": {
            "range": {
                "field":  "view_count",
                "ranges": [
                    {"to": 100},
                    {"from": 100, "to": 1000},
                    {"from": 1000}
                ]
            }
        }
    }
})

# Access aggregation results
buckets = result["aggregations"]["top_authors"]["buckets"]
for bucket in buckets:
    print(bucket["key"], bucket["doc_count"])
```

**Fuzzy search and autocomplete**
```python
# Fuzzy — handles typos (fuzziness = max edit distance)
result = es.search(index="articles", body={
    "query": {
        "match": {
            "title": {
                "query":     "postgress",   # typo
                "fuzziness": "AUTO"         # AUTO: 0 edits for 1-2 chars,
                                            #       1 edit for 3-5 chars,
                                            #       2 edits for 6+ chars
            }
        }
    }
})

# Autocomplete using completion suggester
result = es.search(index="articles", body={
    "suggest": {
        "title_autocomplete": {
            "prefix": "postgr",
            "completion": {
                "field": "title_suggest",
                "size":  5
            }
        }
    }
})
```

**Highlighting matched terms**
```python
result = es.search(index="articles", body={
    "query": {"match": {"body": "distributed systems"}},
    "highlight": {
        "fields": {
            "body": {
                "fragment_size":       150,    # chars per snippet
                "number_of_fragments": 3,      # max snippets per doc
                "pre_tags":  ["<mark>"],
                "post_tags": ["</mark>"]
            }
        }
    }
})

for hit in result["hits"]["hits"]:
    print(hit["highlight"]["body"])   # ["...distributed <mark>systems</mark>..."]
```

**Pagination — search_after over from/size**
```python
# from/size is fine for small offsets
result = es.search(index="articles", body={
    "from": 0, "size": 10,
    "query": {"match_all": {}},
    "sort":  [{"published": "desc"}, {"_id": "asc"}]
})

# search_after for deep pagination — stateless, uses last hit's sort values
last_hit    = result["hits"]["hits"][-1]
sort_values = last_hit["sort"]

next_page = es.search(index="articles", body={
    "size":         10,
    "query":        {"match_all": {}},
    "sort":         [{"published": "desc"}, {"_id": "asc"}],
    "search_after": sort_values   # cursor-based — no memory overhead
})
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