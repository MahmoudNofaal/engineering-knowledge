# MongoDB Aggregation Pipeline

> A multi-stage data processing framework built into MongoDB that transforms, filters, groups, and reshapes documents server-side — the MongoDB equivalent of SQL's GROUP BY, JOIN, HAVING, and window functions combined.

---

## When To Use It

Use the aggregation pipeline when a simple `find()` isn't enough — analytics, reporting, grouped counts, computed fields, joining collections, or reshaping documents before sending to the client. Don't pull documents into application memory and process them in code when the pipeline can do it server-side. The exception: extremely complex transformations that are cleaner in application code, or when the pipeline stage count and memory usage make it slower than a targeted query plus minimal app-side work.

---

## Core Concept

The pipeline is a sequence of stages. Each stage receives a stream of documents, transforms it, and passes the result to the next stage. Stages are applied in order — the output of one is the input of the next. Only `$match` and `$sort` can use indexes, and only when they appear early in the pipeline before any stage that reshapes documents. That's the most important performance rule: filter early with `$match`, project early with `$project` to reduce document size, then group and transform. Running `$group` before `$match` means grouping the entire collection before filtering — a full collection scan every time.

---

## The Code

**Pipeline structure and stage order**
```csharp
using MongoDB.Driver;

var client = new MongoClient();
var db = client.GetDatabase("shopdb");
var col = db.GetCollection<BsonDocument>("orders");

var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument()),  // 1. Filter first — uses indexes
    new BsonDocument("$project", new BsonDocument()),  // 2. Reduce document size early
    new BsonDocument("$group", new BsonDocument()),  // 3. Aggregate reduced documents
    new BsonDocument("$sort", new BsonDocument()),  // 4. Sort aggregated results
    new BsonDocument("$limit", 10),  // 5. Cap output
};

var results = col.Aggregate<BsonDocument>(pipeline).ToList();
```

**`$match` — filter documents (always first)**
```csharp
using System;
using MongoDB.Driver;

var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument
    {
        { "status", "completed" },
        { "created_at", new BsonDocument("$gte", DateTime.UtcNow.AddDays(-30)) },
        { "total", new BsonDocument("$gt", 0) }
    })
};
```

**`$group` — aggregate and compute**
```csharp
var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument("status", "completed")),
    new BsonDocument("$group", new BsonDocument
    {
        { "_id", "$customer_id" },    // group key — null for grand total
        { "order_count", new BsonDocument("$sum", 1) },
        { "total_spent", new BsonDocument("$sum", "$total") },
        { "avg_order", new BsonDocument("$avg", "$total") },
        { "first_order", new BsonDocument("$min", "$created_at") },
        { "last_order", new BsonDocument("$max", "$created_at") },
        { "all_items", new BsonDocument("$push", "$items") },       // array of all items
        { "unique_skus", new BsonDocument("$addToSet", "$sku") },   // deduplicated array
    })
};
```

**`$project` — reshape and compute fields**
```csharp
var pipeline = new[]
{
    new BsonDocument("$project", new BsonDocument
    {
        { "name", 1 },                            // include
        { "email", 1 },
        { "password", 0 },                        // exclude sensitive field
        // Computed fields
        { "full_name", new BsonDocument("$concat", new BsonArray { "$first_name", " ", "$last_name" }) },
        { "year", new BsonDocument("$year", "$created_at") },
        { "discounted", new BsonDocument("$multiply", new BsonArray { "$price", 0.9 }) },
        { "is_vip", new BsonDocument("$gte", new BsonArray { "$total_spent", 1000 }) },  // boolean expression
    })
};
```

**`$addFields` — add fields without dropping others**
```csharp
// $project replaces the document shape; $addFields just adds to it
var pipeline = new[]
{
    new BsonDocument("$addFields", new BsonDocument
    {
        { "tax", new BsonDocument("$multiply", new BsonArray { "$total", 0.14 }) },
        { "grand_total", new BsonDocument("$multiply", new BsonArray { "$total", 1.14 }) },
    })
};
```

