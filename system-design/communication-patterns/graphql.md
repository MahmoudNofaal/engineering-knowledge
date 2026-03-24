# GraphQL

> A query language for APIs where the client specifies exactly what data it needs, instead of the server deciding what to return.

---

## When To Use It

Use GraphQL when clients have genuinely different data needs — mobile apps needing less than web, dashboards composing data from multiple entities. It shines when over-fetching and under-fetching are real pain points. Don't use it for simple CRUD APIs where REST is perfectly adequate — you'll pay the complexity cost without the benefit. Avoid it when your team has no experience with it and the deadline is short; the tooling and mental model take time to internalize.

---

## Core Concept

With REST, the server owns the shape of the response. With GraphQL, the client sends a query describing exactly the fields it wants, and the server returns only those fields — nothing more. There's a single endpoint (usually `/graphql`) and a schema that defines every type and operation available. Queries are for reading, mutations for writing, and subscriptions for real-time updates. On the server, each field in the schema is backed by a resolver function — a small function responsible for fetching that specific piece of data.

---

## The Code

**Schema definition**
```graphql
type Order {
  id: ID!
  product: String!
  qty: Int!
  customer: Customer!
}

type Customer {
  id: ID!
  name: String!
}

type Query {
  order(id: ID!): Order
}
```

**Client query — ask only for what you need**
```graphql
query {
  order(id: "42") {
    product
    qty
    customer {
      name
    }
  }
}
```

**Resolver implementation (ASP.NET Core with Hot Chocolate)**
```csharp
public class QueryType : ObjectType
{
    protected override void Configure(IObjectTypeDescriptor descriptor)
    {
        descriptor.Field("order")
            .Argument("id", a => a.Type<IdType>())
            .Resolve(ctx =>
            {
                var id = ctx.ArgumentValue<string>("id");
                return new Order { Id = id, Product = "Widget", Qty = 3 };
            });
    }
}
```

**Mutation — write operation**
```graphql
mutation {
  createOrder(product: "Widget", qty: 3) {
    id
    product
  }
}
```

---

## Gotchas

- **The N+1 problem will hit you immediately.** If you fetch a list of orders and each order resolves its customer separately, you make one DB call for orders and N calls for customers. Use a DataLoader to batch these into a single query.
- **Authorization is per-resolver, not per-endpoint.** REST lets you protect routes at the middleware level. In GraphQL, a user can query any field they can reach in the schema — you must check permissions inside each resolver or use a directive-based approach.
- **Caching is non-trivial.** REST caches at the HTTP level using URL + method. GraphQL uses POST for all queries, so HTTP caching doesn't apply by default. You need persisted queries or client-side caching (Apollo Client, etc.).
- **Schema changes require coordination.** Removing a field breaks any client using it with no warning at the protocol level. Use deprecation directives and give clients a migration window before removing anything.
- **File uploads are not part of the spec.** Uploading files through GraphQL requires a multipart request convention that isn't standardized — most clients and servers implement it differently.

---

## Interview Angle

**What they're really testing:** Whether you understand the client-driven data model and the architectural consequences — not just the syntax.

**Common question form:** "When would you choose GraphQL over REST?" or "What problems does GraphQL solve and what does it introduce?"

**The depth signal:** A junior says GraphQL avoids over-fetching. A senior explains the N+1 resolver problem and DataLoader as the standard fix, explains why HTTP caching breaks and what persisted queries do about it, and articulates that GraphQL shifts complexity from the server to the schema layer — meaning schema design and access control require more discipline than with REST.

---

## Related Topics

- [[system-design/rest-vs-grpc.md]] — REST and gRPC are the main alternatives; understanding all three lets you make the right call per use case
- [[system-design/api-gateway.md]] — API gateways can expose a GraphQL facade over multiple REST or gRPC backends
- [[databases/query-optimization.md]] — N+1 is a database problem at its core; understanding query cost matters when writing resolvers

---

## Source

https://graphql.org/learn/

---

*Last updated: 2026-03-24*