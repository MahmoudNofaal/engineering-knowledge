# SQL Date & Time Functions

> Date and time functions let you extract, truncate, format, and perform arithmetic on temporal values — the foundation of every time-series query, reporting period calculation, and age computation.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Functions for manipulating and querying temporal values |
| **Use when** | Filtering by date range, grouping by period, calculating durations |
| **Avoid when** | Doing timezone math in application code — the database does it better |
| **Standard** | SQL-92 (basic); SQL:2011 (temporal tables); PostgreSQL has rich extensions |
| **Key functions** | `NOW()`, `CURRENT_DATE`, `DATE_TRUNC`, `EXTRACT`, `DATE_PART`, `AGE`, `TO_CHAR`, `TO_TIMESTAMP`, `AT TIME ZONE` |
| **Critical rule** | Always use TIMESTAMPTZ for application timestamps — never plain TIMESTAMP |

---

## When To Use It

Use date functions wherever your queries involve time — report periods, age calculations, filtering by recency, aggregating by day/week/month. The most important habit: always filter with explicit time boundaries rather than relative expressions in application code — let the database compute `NOW() - INTERVAL '30 days'` at query time, not at application startup. Date functions on indexed columns can suppress index use; `DATE_TRUNC(created_at) = '2024-01-01'` prevents an index on `created_at` from being used. Always filter with a range instead.

---

## Core Concept

PostgreSQL has six timestamp-related types: `DATE` (calendar date), `TIME` (time of day, no tz), `TIMETZ` (time + timezone — rarely useful), `TIMESTAMP` (date + time, no timezone), `TIMESTAMPTZ` (date + time, stored as UTC), and `INTERVAL` (a duration). For nearly all application work, use `TIMESTAMPTZ` for datetimes and `DATE` for calendar dates.

`TIMESTAMPTZ` stores values internally as UTC microseconds since the PostgreSQL epoch (2000-01-01). When you read a value, PostgreSQL converts from UTC to the session's `timezone` setting. This means the same stored value looks like different times to different users — which is correct behaviour for a global application.

`INTERVAL` represents a duration — `INTERVAL '3 months 2 days 4 hours'`. Interval arithmetic is calendar-aware: adding 1 month to January 31 gives February 28/29 (last day of February), not March 3.

---

## Version History

| PostgreSQL Version | What changed |
|---|---|
| Pre-8.0 | DATE, TIME, TIMESTAMP, INTERVAL, basic functions |
| 8.1 | TIMESTAMPTZ improvements; AT TIME ZONE |
| 9.0 | Date/time function performance improvements |
| 9.6 | `pg_timezone_names` view added |
| 12 | `DATE_BIN` function added (truncate to arbitrary intervals) |
| 14 | Multirange types (daterange[], tstzrange[]) |

---

## Performance

| Pattern | Index use | Notes |
|---|---|---|
| `WHERE col >= x AND col < y` | B-tree range scan | Best pattern — always use this |
| `WHERE DATE_TRUNC('day', col) = '2024-01-15'` | None | Function on column — seq scan |
| `WHERE col::DATE = '2024-01-15'` | None | Cast on column — seq scan |
| `WHERE EXTRACT(year FROM col) = 2024` | None | Function on column — seq scan |
| `WHERE col BETWEEN x AND y` | B-tree range scan | Works but BETWEEN is inclusive on both ends |
| BRIN index on ordered TIMESTAMPTZ | BRIN scan | Excellent for large append-only log tables |

**The golden rule for date filtering:**
```sql
-- BAD: function on column suppresses index
WHERE DATE_TRUNC('day', created_at) = '2024-01-15'

-- GOOD: range on the column — uses the index
WHERE created_at >= '2024-01-15'::TIMESTAMPTZ
  AND created_at  < '2024-01-16'::TIMESTAMPTZ
```

---

## The Code

