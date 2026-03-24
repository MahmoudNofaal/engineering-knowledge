# Rate Limiting

> Controlling how many requests a client can make to a service within a time window — to protect the service from abuse, overload, and uneven resource consumption.

---

## When To Use It
Any public-facing API, any endpoint that does expensive work (sends emails, charges cards, runs ML inference), and any service that could be weaponized for abuse. Rate limiting is also necessary internally — a misbehaving microservice should not be able to take down its dependencies. If you have no rate limiting, one bad actor or one runaway process can take down your entire service.

---

## Core Concept
Rate limiting tracks how many requests a client has made within some time window and rejects (or delays) requests that exceed the limit. The client is usually identified by API key, user ID, or IP address. The hard part isn't the concept — it's which algorithm to use and where to enforce the limit. Different algorithms have different properties: token bucket allows short bursts, fixed window is simple but allows 2× the intended rate at window boundaries, sliding window log is accurate but expensive, sliding window counter is a practical compromise. Where you enforce matters too: at the load balancer, in a middleware layer, or in a dedicated service — each with different consistency guarantees.

---

## The Code
```python
# ── Token bucket — allows bursts up to bucket capacity ───────────────────
# Tokens refill at a fixed rate. Each request consumes one token.
# If bucket is empty, request is rejected. Burst-friendly.

import time
import threading

class TokenBucket:
    def __init__(self, capacity: int, refill_rate: float):
        """
        capacity:    max tokens (= max burst size)
        refill_rate: tokens added per second
        """
        self.capacity     = capacity
        self.refill_rate  = refill_rate
        self.tokens       = float(capacity)
        self.last_refill  = time.monotonic()
        self._lock        = threading.Lock()

    def allow(self) -> bool:
        with self._lock:
            now = time.monotonic()
            elapsed = now - self.last_refill
            # Add tokens earned since last check, up to capacity
            self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate)
            self.last_refill = now

            if self.tokens >= 1:
                self.tokens -= 1
                return True
            return False   # bucket empty — request rejected

# 10 req/s sustained, burst up to 50
limiter = TokenBucket(capacity=50, refill_rate=10)

for i in range(60):
    allowed = limiter.allow()
    print(f"Request {i+1:02d}: {'✓ allowed' if allowed else '✗ rejected'}")
```
```python
# ── Sliding window counter (Redis-backed, distributed) ────────────────────
# More accurate than fixed window. Practical for distributed systems.
# Uses two fixed windows (current + previous) weighted by overlap.

import redis
import time

r = redis.Redis(decode_responses=True)

def is_allowed(client_id: str, limit: int, window_s: int) -> bool:
    now         = time.time()
    window_start = int(now // window_s) * window_s   # current window start
    prev_start   = window_start - window_s            # previous window start

    curr_key = f"ratelimit:{client_id}:{window_start}"
    prev_key = f"ratelimit:{client_id}:{prev_start}"

    pipe = r.pipeline()
    pipe.incr(curr_key)
    pipe.expire(curr_key, window_s * 2)
    pipe.get(prev_key)
    curr_count, _, prev_count = pipe.execute()

    curr_count = int(curr_count)
    prev_count = int(prev_count or 0)

    # Weight previous window by how much of current window has elapsed
    elapsed_fraction = (now - window_start) / window_s
    weighted_count   = prev_count * (1 - elapsed_fraction) + curr_count

    return weighted_count <= limit

# 100 requests per 60-second window
for i in range(110):
    allowed = is_allowed("user:42", limit=100, window_s=60)
    if not allowed:
        print(f"Request {i+1}: rate limited")
        break
```
```python
# ── HTTP response headers — tell clients how to behave ────────────────────
from flask import Flask, request, jsonify, Response

app = Flask(__name__)

@app.route("/api/data")
def api_data():
    client_id = request.headers.get("X-API-Key", request.remote_addr)
    allowed   = is_allowed(client_id, limit=100, window_s=60)

    headers = {
        "X-RateLimit-Limit":     "100",
        "X-RateLimit-Remaining": "0" if not allowed else "...",
        "X-RateLimit-Reset":     str(int(time.time() // 60 + 1) * 60),
    }

    if not allowed:
        return Response(
            '{"error": "rate limit exceeded"}',
            status=429,                      # Too Many Requests — the correct status code
            headers={**headers, "Retry-After": "60"},
            mimetype="application/json"
        )

    return jsonify({"data": "..."})
```

---

## Gotchas
- **Fixed window allows 2× the intended rate at window boundaries.** If your limit is 100 requests per minute, a client can make 100 requests at 11:59:59 and 100 more at 12:00:00 — 200 requests in two seconds. Sliding window algorithms prevent this; fixed window is only acceptable when boundary bursts are not a safety concern.
- **IP-based rate limiting is easy to bypass and easy to over-apply.** Shared NAT (corporate offices, university networks, mobile carriers) routes thousands of users through one IP — rate limiting by IP bans all of them for one user's behavior. Always prefer authenticated identifiers (API key, user ID) when available.
- **Distributed rate limiting requires a shared store — and that store becomes a dependency.** A Redis-backed rate limiter that goes down either stops all traffic (if you fail closed) or allows unlimited traffic (if you fail open). Decide which failure mode is acceptable before the Redis incident happens.
- **Clients must handle 429 correctly — and many don't.** A client that retries immediately on a 429 makes the problem worse. Always include `Retry-After` headers and document expected client behavior. Exponential backoff with jitter is the correct client response.
- **Rate limiting is not the same as authentication.** Rate limiting an unauthenticated endpoint by IP doesn't stop a distributed attacker with many IPs. Defense-in-depth means rate limiting + CAPTCHA + anomaly detection + blocking at the network layer for real abuse scenarios.

---

## Interview Angle
**What they're really testing:** Whether you can design a rate limiter end-to-end — algorithm choice, data store, distributed consistency, and failure behavior — not just name the concept.

**Common question form:** "Design a rate limiter" — one of the most common system design interview questions.

**The depth signal:** A junior candidate describes what a rate limiter does and maybe names the token bucket. A senior candidate walks through: algorithm selection and trade-offs (token bucket for burst-friendly, sliding window for accuracy), client identification strategy (API key > user ID > IP, and why), data store choice (Redis with atomic Lua scripts or pipeline to avoid race conditions), failure mode decision (fail open vs closed, and the business reasoning for each), HTTP response semantics (429, Retry-After, X-RateLimit-* headers), and where to enforce (load balancer for unauthenticated endpoints, application middleware for per-user limits, API gateway for multi-service enforcement). The separation is: juniors describe a rate limiter, seniors design one with all the operational considerations.

---

## Related Topics
- [[system-design/load-balancing.md]] — Rate limiting is often enforced at the load balancer or API gateway layer.
- [[system-design/caching.md]] — Rate limit counters are typically stored in an in-memory cache (Redis).
- [[system-design/consistent-hashing.md]] — Distributing rate limit counter storage across a Redis cluster uses consistent hashing.

---

## Source
https://stripe.com/blog/rate-limiters

---
*Last updated: 2026-03-24*