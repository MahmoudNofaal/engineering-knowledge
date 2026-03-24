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
```python
from pymongo import MongoClient
from bson import ObjectId

client = MongoClient("mongodb://localhost:27017")
db     = client["shopdb"]
col    = db["products"]

# Insert
result = col.insert_one({
    "name":  "Laptop",
    "brand": "Dell",
    "price": 1200,
    "specs": {"ram_gb": 16, "ssd_gb": 512},
    "tags":  ["portable", "work"]
})
print(result.inserted_id)   # ObjectId("...")

# Insert many
col.insert_many([
    {"name": "Phone",  "brand": "Apple", "price": 999},
    {"name": "Tablet", "brand": "Apple", "price": 799},
])

# Find one
doc = col.find_one({"name": "Laptop"})

# Find many — returns a cursor, not a list
for doc in col.find({"brand": "Apple"}):
    print(doc["name"])

# Update one — $set only changes specified fields
col.update_one(
    {"name": "Laptop"},
    {"$set": {"price": 1100, "specs.ram_gb": 32}}
)

# Update many
col.update_many(
    {"brand": "Apple"},
    {"$inc": {"price": -50}}    # decrement price by 50
)

# Delete
col.delete_one({"name": "Tablet"})
```

**Query operators**
```python
# Comparison
col.find({"price": {"$gte": 500, "$lte": 1500}})

# Array contains
col.find({"tags": "portable"})          # exact element match
col.find({"tags": {"$all": ["portable", "work"]}})  # all elements present

# Nested field — dot notation
col.find({"specs.ram_gb": {"$gte": 16}})

# OR
col.find({"$or": [{"brand": "Dell"}, {"brand": "Apple"}]})

# Field existence
col.find({"discount": {"$exists": True}})

# Regex
col.find({"name": {"$regex": "^lap", "$options": "i"}})
```

**Projection — return only needed fields**
```python
# 1 = include, 0 = exclude. Can't mix include/exclude except for _id
col.find(
    {"brand": "Apple"},
    {"name": 1, "price": 1, "_id": 0}   # return name and price only
)
```

**Sorting, limiting, skipping**
```python
# Sort by price descending, take top 5
col.find().sort("price", -1).limit(5)

# Pagination — skip is inefficient on large collections; use range queries instead
col.find().sort("_id", 1).skip(20).limit(10)

# Better pagination — range on _id or a timestamp field
last_id = ObjectId("...")
col.find({"_id": {"$gt": last_id}}).sort("_id", 1).limit(10)
```

**Indexing**
```python
from pymongo import ASCENDING, DESCENDING, TEXT

# Single field
col.create_index("brand")

# Compound — order matters for query and sort alignment
col.create_index([("brand", ASCENDING), ("price", DESCENDING)])

# Unique
col.create_index("email", unique=True)

# Text index — full-text search (one per collection)
col.create_index([("name", TEXT), ("description", TEXT)])
col.find({"$text": {"$search": "laptop dell"}})

# Partial index — only index documents matching a filter
col.create_index(
    "discount",
    partialFilterExpression={"discount": {"$exists": True}}
)

# Check existing indexes
col.index_information()
```

**Aggregation pipeline**
```python
# Pipeline: sequence of stages, each transforms the document stream
pipeline = [
    # Stage 1: filter
    {"$match": {"brand": "Apple"}},

    # Stage 2: group and compute
    {"$group": {
        "_id":       "$brand",
        "avg_price": {"$avg": "$price"},
        "count":     {"$sum": 1},
        "max_price": {"$max": "$price"},
    }},

    # Stage 3: sort result
    {"$sort": {"avg_price": -1}},

    # Stage 4: reshape output
    {"$project": {
        "brand":     "$_id",
        "avg_price": {"$round": ["$avg_price", 2]},
        "count":     1,
        "_id":       0
    }}
]

list(col.aggregate(pipeline))
```

**Embed vs reference — the core modeling decision**
```python
# EMBED: address always read with user, never updated independently
{
    "_id":  ObjectId("..."),
    "name": "Ali",
    "address": {            # embedded — one document, one read
        "street": "123 Main St",
        "city":   "Cairo",
    }
}

# REFERENCE: orders are many, large, queried independently
{
    "_id":      ObjectId("..."),
    "name":     "Ali",
    "order_ids": [ObjectId("..."), ObjectId("...")]  # reference by ID
}
# Fetch orders separately — MongoDB has no JOIN, you do it in app code
# or use $lookup in aggregation
orders = db.orders.find({"_id": {"$in": user["order_ids"]}})

# $lookup — left outer join in aggregation (use sparingly)
pipeline = [
    {"$match": {"name": "Ali"}},
    {"$lookup": {
        "from":         "orders",
        "localField":   "order_ids",
        "foreignField": "_id",
        "as":           "orders"
    }}
]
```

**Multi-document transactions**
```python
# Use only when you must update multiple documents atomically
# Slower than single-document ops — avoid in hot paths

with client.start_session() as session:
    with session.start_transaction():
        db.accounts.update_one(
            {"_id": from_id},
            {"$inc": {"balance": -amount}},
            session=session
        )
        db.accounts.update_one(
            {"_id": to_id},
            {"$inc": {"balance": amount}},
            session=session
        )
        # Both commit or both roll back
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