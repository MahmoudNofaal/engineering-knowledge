# PostgreSQL pgvector

> A Postgres extension that adds a native vector data type and approximate nearest-neighbor search, letting you store and query embeddings directly in your database without a separate vector store.

---

## When To Use It

Use pgvector when you're building semantic search, RAG pipelines, or recommendation features and you're already on Postgres — it avoids the operational cost of running a separate vector database like Pinecone or Weaviate. Don't use it when you need to query hundreds of millions of vectors at low latency with high recall — dedicated vector databases are better optimized for that scale. For most production RAG apps under ~5M vectors, pgvector is more than enough.

---

## Core Concept

Embeddings are fixed-length arrays of floats that represent meaning as position in high-dimensional space. Similar things are close together; different things are far apart. pgvector stores these as a `vector(n)` column and lets you search by distance — cosine, L2 (Euclidean), or inner product. Without an index, it does exact search (slow at scale). With an HNSW or IVFFlat index, it does approximate nearest-neighbor search (fast, with a small accuracy tradeoff). The index trades perfect recall for query speed — you control that tradeoff with index build parameters.

---

## The Code

**Install and setup**
```sql
-- Enable the extension (once per database)
CREATE EXTENSION IF NOT EXISTS vector;
```

**Create a table with a vector column**
```sql
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    content     TEXT NOT NULL,
    embedding   vector(1536)   -- dimension must match your embedding model
                               -- OpenAI text-embedding-3-small = 1536
);
```

**Insert embeddings**
```sql
-- Embeddings come from your app layer (OpenAI, etc.), stored as array literals
INSERT INTO documents (content, embedding) VALUES
('Postgres is a relational database', '[0.12, 0.83, ..., 0.45]'),
('Redis is an in-memory store',       '[0.95, 0.11, ..., 0.72]');
```

**Similarity search — three distance operators**
```sql
-- L2 distance (Euclidean) — <->
-- Cosine distance          — <=>
-- Inner product            — <#>

-- Cosine similarity search: find 5 most similar docs to a query embedding
SELECT id, content,
       1 - (embedding <=> '[0.12, 0.83, ..., 0.45]') AS similarity
FROM documents
ORDER BY embedding <=> '[0.12, 0.83, ..., 0.45]'
LIMIT 5;

-- Note: <=> returns cosine DISTANCE (0 = identical, 2 = opposite)
-- Subtract from 1 to get similarity score
```

**Indexing — HNSW (recommended) vs IVFFlat**
```sql
-- HNSW: better recall, faster queries, slower build, more memory
-- Build once, query many — production default
CREATE INDEX idx_documents_hnsw ON documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
-- m: connections per node (higher = better recall, more memory)
-- ef_construction: build-time search width (higher = better recall, slower build)

-- IVFFlat: faster build, less memory, lower recall
-- Better for datasets that change frequently
CREATE INDEX idx_documents_ivfflat ON documents
USING ivfflat (embedding vector_l2_ops)
WITH (lists = 100);
-- lists ≈ sqrt(row count) is the standard starting point
-- Run ANALYZE after bulk inserts so the planner uses the index
```

**Hybrid search — combine vector similarity with SQL filters**
```sql
-- Metadata filter + vector search in one query
SELECT id, content,
       embedding <=> '[0.12, 0.83, ..., 0.45]' AS distance
FROM documents
WHERE category = 'technical'        -- hard filter first
  AND created_at > NOW() - INTERVAL '30 days'
ORDER BY distance
LIMIT 10;
```

**Tuning query-time recall for HNSW**
```sql
-- ef_search controls recall vs speed at query time (default 40)
-- Raise it when you need higher recall; lower it for speed
SET hnsw.ef_search = 100;

SELECT content
FROM documents
ORDER BY embedding <=> '[...]'
LIMIT 5;
```

---

## Gotchas

- **Dimension mismatch is a hard error.** If your embedding model outputs 1536 dimensions and your column is `vector(768)`, the insert fails. Lock the model and dimension together — changing models means re-embedding everything and altering the column.
- **HNSW index is built on data that exists at creation time.** New rows are indexed incrementally, but the index quality degrades with large insert volumes. Rebuild the index (`REINDEX`) after bulk loads.
- **`<=>` is cosine DISTANCE, not similarity.** Order by it ascending for nearest neighbors. Forgetting this and ordering DESC is a common mistake that returns the least similar results.
- **IVFFlat requires `ANALYZE` after bulk inserts.** Without it, the query planner may skip the index entirely for new rows that fall outside the trained centroids.
- **pgvector exact search (`ORDER BY embedding <=> ... LIMIT n` with no index) does a full sequential scan.** Fine for development, catastrophic at scale. Always confirm the index is being used with `EXPLAIN ANALYZE`.

---

## Interview Angle

**What they're really testing:** Whether you understand the vector search problem and can reason about approximate vs exact search tradeoffs — not just that you know pgvector exists.

**Common question form:** *"How would you implement semantic search in a Postgres-backed RAG system?"* or *"When would you use pgvector vs Pinecone?"*

**The depth signal:** A junior says "store embeddings in pgvector and query by cosine similarity." A senior explains the HNSW vs IVFFlat tradeoff (recall, build time, memory), knows that `<=>` returns distance not similarity, understands that hybrid search combining metadata filters with vector search is the real production pattern, and can articulate the scale ceiling — pgvector works well up to a few million vectors on good hardware, but at tens of millions with strict latency SLAs, the approximate indexing in dedicated engines like Pinecone or Qdrant (purpose-built for this) pulls ahead because they shard and quantize at the storage layer in ways Postgres doesn't.

---

## Related Topics

- [[databases/postgres-jsonb.md]] — Metadata stored as JSONB alongside vector columns is a common pattern for hybrid search filters.
- [[databases/indexing-strategies.md]] — HNSW and IVFFlat are fundamentally different from B-tree and GIN; understanding the tradeoff space matters.
- [[ai-engineering/rag-pipeline.md]] — pgvector is the retrieval layer in most Postgres-native RAG systems.
- [[databases/postgres-full-text-search.md]] — Combining FTS (keyword) with pgvector (semantic) is the hybrid search pattern that beats either alone.

---

## Source

[pgvector GitHub — installation, operators, index options](https://github.com/pgvector/pgvector)

---
*Last updated: 2026-03-24*