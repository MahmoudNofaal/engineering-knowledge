# Data Lake vs Data Warehouse

> A data lake stores raw, unprocessed data in any format at massive scale; a data warehouse stores structured, cleaned, query-optimized data for analytics.

---

## When To Use It

Use a data warehouse when your analytics consumers are business users or BI tools running structured SQL queries on clean, well-defined data. Use a data lake when you need to store raw data cheaply before you know exactly how it will be used — ML training data, event logs, CDC streams, raw API responses. In practice, most mature systems end up with both: a lake as the landing zone and long-term store, and a warehouse as the curated layer on top. The "lakehouse" architecture (Delta Lake, Apache Iceberg) is an attempt to get both properties from one system.

---

## Core Concept

A data warehouse is a database designed for analytical queries rather than transactional ones. It uses columnar storage, pre-built aggregations, and a strictly enforced schema-on-write so that queries over billions of rows are fast and consistent. A data lake is a cheap object store (S3, GCS, ADLS) where you dump everything in its raw form — JSON, Parquet, CSV, images, logs — and define the schema only when you read it (schema-on-read). The lake is flexible and cheap but messy. The warehouse is structured and fast but requires upfront data modeling work. The ETL or ELT pipeline connecting them is where most of the engineering effort lives.

---

## The Code

### Writing raw events to a data lake (S3 via C#)
```csharp
using Amazon.S3;
using System;
using System.Text.Json;
using System.Threading.Tasks;

public class DataLakeWriter
{
    private readonly AmazonS3Client _s3;
    private const string Bucket = "my-data-lake";

    public DataLakeWriter()
    {
        _s3 = new AmazonS3Client();
    }

    public async Task WriteEventToLakeAsync(Dictionary<string, object> evt)
    {
        var now = DateTime.UtcNow;
        var key = $"events/year={now.Year}/month={now.Month:D2}/day={now.Day:D2}/{now.Ticks}.json";
        
        var content = JsonSerializer.Serialize(evt);
        await _s3.PutObjectAsync(new Amazon.S3.Model.PutObjectRequest
        {
            BucketName = Bucket,
            Key = key,
            ContentBody = content
        });
    }
}
```

### Querying the lake with Athena (schema-on-read)
```sql
-- Define schema at query time over raw S3 files
CREATE EXTERNAL TABLE events (
    user_id    BIGINT,
    event_type STRING,
    occurred_at TIMESTAMP
)
PARTITIONED BY (year INT, month INT, day INT)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://my-data-lake/events/';

-- Query it like a regular table
SELECT event_type, COUNT(*) FROM events
WHERE year = 2026 AND month = 3
GROUP BY event_type;
```

### Writing cleaned data into a warehouse (Redshift / BigQuery pattern)
```sql
-- Structured, typed, indexed — optimized for analytics
CREATE TABLE fct_user_events (
    user_id      BIGINT       NOT NULL,
    event_type   VARCHAR(50)  NOT NULL,
    occurred_at  TIMESTAMP    NOT NULL,
    session_id   VARCHAR(100)
)
DISTKEY(user_id)        -- Redshift: co-locate rows by user for fast aggregation
SORTKEY(occurred_at);   -- Redshift: skip scanning old data by sort order
```

---

## Gotchas

- **Data lakes turn into data swamps without governance** — without a catalog (AWS Glue, Apache Atlas) and naming conventions, nobody knows what's in the lake or whether it's trustworthy. Storage is cheap; discoverability is not free.
- **Schema-on-read means broken pipelines fail silently** — upstream changes the JSON structure, and your Athena query returns NULLs or wrong types with no error. Schema registries and data contracts prevent this.
- **Warehouse storage costs are nonlinear** — columnar warehouses like BigQuery or Redshift charge for storage and compute separately. A poorly written query that scans a full 10TB table every hour gets expensive fast.
- **ELT has replaced ETL in most modern stacks** — load raw data first, transform inside the warehouse using dbt or SQL. This is cheaper and more flexible than transforming before loading, but it means raw messy data lives in your warehouse too if you're not careful.
- **"Lakehouse" doesn't eliminate the trade-offs** — Delta Lake and Iceberg give ACID transactions on the lake, but query performance still trails a properly modeled warehouse for complex analytical workloads.

---

## Interview Angle

**What they're really testing:** Whether you understand the analytics data stack and can reason about trade-offs between flexibility, cost, and query performance at scale.

**Common question form:** "How would you design the data infrastructure for a product analytics system?" or "When would you use S3 + Athena instead of Redshift?"

**The depth signal:** A junior says "a warehouse is structured and a lake is not." A senior explains columnar storage and why it makes aggregations fast, describes the ELT pattern and where dbt fits, talks about partitioning strategies for cost control, and knows that in practice most systems use both and the interesting problem is the pipeline between them.

---

## Related Topics

- [[system-design/change-data-capture.md]] — CDC is one of the primary patterns for streaming operational data into a lake or warehouse.
- [[system-design/event-sourcing.md]] — Event stores are a natural source of raw data for a data lake.
- [[ai-engineering/feature-store.md]] — Feature stores sit between the lake/warehouse and ML models, serving pre-computed features for training and inference.

---

## Source

https://www.databricks.com/discover/data-lakes/introduction

---

*Last updated: 2026-03-24*