---
id: "7.248"
title: "Throttling vs Rate Limiting — Differences"
domain: "System Design & Distributed Systems"
domain_id: 7
group: "Scalability Patterns"
tags: [system-design, distributed-systems, scalability, dotnet, azure, throttling, rate-limiting, traffic-management, api-design]
priority: 2
prerequisites:
  - "[[7.241 — Rate Limiting — Token Bucket Algorithm]] — rate limiting is the core mechanism; throttling is an alternative control strategy"
  - "[[7.242 — Rate Limiting — Leaky Bucket Algorithm]] — leaky bucket can serve both: rate limiting (overflow reject) and throttling (smooth output via queue)"
  - "[[7.247 — Rate Limiting — ASP.NET Core RateLimiterMiddleware]] — ASP.NET Core middleware does rate limiting (reject); throttling needs a different approach"
related:
  - "[[7.241 — Rate Limiting — Token Bucket Algorithm]] — most common algorithm for rate limiting (reject); less common for throttling"
  - "[[7.242 — Rate Limiting — Leaky Bucket Algorithm]] — uniquely suited for throttling (built-in queue + drain); can also rate-limit"
  - "[[7.247 — Rate Limiting — ASP.NET Core RateLimiterMiddleware]] — does not support throttling natively; the distinction matters when choosing middleware"
  - "[[7.243 — Rate Limiting — Fixed Window Counter]] — rate limiting only (reject at boundary); useless for throttling"
  - "[[7.220 — Queue-Based Load Leveling]] — throttling is often implemented via queue-based load leveling; rate limiting rejects instead"
  - "[[7.238 — Backpressure — Detection and Handling]] — throttling is a form of backpressure; rate limiting is a hard backpressure signal"
  - "[[4.142 — API Versioning and Rate Limiting Strategy]] — choosing between throttling and rate limiting depends on client type and API contract"
created: 2026-06-17
---

## Navigation

**Domain:** [[7 — System Design & Distributed Systems]] > **Group:** Scalability Patterns
**Previous:** [[7.247 — Rate Limiting — ASP.NET Core RateLimiterMiddleware]] | **Next:** — (last in rate limiting sequence)

### Prerequisites

- [[7.241 — Rate Limiting — Token Bucket Algorithm]] — rate limiting is the core mechanism; throttling is an alternative control strategy
- [[7.242 — Rate Limiting — Leaky Bucket Algorithm]] — leaky bucket can serve both: rate limiting (overflow reject) and throttling (smooth output via queue)
- [[7.247 — Rate Limiting — ASP.NET Core RateLimiterMiddleware]] — ASP.NET Core middleware does rate limiting (reject); throttling needs a different approach

### Where This Fits

Throttling and rate limiting are two strategies for controlling request flow, and engineers frequently use the terms interchangeably — but they produce different client experiences and have different architectural implications. **Rate limiting rejects** excess requests with a clear signal (HTTP 429). **Throttling delays** or degrades excess requests without rejecting them — the client still gets a response, just slower or reduced quality. A .NET engineer encounters this distinction when choosing how to protect an API: does a free-tier client get a 429 or a 1-second delay? The choice affects client SDK design, user experience, and downstream load patterns. It becomes relevant whenever the team designs a consumer-facing API with tiered access, or when they must decide between the ASP.NET Core RateLimiterMiddleware (rate limiting only) and a custom queue-based approach (throttling).

---