**Current time functions**
```sql
SELECT
    NOW(),                  -- current timestamp with timezone (TIMESTAMPTZ)
    CURRENT_TIMESTAMP,      -- same as NOW() — SQL standard
    CURRENT_DATE,           -- current date (DATE) — no time component
    CURRENT_TIME,           -- current time with timezone
    CLOCK_TIMESTAMP(),      -- actual current time (NOW() is fixed within a transaction)
    TIMEOFDAY();            -- text representation of current time
```

**DATE_TRUNC — truncate to a time unit**
```sql
-- Truncates to the start of the specified period
SELECT
    DATE_TRUNC('year',    NOW()),  -- 2024-01-01 00:00:00+00
    DATE_TRUNC('quarter', NOW()),  -- 2024-01-01 (or 04-01, 07-01, 10-01)
    DATE_TRUNC('month',   NOW()),  -- 2024-04-01 00:00:00+00
    DATE_TRUNC('week',    NOW()),  -- Monday of current week
    DATE_TRUNC('day',     NOW()),  -- today midnight
    DATE_TRUNC('hour',    NOW()),  -- top of current hour
    DATE_TRUNC('minute',  NOW()); -- current minute

-- Primary use: GROUP BY time periods
SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*)                         AS new_users
FROM users
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month;
```

**EXTRACT / DATE_PART — extract a specific field**
```sql
-- EXTRACT is SQL standard; DATE_PART is PostgreSQL synonym
SELECT
    EXTRACT(year   FROM NOW()),    -- 2024
    EXTRACT(month  FROM NOW()),    -- 4
    EXTRACT(day    FROM NOW()),    -- 13
    EXTRACT(hour   FROM NOW()),    -- 14
    EXTRACT(dow    FROM NOW()),    -- 0=Sunday, 1=Monday ... 6=Saturday
    EXTRACT(isodow FROM NOW()),    -- 1=Monday ... 7=Sunday (ISO)
    EXTRACT(week   FROM NOW()),    -- ISO week number (1–53)
    EXTRACT(epoch  FROM NOW());    -- Unix timestamp (seconds since 1970-01-01)

-- BAD: using EXTRACT in WHERE (suppresses index)
WHERE EXTRACT(year FROM created_at) = 2024

-- GOOD: range query
WHERE created_at >= '2024-01-01'::TIMESTAMPTZ
  AND created_at  < '2025-01-01'::TIMESTAMPTZ
```

**DATE_BIN — truncate to arbitrary intervals (PostgreSQL 12+)**
```sql
-- Bin timestamps into 15-minute buckets (useful for metrics)
SELECT
    DATE_BIN('15 minutes', created_at, '2024-01-01') AS bucket,
    COUNT(*)                                           AS events
FROM events
GROUP BY DATE_BIN('15 minutes', created_at, '2024-01-01')
ORDER BY bucket;
-- More flexible than DATE_TRUNC — works for any interval, not just calendar units
```

**INTERVAL arithmetic**
```sql
SELECT
    NOW() + INTERVAL '7 days',          -- 7 days from now
    NOW() - INTERVAL '3 months',        -- 3 months ago
    NOW() + INTERVAL '1 year 2 months 3 days 4 hours',

    -- Date arithmetic using integers
    CURRENT_DATE + 7,                   -- 7 days from today (DATE + INT = DATE)
    CURRENT_DATE - 30;                  -- 30 days ago

-- Filter: last 30 days
SELECT * FROM orders
WHERE created_at >= NOW() - INTERVAL '30 days';

-- Compute interval between two timestamps
SELECT created_at, updated_at,
       (updated_at - created_at) AS time_to_resolve  -- returns INTERVAL
FROM support_tickets;
```

**AGE — human-readable interval**
```sql
-- AGE returns a "cleaned up" interval (years, months, days)
SELECT
    AGE(NOW(), '1990-05-15'::DATE),         -- '33 years 11 months 1 day'
    AGE('2024-03-01', '2023-12-15'),        -- '2 months 16 days'
    EXTRACT(year FROM AGE(birth_date))      -- person's age in years
FROM users;
```

