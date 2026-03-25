# MongoDB Fundamentals

> A document database that stores data as BSON (binary JSON) objects in collections, giving you a flexible schema, rich query language, and horizontal scaling without requiring a predefined table structure.

---

## When To Use It

Use MongoDB when your data is naturally document-shaped — each record is self-contained with variable fields, and you query it as a whole unit. Good fits: product catalogs with varying attributes, CMS content, user profiles, event logs. Bad fits: data with heavy relationships that you constantly join across (use Postgres), financial transactions requiring strict ACID across multiple documents (use Postgres), or anything where the schema is actually well-defined and stable (the flexibility costs you query power you never needed).

---

## Core Concept

MongoDB stores documents — BSON objects — in collections. No fixed schema means documents in the same collection can have different fields. Queries happen against field values inside documents, including nested objects and arrays. The document is the unit of atomicity — a single document write is always atomic. Multi-document transactions exist but are slower and should be the exception. The data modeling question is always: embed or reference? Embed when you always read the data together. Reference when the related data is large, frequently updated independently, or shared across many documents.

---

## The Code

**Connecting and basic CRUD**
```csharp
using MongoDB.Driver;
using MongoDB.Bson;

var client = new MongoClient("mongodb://localhost:27017");
var db = client.GetDatabase("shopdb");
var col = db.GetCollection<BsonDocument>("products");

// Insert
var result = col.InsertOne(new BsonDocument
{
    { "name", "Laptop" },
    { "brand", "Dell" },
    { "price", 1200 },
    { "specs", new BsonDocument { { "ram_gb", 16 }, { "ssd_gb", 512 } } },
    { "tags", new BsonArray { "portable", "work" } }
});
Console.WriteLine(result.InsertedId);   // ObjectId(...)

// Insert many
col.InsertMany(new[]
{
    new BsonDocument { { "name", "Phone" }, { "brand", "Apple" }, { "price", 999 } },
    new BsonDocument { { "name", "Tablet" }, { "brand", "Apple" }, { "price", 799 } }
});

// Find one
var doc = col.Find(Builders<BsonDocument>.Filter.Eq("name", "Laptop")).FirstOrDefault();

// Find many
foreach (var product in col.Find(Builders<BsonDocument>.Filter.Eq("brand", "Apple")).ToList())
{
    Console.WriteLine(product["name"]);
}

// Update one — $set only changes specified fields
col.UpdateOne(
    Builders<BsonDocument>.Filter.Eq("name", "Laptop"),
    Builders<BsonDocument>.Update.Set("price", 1100).Set("specs.ram_gb", 32)
);

// Update many
col.UpdateMany(
    Builders<BsonDocument>.Filter.Eq("brand", "Apple"),
    Builders<BsonDocument>.Update.Inc("price", -50)    // decrement price by 50
);

// Delete
col.DeleteOne(Builders<BsonDocument>.Filter.Eq("name", "Tablet"));
```

**Query operators**
```csharp
// Comparison
col.Find(Builders<BsonDocument>.Filter.And(
    Builders<BsonDocument>.Filter.Gte("price", 500),
    Builders<BsonDocument>.Filter.Lte("price", 1500)
));

// Array contains
col.Find(Builders<BsonDocument>.Filter.Eq("tags", "portable"));  // exact element match
col.Find(Builders<BsonDocument>.Filter.All("tags", new[] { "portable", "work" }));  // all elements present

// Nested field — dot notation
col.Find(Builders<BsonDocument>.Filter.Gte("specs.ram_gb", 16));

// OR
col.Find(Builders<BsonDocument>.Filter.Or(
    Builders<BsonDocument>.Filter.Eq("brand", "Dell"),
    Builders<BsonDocument>.Filter.Eq("brand", "Apple")
));

// Field existence
col.Find(Builders<BsonDocument>.Filter.Exists("discount", true));

// Regex
col.Find(Builders<BsonDocument>.Filter.Regex("name", "^lap"));
```

