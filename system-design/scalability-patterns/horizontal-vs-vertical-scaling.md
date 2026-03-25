# Horizontal vs Vertical Scaling

> Two strategies for handling more load — vertical adds resources to one machine, horizontal adds more machines.

---

## When To Use It
Every system eventually hits its capacity ceiling. Vertical scaling is the first instinct — it's simpler and requires no code changes. Horizontal scaling becomes necessary when you've hit the hardware ceiling, need fault tolerance, or require geographic distribution. The real question isn't which one, it's which one first, and at what point does the cost/complexity of horizontal scaling become worth it.

---

## Core Concept
Vertical scaling (scale up) means giving your existing server more CPU, RAM, or faster storage. You hit a wall: there's a maximum size machine money can buy, and a bigger machine is a bigger single point of failure. Horizontal scaling (scale out) means running multiple smaller servers and distributing load across them. This removes the hardware ceiling and adds redundancy, but introduces a new class of problems: how do you route traffic, share state, and keep data consistent across instances? Stateless services scale horizontally almost for free. Stateful services — anything that holds data on the machine — are hard to scale horizontally and usually require a rethinking of where state lives.

---

## The Code
```csharp
// ── Vertical scaling: same server, bigger resources ───────────────────────
// No code change needed. But here's what the limit looks like:

var verticalLimits = new Dictionary<string, object>
{
    { "max_cpu_cores",    "~192 cores (AWS u-24tb1.metal)" },
    { "max_ram",          "~24 TB (high-memory instances)" },
    { "max_network",      "~400 Gbps" },
    { "max_nvme_iops",    "~3.8M IOPS (io2 Block Express)" },
    { "single_point_of_failure", true },    // one machine, one failure domain
    { "cost_scaling",     "superlinear — 2x resources costs >2x" },
};

// ── Horizontal scaling: more servers, distributed load ────────────────────
// Requires: stateless services, external session/cache, shared storage

var horizontalRequirements = new Dictionary<string, object>
{
    { "stateless_app_tier",    true },   // no local session state
    { "external_session_store", "Redis / DynamoDB" },
    { "shared_file_storage",    "S3 / EFS / NFS" },
    { "load_balancer",          "required to distribute traffic" },
    { "service_discovery",      "required for services to find each other" },
    { "distributed_tracing",    "required to debug across nodes" },
};
```
```csharp
// ── Detecting when vertical scaling is failing ────────────────────────────
using System;
using System.Diagnostics;

public Dictionary<string, object> ScalingPressureReport()
{
    var cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
    float cpuPct = cpuCounter.NextValue();

    var ramCounter = new PerformanceCounter("Memory", "Available MBytes");
    float ramAvailableGb = ramCounter.NextValue() / 1024f;
    var ramTotalCounter = new PerformanceCounter("Memory", "Committed Bytes");
    float ramUsedPct = (ramTotalCounter.NextValue() / 1024f / 1024f) / 100f;

    string recommendation = cpuPct > 85 ? "Scale up: CPU bottleneck, add cores" :
                           ramUsedPct > 90 ? "Scale up: RAM bottleneck, add memory" :
                           "Current resources adequate";

    return new Dictionary<string, object>
    {
        { "cpu_utilization_pct", cpuPct },
        { "ram_available_gb", ramAvailableGb },
        { "recommendation", recommendation }
    };
}

var report = ScalingPressureReport();
Console.WriteLine($"CPU: {report["cpu_utilization_pct"]}%, Recommendation: {report["recommendation"]}");
// When "scale up" keeps appearing but you're already on the biggest
// available instance → time to rearchitect for horizontal scaling.
```
```csharp
// ── Stateless service: safe to scale horizontally ─────────────────────────
// All state is externalized — any instance can handle any request

using StackExchange.Redis;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

public class UserController : ControllerBase
{
    private readonly IDatabase _redisCache;

    public UserController(IConnectionMultiplexer redis)
    {
        _redisCache = redis.GetDatabase();
    }

    [HttpGet("/user/{userId}")]
    public IActionResult GetUser(string userId)
    {
        // State lives in Redis, not in this process's memory.
        // Adding 10 more instances of this service needs zero code change.
        var cached = _redisCache.StringGet($"user:{userId}");
        if (cached.HasValue)
        {
            return Ok(new { source = "cache", data = cached.ToString() });
        }
        // ... fetch from DB, populate cache, return result
        return Ok(new { source = "db", data = $"user_{userId}_data" });
    }
}
```

---

## Gotchas
- **Vertical scaling has superlinear cost.** A machine with 2x the RAM doesn't cost 2x — it often costs 3–4x. At a certain point, running three mid-tier machines is cheaper than one top-tier machine and also more resilient.
- **Horizontal scaling doesn't fix a slow algorithm.** Adding servers to a system with an O(n²) hot path just means the O(n²) problem runs on more machines simultaneously. Profile before scaling.
- **Session state is the most common horizontal scaling blocker.** Applications that store session data in local memory break the moment a second instance is added and a user's next request lands on a different server. Sticky sessions are a band-aid, not a fix.
- **Database horizontal scaling is categorically harder than app tier scaling.** Stateless web servers scale out trivially. Databases have consistency and coordination requirements that make horizontal scaling a full architectural project — not a configuration change.
- **You can't always undo vertical scaling quickly.** Migrating to a smaller instance class is disruptive. Choosing the right vertical size early avoids emergency rescaling during an incident.

---

## Interview Angle
**What they're really testing:** Whether you understand the operational and architectural implications of scale decisions, not just that "you can add more servers."

**Common question form:** "Your service is getting slow under load. How do you scale it?" or "Walk me through how you'd handle 10x traffic growth."

**The depth signal:** A junior answer says "I'd add more servers" or "I'd scale horizontally." A senior answer asks what's bottlenecked first — "Is it CPU, memory, I/O, or network? Is the bottleneck in the app tier or the database? If it's the app tier and it's stateless, horizontal scaling is straightforward — add instances behind the load balancer. If there's session state, we need to externalize it to Redis first. If the database is the bottleneck, scaling the app tier does nothing — we need read replicas, caching, or sharding depending on whether it's read or write pressure." The separation is: juniors name a scaling strategy, seniors diagnose before prescribing.

---

## Related Topics
- [[system-design/load-balancing.md]] — Required to distribute traffic across horizontally scaled instances.
- [[system-design/database-scaling.md]] — Why scaling the data layer is a separate and harder problem.
- [[system-design/caching.md]] — The primary tool to reduce load before scaling becomes necessary.

---

## Source
https://aws.amazon.com/blogs/architecture/scale-your-web-application-one-step-at-a-time/

---
*Last updated: 2026-03-24*