**Timezone handling — AT TIME ZONE**
```sql
-- Convert a TIMESTAMPTZ to a specific timezone for display
SELECT NOW() AT TIME ZONE 'America/New_York';    -- EST/EDT display
SELECT NOW() AT TIME ZONE 'Asia/Cairo';           -- Cairo time

-- Store in UTC (TIMESTAMPTZ does this automatically)
-- Display in user's timezone at query time
SELECT
    user_id,
    created_at AT TIME ZONE u.timezone AS local_created_at
FROM events e
JOIN users u ON u.id = e.user_id;

-- List all available timezone names
SELECT name, abbrev, utc_offset FROM pg_timezone_names ORDER BY name;
```

**TO_CHAR — format a timestamp as a string**
```sql
SELECT
    TO_CHAR(NOW(), 'YYYY-MM-DD'),                -- '2024-04-13'
    TO_CHAR(NOW(), 'DD Mon YYYY'),               -- '13 Apr 2024'
    TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),     -- '2024-04-13 14:23:45'
    TO_CHAR(NOW(), 'Day, DD Month YYYY'),         -- 'Saturday, 13 April  2024'
    TO_CHAR(NOW(), 'YYYY"W"IW'),                 -- '2024W15' (ISO week)
    TO_CHAR(NOW(), 'Q');                          -- '2' (quarter)
```

**TO_TIMESTAMP / TO_DATE — parse strings to temporal types**
```sql
-- Parse string to TIMESTAMP
SELECT TO_TIMESTAMP('2024-04-13 14:23:45', 'YYYY-MM-DD HH24:MI:SS');

-- Parse string to DATE
SELECT TO_DATE('13/04/2024', 'DD/MM/YYYY');

-- Cast syntax (for ISO-format strings — PostgreSQL handles these automatically)
SELECT '2024-04-13'::DATE;
SELECT '2024-04-13 14:23:45'::TIMESTAMPTZ;
SELECT '2024-04-13T14:23:45Z'::TIMESTAMPTZ;  -- ISO 8601
```

**Generate a date series — fill gaps in reporting**
```sql
-- Generate every day in a range (no missing days in the result)
SELECT
    d::DATE AS report_date,
    COALESCE(COUNT(o.id), 0) AS order_count
FROM GENERATE_SERIES(
    '2024-01-01'::DATE,
    '2024-01-31'::DATE,
    INTERVAL '1 day'
) d
LEFT JOIN orders o
    ON o.created_at >= d
   AND o.created_at  < d + INTERVAL '1 day'
GROUP BY d
ORDER BY d;
-- GENERATE_SERIES fills in every date; LEFT JOIN gives 0 for days with no orders
```

---

## Real World Example

A SaaS analytics dashboard needs to compute month-over-month revenue growth with period labels, bucket events into hourly metrics, and show each customer's days-since-last-login — all while correctly handling timezone display for a global user base.

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', created_at)                                 AS period_start,
        TO_CHAR(DATE_TRUNC('month', created_at), 'Mon YYYY')            AS period_label,
        SUM(amount)                                                      AS revenue
    FROM payments
    WHERE status = 'succeeded'
      AND created_at >= DATE_TRUNC('year', NOW())   -- this year only
    GROUP BY DATE_TRUNC('month', created_at)
),
growth_calc AS (
    SELECT
        period_start,
        period_label,
        revenue,
        LAG(revenue) OVER (ORDER BY period_start)  AS prev_revenue
    FROM monthly_revenue
)
SELECT
    period_label,
    revenue,
    prev_revenue,
    CASE
        WHEN prev_revenue IS NULL OR prev_revenue = 0 THEN NULL
        ELSE ROUND(100.0 * (revenue - prev_revenue) / prev_revenue, 1)
    END AS mom_growth_pct
