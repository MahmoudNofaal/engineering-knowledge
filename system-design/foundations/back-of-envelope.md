# Back-of-Envelope Estimation

> Quick, rough capacity calculations done before any design work — to understand the scale of the problem and expose constraints early.

---

## When To Use It
Right after requirements gathering and before drawing any architecture. You need these numbers to make defensible technology choices — you can't decide whether you need sharding, caching, or object storage without knowing your data volume and request rate. In interviews, skipping this step signals that you're guessing at your architecture rather than reasoning about it.

---

## Core Concept
Back-of-envelope estimation is about getting the right order of magnitude, not the exact number. You take the requirements (DAU, read/write ratio, object sizes) and derive: requests per second, storage over time, and bandwidth. These three outputs expose the system's character — is it read-heavy or write-heavy? Storage-bound or compute-bound? The math is simple; the skill is knowing which numbers matter and what they imply about your design.

---

## The Code
```python
# ── Core estimation template ──────────────────────────────────────────────

DAU            = 100_000_000   # 100M daily active users
reads_per_day  = 10            # average reads per user per day
writes_per_day = 1             # average writes per user per day
avg_object_kb  = 250           # average size of one write (e.g., a tweet + metadata)
retention_yrs  = 5

SECONDS_PER_DAY = 86_400

# ── Throughput ────────────────────────────────────────────────────────────
read_rps  = (DAU * reads_per_day)  / SECONDS_PER_DAY
write_rps = (DAU * writes_per_day) / SECONDS_PER_DAY

# ── Storage ───────────────────────────────────────────────────────────────
writes_per_day_total = DAU * writes_per_day
storage_5yr_tb = (writes_per_day_total * avg_object_kb * 365 * retention_yrs) / 1e9

# ── Bandwidth ─────────────────────────────────────────────────────────────
read_bandwidth_gbps  = (read_rps  * avg_object_kb * 1024) / 1e9
write_bandwidth_gbps = (write_rps * avg_object_kb * 1024) / 1e9

print(f"Read RPS:          {read_rps:>10,.0f}")
print(f"Write RPS:         {write_rps:>10,.0f}")
print(f"Storage (5yr TB):  {storage_5yr_tb:>10,.1f}")
print(f"Read bandwidth:    {read_bandwidth_gbps:>10.2f} Gbps")
print(f"Write bandwidth:   {write_bandwidth_gbps:>10.2f} Gbps")
```
```python
# ── Memory sizing: how much can one cache server hold? ────────────────────

cache_server_ram_gb  = 72       # typical cache node
object_size_bytes    = 500
objects_per_server   = (cache_server_ram_gb * 1e9) / object_size_bytes

print(f"Objects per cache node: {objects_per_server:,.0f}")
# Use this to decide: do you need a cache cluster or is one node enough?
```
```python
# ── Quick powers-of-2 / time cheat sheet (memorise these) ────────────────
units = {
    "1 KB":           1_000,
    "1 MB":           1_000_000,
    "1 GB":           1_000_000_000,
    "1 TB":           1_000_000_000_000,
    "Seconds/day":    86_400,
    "Seconds/month":  2_592_000,
    "Seconds/year":   31_536_000,
}
```

---

## Gotchas
- **Peak load ≠ average load.** Always multiply your average RPS by a peak factor (2x–10x depending on the system). A social platform at 11,000 write RPS average might spike to 80,000 during a live event. Design for peak, not average.
- **Don't conflate storage and bandwidth.** High storage doesn't mean high bandwidth — a cold archive has petabytes but near-zero throughput. High write RPS with small objects can saturate bandwidth with modest total storage. Estimate both separately.
- **Precision is a red flag.** Saying "11,574 RPS" implies false accuracy. Round aggressively — "~12K RPS" shows you understand estimation. Interviewers notice.
- **Object size assumptions drive everything.** A tweet (280 chars ≈ 300 bytes) and a photo (3 MB) produce wildly different storage estimates from the same user count. Clarify object sizes during requirements gathering or state your assumption explicitly.
- **Derived numbers should change your design.** If you calculate 50 TB/year of storage and then pick a single relational database, something went wrong. The estimation step must visibly inform the architecture step.

---

## Interview Angle
**What they're really testing:** Whether you can reason quantitatively about a system rather than just pattern-match to a known architecture.

**Common question form:** "Before we go further, can you estimate the scale we're dealing with?" or implied — the interviewer waits to see if you do it unprompted.

**The depth signal:** A junior candidate gives vague scale descriptions ("it'll be a lot of traffic") or does the math but doesn't connect it to decisions. A senior candidate runs the numbers quickly, rounds confidently, and immediately draws architecture implications: "At 15K write RPS we'll need to shard the write path — a single Postgres instance tops out around 5–10K. And at 200 TB over five years, we're in object storage territory, not block storage." The separation is: juniors calculate, seniors use the calculation to constrain the design.

---

## Related Topics
- [[system-design/requirements-gathering.md]] — You can't estimate without the numbers requirements gathering produces.
- [[system-design/latency-numbers.md]] — The companion reference: what the hardware can actually do at those scales.
- [[system-design/caching-strategies.md]] — Cache sizing decisions come directly from memory estimation.

---

## Source
https://highscalability.com/google-pro-tip-use-back-of-the-envelope-calculations-to-choo/

---
*Last updated: 2026-03-24*