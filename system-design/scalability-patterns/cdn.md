# CDN (Content Delivery Network)

> A geographically distributed network of servers that cache and serve content from locations physically close to the user.

---

## When To Use It
Any time you serve static assets (images, JS, CSS, fonts, videos) to users spread across geographies. Also useful for dynamic content acceleration and DDoS mitigation. Don't use a CDN as a substitute for a fast origin server — if your origin generates a page in 3 seconds, caching that page on a CDN helps repeat visitors but doesn't fix the underlying slowness.

---

## Core Concept
A CDN is a geographically distributed caching layer. When a user in Cairo requests an image, instead of routing that request to your origin server in Virginia (150ms round trip), it routes to a CDN edge node in Cairo (5ms round trip) that has the image cached. On a cache miss, the edge fetches from your origin, caches it locally, and serves it — subsequent requests from that region get the cached copy. The result: lower latency for users, lower bandwidth cost and load on your origin, and built-in redundancy. Modern CDNs also handle TLS termination at the edge, DDoS absorption, and increasingly, dynamic computation (edge functions).

---

## The Code
```python
# ── Cache-Control headers — the primary mechanism for CDN caching ─────────
# The CDN reads these headers to decide what to cache and for how long.

from flask import Flask, send_file, make_response

app = Flask(__name__)

@app.route("/static/logo.png")
def serve_logo():
    response = make_response(send_file("assets/logo.png"))
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    # public     → CDN is allowed to cache this (vs private = user-specific, no CDN cache)
    # max-age    → cache for 1 year (seconds)
    # immutable  → browser won't revalidate on reload; use only with content-hashed filenames
    return response

@app.route("/api/feed")
def serve_feed():
    response = make_response({"items": []})
    response.headers["Cache-Control"] = "public, max-age=30, stale-while-revalidate=60"
    # max-age=30            → serve from cache for 30s
    # stale-while-revalidate=60 → serve stale for 60s while fetching fresh in background
    return response

@app.route("/dashboard")
def serve_dashboard():
    response = make_response("<html>...</html>")
    response.headers["Cache-Control"] = "private, no-store"
    # private  → user-specific; CDN must NOT cache this
    # no-store → don't cache anywhere, not even the browser
    return response
```
```python
# ── CDN cache invalidation via API (Cloudflare example) ──────────────────
# When you deploy new assets, purge the old cached versions.

import httpx

def purge_cloudflare_cache(zone_id: str, api_token: str, urls: list[str]) -> dict:
    response = httpx.post(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache",
        headers={
            "Authorization": f"Bearer {api_token}",
            "Content-Type":  "application/json",
        },
        json={"files": urls},
    )
    return response.json()

# Usage: call this as part of your CI/CD deploy pipeline.
purge_cloudflare_cache(
    zone_id   = "abc123",
    api_token = "...",
    urls      = [
        "https://example.com/static/app.js",
        "https://example.com/static/style.css",
    ]
)
```
```python
# ── Content-hashed filenames — the right way to handle cache busting ──────
# Instead of purging, give each file version a unique URL.
# Old URL stays cached (safe). New URL is cache-miss (fresh).

import hashlib, pathlib

def content_hash_filename(filepath: str) -> str:
    content = pathlib.Path(filepath).read_bytes()
    digest  = hashlib.md5(content).hexdigest()[:8]
    stem    = pathlib.Path(filepath).stem
    suffix  = pathlib.Path(filepath).suffix
    return f"{stem}.{digest}{suffix}"

print(content_hash_filename("app.js"))   # → app.a3f2c1b4.js
# Set max-age=31536000, immutable on this URL.
# Next deploy produces app.9d1e7f2a.js — a different URL — zero cache invalidation needed.
```

---

## Gotchas
- **Dynamic content with user-specific data must never be cached at the CDN.** If a CDN caches a response containing `Hello, Alice` and serves it to Bob, that's a data breach. Always set `Cache-Control: private` or `no-store` on authenticated or user-specific responses — and verify this with a cache audit, not just intent.
- **CDN cache invalidation is slow and often incomplete.** Purging a URL from Cloudflare propagates across their edge network in seconds to minutes. During that window, some users still get stale content. Content-hashed filenames make purging irrelevant for static assets — use them instead of relying on purge APIs.
- **Cache-Control on the response ≠ what the CDN actually caches.** Many CDN configurations have override rules that ignore your headers. Always verify what's actually being cached with a `curl -I` to the CDN URL and checking the `cf-cache-status` or `x-cache` response header.
- **A CDN cache miss still hits your origin.** A cold CDN (new region, cache eviction, or low cache hit rate) is not a CDN problem — it's a traffic spike directly to your origin. Your origin must still be sized for realistic cache-miss traffic, not just CDN-absorbed traffic.
- **CDNs are not automatically DDoS protection.** CDNs absorb volumetric DDoS by distributing attack traffic across many edge nodes. But application-layer attacks (L7, slowloris, API abuse) still reach your origin unless you've explicitly configured WAF rules and rate limiting at the edge.

---

## Interview Angle
**What they're really testing:** Whether you understand the CDN as a system component with its own caching semantics, failure modes, and interaction with your application's deployment pipeline.

**Common question form:** "Design a video streaming service" or "How would you serve assets globally with low latency?"

**The depth signal:** A junior candidate says "use a CDN for static assets." A senior candidate explains cache-control header strategy (and the difference between `public`, `private`, and `immutable`), how they handle cache invalidation during deploys (content-hashed filenames > purge APIs), what happens to their origin during a CDN cold start, how they prevent user-specific data from leaking through the CDN cache, and how CDN fits into DDoS mitigation. They also mention edge functions for personalisation or A/B testing without losing cacheability. The separation is: juniors know CDNs cache things near users, seniors know exactly what gets cached, for how long, and what breaks when it goes wrong.

---

## Related Topics
- [[system-design/caching.md]] — CDN is caching at the network edge; the same invalidation and TTL concepts apply.
- [[system-design/load-balancing.md]] — CDN sits in front of load balancers in the full request path.
- [[system-design/latency-numbers.md]] — Geography-driven latency is the core problem CDNs solve.

---

## Source
https://web.dev/articles/content-delivery-networks

---
*Last updated: 2026-03-24*