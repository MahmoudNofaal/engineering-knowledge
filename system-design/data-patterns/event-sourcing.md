# Event Sourcing

> Instead of storing the current state of an entity, store the full sequence of events that led to that state — and derive current state by replaying them.

---

## When To Use It

Use event sourcing when audit history is a first-class requirement, when you need to reconstruct past states of an entity, or when multiple downstream systems need to react to changes in your domain. It's a strong fit for financial systems, inventory tracking, and collaborative tools. Don't use it for simple CRUD services where you just need the latest value — the operational complexity is not worth it. It pairs naturally with CQRS but doesn't require it.

---

## Core Concept

In a normal database, when an order is shipped you update the `status` column to `shipped` and the previous value is gone. In event sourcing, you never update — you append an `OrderShipped` event to the event log. The current state is always derived by replaying all events for that entity from the beginning (or from a snapshot). This means you have a complete, immutable history of everything that ever happened. The trade-off is that reads become more expensive (you have to replay), and the system is fundamentally harder to reason about when you're used to traditional CRUD. Snapshots exist to avoid replaying thousands of events on every read.

---

## The Code

### Appending events (the write side)
```csharp
public record OrderEvent(Guid OrderId, string Type, string Payload, DateTime OccurredAt);

public class OrderEventStore
{
    private readonly List<OrderEvent> _store = new(); // replace with DB in production

    public void Append(Guid orderId, string eventType, string payload)
    {
        _store.Add(new OrderEvent(orderId, eventType, payload, DateTime.UtcNow));
    }
}

// Usage
store.Append(orderId, "OrderPlaced",   """{"customerId": 42, "total": 199.99}""");
store.Append(orderId, "OrderShipped",  """{"carrier": "DHL", "trackingId": "XYZ"}""");
store.Append(orderId, "OrderDelivered","""{"deliveredAt": "2026-03-24"}""");
```

### Rebuilding state by replaying events
```csharp
public class Order
{
    public Guid Id { get; private set; }
    public string Status { get; private set; } = "None";
    public decimal Total { get; private set; }

    public static Order Replay(IEnumerable<OrderEvent> events)
    {
        var order = new Order();
        foreach (var e in events)
        {
            order.Apply(e); // each event mutates state forward
        }
        return order;
    }

    private void Apply(OrderEvent e)
    {
        switch (e.Type)
        {
            case "OrderPlaced":
                Status = "Placed";
                // parse Total from e.Payload
                break;
            case "OrderShipped":
                Status = "Shipped";
                break;
            case "OrderDelivered":
                Status = "Delivered";
                break;
        }
    }
}
```

### Snapshot to avoid full replay
```csharp
// Every N events, save a snapshot of current state
// On load: fetch latest snapshot + only events after it
public record OrderSnapshot(Guid OrderId, string Status, decimal Total, int LastEventIndex);
```

---

## Gotchas

- **Events are immutable — you can never fix a bug by editing them** — if you published a wrong event, you have to publish a correcting event. This is philosophically correct but operationally surprising the first time it happens in production.
- **Schema evolution is painful** — if `OrderPlaced` gains a new required field six months in, you must handle old events that don't have it during replay. Upcasting or versioned event types are required strategies.
- **Replay time grows unbounded without snapshots** — an entity with 50,000 events takes real time to replay on every read. Snapshots are not optional at scale; plan for them from the start.
- **Eventual consistency is the default** — read models are projections built asynchronously from the event stream. There will be a lag between writing an event and it appearing in queries.
- **Debugging is harder** — current state isn't directly visible in the database. You need tooling to replay and inspect state, otherwise production incidents become archaeology exercises.

---

## Interview Angle

**What they're really testing:** Whether you understand immutable audit logs, the trade-offs of append-only systems, and how event sourcing enables temporal queries and system decoupling.

**Common question form:** "How would you design a system where you can see the full history of any order?" or "Walk me through event sourcing and when you'd use it."

**The depth signal:** A junior describes event sourcing as "saving a log of actions." A senior explains the replay mechanism, discusses snapshot strategies, talks about event schema versioning, mentions the CQRS pairing and why it's natural, and can articulate specific scenarios where traditional CRUD would be simpler and event sourcing would be overkill.

---

## Related Topics

- [[system-design/change-data-capture.md]] — CDC is a way to stream changes out of a traditional database; event sourcing makes those changes explicit from the start.
- [[system-design/denormalization.md]] — Read projections in event sourcing are a form of intentional denormalization built from the event stream.
- [[system-design/cqrs.md]] — Command Query Responsibility Segregation is the natural architectural pair for event sourcing.

---

## Source

https://martinfowler.com/eaaDev/EventSourcing.html

---

*Last updated: 2026-03-24*