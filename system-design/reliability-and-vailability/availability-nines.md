# Availability Nines

> A shorthand for expressing how much uptime a system guarantees, measured as a percentage of total time in a year.

---

## When To Use It

Use availability targets to set concrete SLAs with customers, drive architectural decisions around redundancy, and define alerting thresholds. Every system that someone depends on needs an explicit availability target — without one, "reliable" means something different to every stakeholder. Don't chase five nines by default; the cost of each additional nine grows exponentially and most systems don't need it. Match your availability target to what the business actually requires and what you can afford to build.

---

## Core Concept

"Three nines" means 99.9% uptime — which sounds impressive until you realize it allows 8.7 hours of downtime per year. "Five nines" (99.999%) allows only 5.26 minutes per year. Each additional nine cuts the allowed downtime by roughly 10x. The reason this matters architecturally is that your total system availability is the product of all its dependencies. If Service A is 99.9% and calls Service B at 99.9%, the combined availability is 99.9% × 99.9% = 99.8%. Dependencies compound downward, which is why distributed systems are harder to keep available than monoliths — more moving parts, more multiplication.

---

## The Code

**Calculating availability from downtime incidents**
```csharp
public static double CalculateAvailability(
    TimeSpan totalPeriod,
    TimeSpan totalDowntime)
{
    var uptime = totalPeriod - totalDowntime;
    return uptime / totalPeriod * 100.0;
}

// Example: 43 minutes downtime in a 30-day month
var availability = CalculateAvailability(
    totalPeriod: TimeSpan.FromDays(30),
    totalDowntime: TimeSpan.FromMinutes(43)
);
// Result: 99.9% — exactly three nines
```

**Availability budget reference table**
```
| Nines | Availability | Downtime/Year  | Downtime/Month |
|-------|-------------|----------------|----------------|
| 99%   | Two nines   | 3.65 days      | 7.2 hours      |
| 99.9% | Three nines | 8.76 hours     | 43.8 minutes   |
| 99.95%| 3.5 nines   | 4.38 hours     | 21.9 minutes   |
| 99.99%| Four nines  | 52.6 minutes   | 4.38 minutes   |
|99.999%| Five nines  | 5.26 minutes   | 26.3 seconds   |
```

**Composite availability — dependency chain**
```csharp
// Availability degrades with every dependency you add
double[] dependencyAvailabilities = { 0.999, 0.999, 0.999 }; // three services

double composite = dependencyAvailabilities.Aggregate(1.0, (acc, a) => acc * a);
// composite = 0.997 → 99.7% — worse than any single service
Console.WriteLine($"Composite availability: {composite:P3}");
```

---

## Gotchas

- **Planned maintenance counts as downtime in most SLAs.** "We were deploying" is not a valid excuse unless your contract explicitly excludes maintenance windows. Zero-downtime deployments are a requirement at four nines and above, not a nice-to-have.
- **Your SLA can't exceed your dependencies' SLAs.** If you promise 99.99% but your cloud database provider guarantees only 99.9%, you're promising something you mathematically cannot deliver. Always check upstream SLAs before committing to customers.
- **Measuring availability is harder than calculating it.** You need to decide: available from where? From your load balancer? From a synthetic monitor in each region? A 200ms timeout that passes at the load balancer but fails for users in Southeast Asia is not "available" to those users.
- **Error budgets flip the framing.** Instead of "don't go down," think in terms of budget: 99.9% gives you 43 minutes per month to spend on incidents, deployments, and experiments. When the budget is exhausted, you stop risky deployments. This is how SRE teams operationalize availability targets.
- **Redundancy alone doesn't guarantee nines.** Active-passive failover with a 2-minute cutover costs you 2 minutes every time it triggers. At four nines you only have 4.38 minutes per month total. Failover time must be included in your availability model.

---

## Interview Angle

**What they're really testing:** Whether you understand that availability is a system-level property with real cost, not just a percentage you put in a contract.

**Common question form:** "How would you design a system for 99.99% availability?" or "What does high availability mean to you?"

**The depth signal:** A junior recites the nines table and says "add redundancy." A senior explains composite availability and how dependencies multiply downward, introduces error budgets as the operational mechanism for managing availability targets, specifies that failover time must be included in availability calculations (not just mean time between failures), and can describe the concrete architectural choices — active-active vs active-passive, regional redundancy, chaos testing — that correspond to specific availability targets and their associated costs.

---

## Related Topics

- [[system-design/fault-tolerance.md]] — availability is the goal; fault tolerance is the set of techniques used to achieve it
- [[system-design/health-checks.md]] — health checks are the mechanism that detects downtime and triggers failover
- [[system-design/chaos-engineering.md]] — the only way to validate your availability claims before an incident proves them wrong

---

## Source

https://sre.google/sre-book/embracing-risk/

---

*Last updated: 2026-03-24*