FROM growth_calc
ORDER BY period_start;
```

*The key insight: `DATE_TRUNC` groups payments into monthly buckets for aggregation, `TO_CHAR` formats the period into a human-readable label, and `LAG` accesses the prior month for growth calculation. The range filter on `created_at` uses a half-open interval (`>=` start of year) — no function on the column, so the index on `created_at` is used fully.*

---

## Common Misconceptions

**"BETWEEN works the same as >= AND <"**
BETWEEN is inclusive on both ends: `BETWEEN '2024-01-01' AND '2024-01-31'` includes rows at exactly `'2024-01-31 00:00:00'` but misses rows from `'2024-01-31 01:00:00'` onward. For date ranges, the half-open interval pattern is safer: `>= '2024-01-01' AND < '2024-02-01'`.

**"NOW() gives me a different time on each call in the same query"**
`NOW()` and `CURRENT_TIMESTAMP` are fixed to the start of the transaction — they return the same value no matter how many times you call them within a transaction. If you need the actual wall-clock time at each point of execution (for timing sub-steps), use `CLOCK_TIMESTAMP()` instead.

**"I can store timezones by saving the offset (+03:00)"**
Storing a fixed offset like `+03:00` loses DST information. Cairo is `+02:00` in winter and `+03:00` in summer — storing `+03:00` is wrong half the year. Always store timezone names (`'Africa/Cairo'`, `'America/New_York'`) and use `AT TIME ZONE` for conversion. PostgreSQL's `pg_timezone_names` has the full IANA timezone database.

---

## Gotchas

- **Functions on timestamp columns suppress index use** — `WHERE DATE_TRUNC('day', created_at) = '2024-01-15'` forces a sequential scan. Always rewrite as a range: `WHERE created_at >= '2024-01-15' AND created_at < '2024-01-16'`.

- **Adding months to month-end dates produces unexpected results** — `'2024-01-31'::DATE + INTERVAL '1 month'` gives `'2024-02-29'` (or 28 in non-leap years) — the last day of February. This is correct calendar arithmetic but surprises people expecting `'2024-03-02'`.

- **EXTRACT(epoch ...) returns seconds, not milliseconds** — JavaScript uses milliseconds; PostgreSQL's epoch returns seconds. `EXTRACT(epoch FROM NOW()) * 1000` if you need milliseconds.

- **Timezone abbreviations are ambiguous** — `'EST'` might mean UTC-5 or UTC+10 depending on the database and platform. Always use IANA timezone names (`'America/New_York'`) for unambiguous timezone specification.

- **`NOW() - INTERVAL '1 month'` at month boundaries is calendar-aware** — it subtracts one calendar month, not 30 days. From March 31, subtracting 1 month gives February 28/29 — not March 1. If you want exactly 30 days, use `NOW() - INTERVAL '30 days'`.

---

## Interview Angle

**What they're really testing:** Whether you can write time-based queries that are both correct (handle timezone, DST, month-end edge cases) and performant (don't suppress index use with functions on columns).

**Common question forms:**
- "Write a query to show daily active users for the last 30 days"
- "How would you group orders by week?"
- "Why is this date filter slow?"

**The depth signal:** A junior knows `NOW()` and `BETWEEN`. A senior knows that functions on timestamp columns prevent index use, uses half-open intervals instead of BETWEEN for date ranges, understands the difference between `TIMESTAMP` and `TIMESTAMPTZ`, uses `GENERATE_SERIES` to fill gaps in time-series data, and knows that `NOW()` is transaction-fixed while `CLOCK_TIMESTAMP()` is wall-clock. Knowing `DATE_BIN` for arbitrary interval bucketing and IANA timezone names for unambiguous timezone handling are strong differentiators.

**Follow-up questions to expect:**
- "How do you handle timezones when users are in different countries?"
- "What's the correct way to filter by a specific calendar day on a TIMESTAMPTZ column?"

---

## Related Topics

- [[databases/sql/sql-indexing.md]] — range queries on TIMESTAMPTZ columns are the correct index-friendly pattern
- [[databases/sql/sql-aggregations.md]] — DATE_TRUNC is the standard way to GROUP BY time period
- [[databases/sql/sql-window-functions.md]] — LAG/LEAD on ordered time series is a common analytics pattern
- [[databases/sql/sql-data-types.md]] — TIMESTAMP vs TIMESTAMPTZ and INTERVAL type storage details

---

## Source

https://www.postgresql.org/docs/current/functions-datetime.html

---
*Last updated: 2026-04-13*