**Projection — return only needed fields**
```csharp
// 1 = include, 0 = exclude. Can't mix include/exclude except for _id
var projection = Builders<BsonDocument>.Projection
    .Include("name")
    .Include("price")
    .Exclude("_id");

col.Find(Builders<BsonDocument>.Filter.Eq("brand", "Apple"))
   .Project(projection)
   .ToList();   // return name and price only
```

**Sorting, limiting, skipping**
```csharp
// Sort by price descending, take top 5
col.Find(FilterDefinition<BsonDocument>.Empty)
   .Sort(Builders<BsonDocument>.Sort.Descending("price"))
   .Limit(5)
   .ToList();

// Pagination -- skip is inefficient on large collections; use range queries instead
col.Find(FilterDefinition<BsonDocument>.Empty)
   .Sort(Builders<BsonDocument>.Sort.Ascending("_id"))
   .Skip(20)
   .Limit(10)
   .ToList();

// Better pagination -- range on _id or a timestamp field
var lastId = ObjectId.Parse("...");
col.Find(Builders<BsonDocument>.Filter.Gt("_id", lastId))
   .Sort(Builders<BsonDocument>.Sort.Ascending("_id"))
   .Limit(10)
   .ToList();
```

**Indexing**
```csharp
using MongoDB.Driver;

// Single field
col.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Ascending("brand")
));

// Compound — order matters for query and sort alignment
col.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Ascending("brand").Descending("price")
));

// Unique
col.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Ascending("email"),
    new CreateIndexOptions { Unique = true }
));

// Text index — full-text search (one per collection)
col.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Text("name").Text("description")
));
col.Find(Builders<BsonDocument>.Filter.Text("laptop dell"));

// Partial index — only index documents matching a filter
col.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Ascending("discount"),
    new CreateIndexOptions
    {
        PartialFilterExpression = Builders<BsonDocument>.Filter.Exists("discount", true)
    }
));

// Check existing indexes
var indexList = col.Indexes.List();
```

**Aggregation pipeline**
```csharp
// Pipeline: sequence of stages, each transforms the document stream
var pipeline = new[]
{
    // Stage 1: filter
    new BsonDocument("$match", new BsonDocument("brand", "Apple")),

    // Stage 2: group and compute
    new BsonDocument("$group", new BsonDocument
    {
        { "_id", "$brand" },
        { "avg_price", new BsonDocument("$avg", "$price") },
        { "count", new BsonDocument("$sum", 1) },
        { "max_price", new BsonDocument("$max", "$price") },
    }),

    // Stage 3: sort result
    new BsonDocument("$sort", new BsonDocument("avg_price", -1)),

    // Stage 4: reshape output
    new BsonDocument("$project", new BsonDocument
    {
        { "brand", "$_id" },
        { "avg_price", new BsonDocument("$round", new BsonArray { "$avg_price", 2 }) },
        { "count", 1 },
        { "_id", 0 }
    })
};

col.Aggregate<BsonDocument>(pipeline).ToList();
```

**Embed vs reference — the core modeling decision**
```csharp
// EMBED: address always read with user, never updated independently
var userEmbedded = new BsonDocument
{
    { "_id", ObjectId.GenerateNewId() },
    { "name", "Ali" },
    { "address", new BsonDocument              // embedded — one document, one read
    {
        { "street", "123 Main St" },
        { "city", "Cairo" }
    }}
};

// REFERENCE: orders are many, large, queried independently
var userReferenced = new BsonDocument
{
    { "_id", ObjectId.GenerateNewId() },
    { "name", "Ali" },
    { "order_ids", new BsonArray              // reference by ID
    {
        ObjectId.GenerateNewId(),
        ObjectId.GenerateNewId()
    }}
};

// Fetch orders separately — MongoDB has no JOIN, you do it in app code
// or use $lookup in aggregation
var userOrderIds = userReferenced["order_ids"].AsBsonArray.Cast<ObjectId>().ToList();
var orders = db.GetCollection<BsonDocument>("orders")
    .Find(Builders<BsonDocument>.Filter.In("_id", userOrderIds))
    .ToList();

// $lookup — left outer join in aggregation (use sparingly)
var pipeline = new[]
{
    new BsonDocument("$match", new BsonDocument("name", "Ali")),
    new BsonDocument("$lookup", new BsonDocument
    {
        { "from", "orders" },
        { "localField", "order_ids" },
        { "foreignField", "_id" },
        { "as", "orders" }
    })
};
```

