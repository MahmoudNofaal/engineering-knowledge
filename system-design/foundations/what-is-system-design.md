# What Is System Design

> System design is the process of defining the architecture, components, and data flow of a software system to meet functional and non-functional requirements.

---

## When To Use It
Every time you build something that needs to scale, stay reliable, or serve more than one user, you're doing system design. It matters most when you're starting a new service, planning for growth, or debugging why something falls apart under load. You don't need it for a weekend script or a throwaway prototype — but the moment you're thinking about multiple services, databases, or real users, system design decisions have consequences you'll live with for years.

---

## Core Concept
System design is how you think through the big picture before writing code. Instead of jumping straight to implementation, you ask: what does this system need to do, how many people will use it, what happens when a piece breaks, and how does data move through it? The output isn't code — it's a set of decisions: what database to use, whether to split into microservices, how caching fits in, where the bottlenecks will be. Good system design means fewer nasty surprises in production.

---

## The Code

There's no single code block for system design itself — it's a thinking process. But here's what a basic design decision looks like when translated into structure:
```csharp
// Example: Choosing between sync vs async communication for two services

// SYNC — Service A waits for Service B to respond
// Use when: you need the result immediately
using System.Net.Http;

public async Task<Dictionary<string, object>> GetUserProfileAsync(string userId)
{
    using var client = new HttpClient();
    var response = await client.GetAsync($"http://user-service/users/{userId}");
    response.EnsureSuccessStatusCode();
    var json = await response.Content.ReadAsStringAsync();
    return JsonSerializer.Deserialize<Dictionary<string, object>>(json);
}

// ASYNC — Service A fires a message and moves on
// Use when: you don't need the result right now (e.g., send welcome email)
using Amazon.SQS;
using Amazon.SQS.Model;

public async Task TriggerWelcomeEmailAsync(string userId)
{
    var sqs = new AmazonSQSClient();
    var request = new SendMessageRequest
    {
        QueueUrl = "https://sqs.us-east-1.amazonaws.com/123/welcome-emails",
        MessageBody = userId
    };
    await sqs.SendMessageAsync(request);
}
```
```csharp
// Example: Back-of-napkin capacity estimation (a core system design skill)

long DAU = 10_000_000;          // daily active users
int reads_per_user = 20;        // average reads per day
int writes_per_user = 2;        // average writes per day

double read_rps = (DAU * reads_per_user) / 86_400.0;    // ~2,315 reads/sec
double write_rps = (DAU * writes_per_user) / 86_400.0;  // ~231 writes/sec

// This tells you: read-heavy system, cache aggressively, replicas matter more than write throughput
Console.WriteLine($"Read RPS:  {read_rps:F0}");
Console.WriteLine($"Write RPS: {write_rps:F0}");
```

---

## Gotchas
- **Scaling prematurely is a design mistake too.** Over-engineering for 10M users when you have 500 creates complexity that kills velocity and introduces failure points you don't need yet.
- **Non-functional requirements are the real constraints.** Latency SLAs, availability targets (99.9% ≠ 99.99%), and data consistency requirements should drive your architecture — most candidates skip straight to drawing boxes.
- **CAP theorem isn't a trivia question.** In practice, you're always choosing between consistency and availability during a partition. If you can't explain what your system sacrifices, you don't actually understand its design.
- **Single points of failure hide in plain sight.** A load balancer, a shared database, a third-party API — any unguarded dependency that takes down your whole system is a design flaw, not bad luck.
- **Data modeling decisions are the hardest to undo.** Choosing the wrong schema, the wrong database type, or the wrong partitioning key early on causes years of pain. More time should be spent here than on service diagrams.

---

## Interview Angle
**What they're really testing:** Whether you can translate vague requirements into concrete technical trade-offs — and whether you understand that every design choice has a cost.

**Common question form:** "Design Twitter / a URL shortener / a rate limiter / a notification system."

**The depth signal:** A junior answer draws boxes and names technologies ("we'll use Redis for caching, Kafka for events"). A senior answer starts by clarifying requirements — read/write ratio, consistency needs, scale targets — then explains *why* each technology was chosen and what it gives up. They call out failure modes unprompted: "if the cache goes down, here's what happens." They size the system with rough numbers before picking components. The separation is: juniors name tools, seniors justify trade-offs.

---

## Related Topics
- [[system-design/cap-theorem.md]] — The fundamental constraint that forces every distributed system design trade-off.
- [[system-design/caching-strategies.md]] — One of the first levers you pull when a system needs to scale reads.
- [[system-design/load-balancing.md]] — How traffic gets distributed and where single points of failure hide.
- [[databases/sql-vs-nosql.md]] — The earliest and most consequential data layer decision in any design.

---

## Source
https://github.com/donnemartin/system-design-primer

---
*Last updated: 2026-03-24*