**`$unwind` — flatten arrays into separate documents**
```csharp
// Document: {order_id: 1, items: [{sku: "A"}, {sku: "B"}]}
// After $unwind: two documents, one per item

var pipeline = new[]
{
    new BsonDocument("$unwind", "$items"),
    new BsonDocument("$group", new BsonDocument
    {
        { "_id", "$items.sku" },
        { "count", new BsonDocument("$sum", 1) }
    })
};

// Preserve documents with empty or missing arrays
var pipelinePreserve = new[]
{
    new BsonDocument("$unwind", new BsonDocument
    {
        { "path", "$items" },
        { "preserveNullAndEmptyArrays", true }  // keeps docs where items is [] or missing
    })
};
```

**`$lookup` — join another collection**
```csharp
// Left outer join: attach product details to each order item
var pipeline = new[]
{
    new BsonDocument("$unwind", "$items"),
    new BsonDocument("$lookup", new BsonDocument
    {
        { "from", "products" },         // collection to join
        { "localField", "items.product_id" },  // field in current doc
        { "foreignField", "_id" },              // field in joined collection
        { "as", "product_detail" }      // output array field name
    }),
    // $lookup always produces an array — unwrap it
    new BsonDocument("$unwind", "$product_detail"),
    new BsonDocument("$project", new BsonDocument
    {
        { "order_id", 1 },
        { "qty", "$items.qty" },
        { "product", "$product_detail.name" },
        { "line_total", new BsonDocument("$multiply", new BsonArray { "$items.qty", "$product_detail.price" }) }
    })
};

// Pipeline $lookup — more powerful, lets you filter joined docs
var pipelineLookup = new[]
{
    new BsonDocument("$lookup", new BsonDocument
    {
        { "from", "products" },
        { "let", new BsonDocument { { "pid", "$product_id" }, { "min_stock", 10 } } },
        { "pipeline", new BsonArray
        {
            new BsonDocument("$match", new BsonDocument("$expr", new BsonDocument
            {
                { "$and", new BsonArray
                {
                    new BsonDocument("$eq", new BsonArray { "$$pid", "$_id" }),
                    new BsonDocument("$gte", new BsonArray { "$stock", "$$min_stock" })
                }}
            }))
        }},
        { "as", "available_product" }
    })
};
```
        ],
        "as": "available_product"
    }}
]
```

**`$facet` — multiple sub-pipelines in one pass**
```csharp
// Run several aggregations over the same input simultaneously
var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument("status", "completed")),
    new BsonDocument("$facet", new BsonDocument
    {
        { "by_status", new BsonArray
        {
            new BsonDocument("$group", new BsonDocument
            {
                { "_id", "$status" },
                { "count", new BsonDocument("$sum", 1) }
            })
        }},
        { "by_month", new BsonArray
        {
            new BsonDocument("$group", new BsonDocument
            {
                { "_id", new BsonDocument("$month", "$created_at") },
                { "total", new BsonDocument("$sum", "$amount") }
            }),
            new BsonDocument("$sort", new BsonDocument("_id", 1))
        }},
        { "summary", new BsonArray
        {
            new BsonDocument("$group", new BsonDocument
            {
                { "_id", BsonNull.Value },
                { "total_rev", new BsonDocument("$sum", "$amount") },
                { "avg_order", new BsonDocument("$avg", "$amount") },
            })
        }}
    })
};
// Returns one document with three arrays — one scan, three results
```

**`$bucket` — range-based grouping**
```csharp
var pipeline = new[]
{
    new BsonDocument("$bucket", new BsonDocument
    {
        { "groupBy", "$price" },
        { "boundaries", new BsonArray { 0, 100, 500, 1000, 5000 } },  // defines bucket edges
        { "default", "Other" },                      // catches values outside boundaries
        { "output", new BsonDocument
        {
            { "count", new BsonDocument("$sum", 1) },
            { "avg", new BsonDocument("$avg", "$price") }
        }}
    })
};
// Produces: {_id: 0, count: N}, {_id: 100, count: N}, ...
```

**`$sort` + `$limit` — top N pattern**
```csharp
// Always pair $sort with $limit — sorting without limiting is expensive
var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument("status", "completed")),
    new BsonDocument("$group", new BsonDocument
    {
        { "_id", "$customer_id" },
        { "total", new BsonDocument("$sum", "$amount") }
    }),
    new BsonDocument("$sort", new BsonDocument("total", -1)),
    new BsonDocument("$limit", 10),
    new BsonDocument("$project", new BsonDocument
    {
        { "customer", "$_id" },
        { "total", 1 },
        { "_id", 0 }
    })
};
```

**`$expr` — use aggregation expressions inside `$match`**
```csharp
// Compare two fields in the same document
var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument(
        "$expr", new BsonDocument("$gt", new BsonArray { "$actual_delivery", "$promised_delivery" })
    ))
};
```

**Explain a pipeline — check if indexes are used**
```csharp
var options = new AggregateOptions { Explain = true };
var explain = col.Aggregate<BsonDocument>(pipeline, options);
// Look for IXSCAN (index used) vs COLLSCAN (full scan) in the explain output
// $match at the start of the pipeline should show IXSCAN on indexed fields
```

---

## Gotchas

- **`$match` must come before `$group` to use an index.** Once `$group` reshapes documents, the original field paths are gone and no index can help. A `$match` after `$group` filters the grouped results — correct but no index benefit.
- **`$lookup` has no index hint — it always scans the joined collection unless the `foreignField` is indexed.** Always create an index on the `foreignField` before using `$lookup` in production. Without it, every joined document triggers a collection scan.
- **`$unwind` on a large array multiplies document count.** An order with 500 items becomes 500 documents after `$unwind`. Memory usage explodes before the next `$group` collapses it. Use `allowDiskUse: True` for pipelines that exceed the 100MB in-memory limit.
- **`$group` with `$push` accumulates unbounded arrays.** If you `$push` items across a million orders into one group, you get a document that exceeds MongoDB's 16MB document size limit. Use `$addToSet` only on low-cardinality fields, and avoid `$push` without a preceding `$limit`.
- **`$facet` runs sub-pipelines on the same input but doesn't parallelize them.** It's one pass, multiple accumulators — not concurrent execution. It's faster than running three separate aggregations but doesn't magically make expensive sub-pipelines cheap.

---

## Interview Angle

**What they're really testing:** Whether you can think in pipeline stages and understand how data volume changes at each stage — not just whether you know the syntax.

**Common question form:** *"How would you calculate monthly revenue by product category?"* or *"How do you join two collections in MongoDB?"* or *"How would you build a faceted search result?"*

**The depth signal:** A junior writes a pipeline that `$groups` before `$matching` and wonders why it's slow. A senior knows the stage-ordering rule — filter and project early to shrink the document stream before expensive operations — and can explain why: `$match` at the start hits an index, the same `$match` after `$group` is a linear scan of grouped results. They also know `$lookup` needs an index on `foreignField` to avoid nested collection scans, that `$unwind` on large arrays must be paired with `allowDiskUse`, and that `$facet` is one scan not N — which matters when the input `$match` is expensive.

---

## Related Topics

- [[databases/mongodb-fundamentals.md]] — Core CRUD, indexing, and the embed-vs-reference decision that shapes what you aggregate over.
- [[databases/postgres-jsonb.md]] — Postgres aggregation over JSONB vs MongoDB pipeline — knowing both helps you pick the right tool.
- [[databases/redis-patterns.md]] — Real-time counters and leaderboards in Redis vs batch aggregation in MongoDB are complementary patterns.
- [[databases/indexing-strategies.md]] — Pipeline performance lives and dies by index usage at the `$match` stage.

---

## Source

[MongoDB Aggregation Pipeline documentation](https://www.mongodb.com/docs/manual/core/aggregation-pipeline/)

---
*Last updated: 2026-03-24*