**Multi-document transactions**
```csharp
// Use only when you must update multiple documents atomically
// Slower than single-document ops -- avoid in hot paths

using (var session = client.StartSession())
{
    session.StartTransaction();
    try
    {
        var accountsCol = db.GetCollection<BsonDocument>("accounts");
        
        accountsCol.UpdateOne(
            session,
            Builders<BsonDocument>.Filter.Eq("_id", fromId),
            Builders<BsonDocument>.Update.Inc("balance", -amount)
        );
        
        accountsCol.UpdateOne(
            session,
            Builders<BsonDocument>.Filter.Eq("_id", toId),
            Builders<BsonDocument>.Update.Inc("balance", amount)
        );
        
        session.CommitTransaction();  // Both commit or both roll back
    }
    catch
    {
        session.AbortTransaction();
        throw;
    }
}
```

---

## Gotchas

- **Schema flexibility is not schema freedom.** Without validation, bad data silently enters the collection. Add JSON Schema validation at the collection level (`db.create_collection` with `validator`) or enforce it in your application layer. Discovering you have 3 different shapes for the same field at query time is painful.
- **`skip()` is O(n) — it scans and discards.** On page 500 of a result set, MongoDB has scanned 5000 documents to throw away 4990. Use range-based pagination on an indexed field (`_id` or a timestamp) for anything beyond the first few pages.
- **Updating a field on millions of documents with `update_many` holds no transaction.** If it fails halfway through, you have a partially updated collection with no rollback. Run large updates in batches with `_id`-based cursors and make the operation idempotent.
- **Text indexes are one per collection and cover all languages with one default stemmer.** You can't have two text indexes on the same collection, and multi-language stemming requires per-document language hints. For serious full-text search, Postgres FTS or Elasticsearch will outclass it.
- **`ObjectId` embeds a timestamp — you get a `created_at` for free.** `ObjectId.generation_time` returns the UTC creation time. Don't add a redundant `created_at` field unless you need millisecond precision (ObjectId is second-level).

---

## Interview Angle

**What they're really testing:** Whether you understand document modeling tradeoffs and know the failure modes — not just that you can write a find query.

**Common question form:** *"How would you model a blog with posts and comments in MongoDB?"* or *"When would you embed vs reference?"* or *"How does MongoDB handle transactions?"*

**The depth signal:** A junior embeds everything because "it's flexible" and references everything because "normalization." A senior explains the actual decision criteria: embed when data is always read together, has bounded size, and isn't shared; reference when data is large, updated independently, or accessed on its own. They also know that multi-document transactions exist but are slower and should be rare — the schema should be designed so most writes touch one document. On the ops side: they know `skip()` is a performance trap, that `update_many` is not atomic across documents, and that missing indexes on query fields causes collection scans that kill performance silently.

---

## Related Topics

- [[databases/nosql-types.md]] — MongoDB is the document store type; understanding the full NoSQL landscape gives it context.
- [[databases/postgres-jsonb.md]] — Postgres with JSONB covers a meaningful slice of the MongoDB use case; know when to stay relational.
- [[databases/indexing-strategies.md]] — Compound index field order, partial indexes, and explain() output are the same concepts applied to MongoDB's query planner.
- [[databases/redis-fundamentals.md]] — MongoDB and Redis are often used together: Mongo as primary store, Redis as cache layer in front of it.

---

## Source

[MongoDB documentation — CRUD, aggregation, data modeling](https://www.mongodb.com/docs/manual/)

---
*Last updated: 2026-03-24*