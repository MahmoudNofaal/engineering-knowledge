# REST vs gRPC

> Two different protocols for building APIs — REST uses HTTP/JSON and is universally readable, gRPC uses HTTP/2 and binary serialization for high-performance service-to-service communication.

---

## When To Use It

Use REST when you're building public-facing APIs, need broad client compatibility, or want human-readable requests for easier debugging. Use gRPC when you're connecting internal microservices where latency and throughput matter, or when you need bidirectional streaming. Don't use gRPC for public APIs unless your clients can handle it — browser support is limited without a proxy layer. Don't use REST when you're making thousands of inter-service calls per second and payload size is a real cost.

---

## Core Concept

REST sends data as JSON over plain HTTP/1.1 — every field name travels as a string on every request. gRPC uses Protocol Buffers (protobuf) to define a schema upfront, then serializes messages into compact binary. The result is smaller payloads, faster parsing, and a strict contract both sides must agree to. gRPC also runs over HTTP/2, which means multiple calls can share one connection without blocking each other. The tradeoff is that you can't just curl a gRPC endpoint and read the response — you need generated client code and tooling on both ends.

---

## The Code

**REST — minimal API endpoint (ASP.NET Core)**
```csharp
// Controller receives JSON, returns JSON automatically
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public IActionResult GetOrder(int id)
    {
        var order = new { Id = id, Product = "Widget", Qty = 3 };
        return Ok(order); // serialized to JSON
    }
}
```

**gRPC — service definition (orders.proto)**
```protobuf
syntax = "proto3";

service OrderService {
  rpc GetOrder (OrderRequest) returns (OrderReply);
}

message OrderRequest {
  int32 id = 1;
}

message OrderReply {
  int32 id = 1;
  string product = 2;
  int32 qty = 3;
}
```

**gRPC — server implementation (ASP.NET Core)**
```csharp
public class OrderGrpcService : OrderService.OrderServiceBase
{
    public override Task<OrderReply> GetOrder(OrderRequest request, ServerCallContext context)
    {
        return Task.FromResult(new OrderReply
        {
            Id = request.Id,
            Product = "Widget",
            Qty = 3
        });
    }
}
```

**gRPC — calling from another service**
```csharp
var channel = GrpcChannel.ForAddress("https://order-service:5001");
var client = new OrderService.OrderServiceClient(channel);

var reply = await client.GetOrderAsync(new OrderRequest { Id = 42 });
Console.WriteLine(reply.Product);
```

---

## Gotchas

- **Browser clients can't call gRPC directly** without gRPC-Web and a proxy (like Envoy or YARP). If your frontend is a browser app, REST is still the practical choice unless you add that layer.
- **Protobuf schema changes are not free.** Removing or renumbering fields breaks existing clients silently — they just get zero values. Always add fields, never remove or reuse field numbers.
- **gRPC errors don't map to HTTP status codes.** You get gRPC status codes (`NOT_FOUND`, `UNAVAILABLE`, etc.) instead of 404/503. Monitoring and error handling need to account for this difference.
- **REST pagination and filtering have no standard.** Every team invents their own query param conventions (`?page=`, `?offset=`, `?cursor=`). gRPC doesn't solve this either, but at least the contract is explicit in the proto file.
- **gRPC streaming holds connections open.** Under a load balancer that terminates idle connections (common in cloud environments), long-lived streams will get silently dropped. You need keepalive settings configured on both client and server.

---

## Interview Angle

**What they're really testing:** Whether you understand protocol-level tradeoffs — serialization cost, connection multiplexing, schema enforcement — not just "REST is simple, gRPC is fast."

**Common question form:** "When would you choose gRPC over REST for an internal microservice?" or "What are the limitations of REST at scale?"

**The depth signal:** A junior says gRPC is faster because it uses binary. A senior explains *why* — protobuf avoids repeated field-name serialization, HTTP/2 multiplexing eliminates head-of-line blocking, and the generated client code enforces the contract at compile time rather than at runtime. A senior also flags where gRPC costs you: observability is harder (binary traces), browser clients need extra infrastructure, and schema evolution requires discipline to avoid silent breakage.

---

## Related Topics

- [[system-design/api-gateway.md]] — API gateways often translate between REST (external) and gRPC (internal), bridging both protocols at the edge
- [[system-design/microservices.md]] — gRPC is a common choice for inter-service communication in microservice architectures
- [[system-design/serialization-formats.md]] — Protobuf vs JSON vs MessagePack is the deeper story behind why gRPC is faster
- [[devops/service-mesh.md]] — Service meshes like Istio handle gRPC load balancing and observability that plain HTTP/2 makes tricky

---

## Source

https://grpc.io/docs/what-is-grpc/introduction/

---

*Last updated: 2026-03-24*