# Domain 7 — System Design & Distributed Systems

## Phonebook — Part 1 of 2 (Topics 7.001 – 7.955)

**1,355 topics across 33 groups.** Priority 1 = Critical → Priority 4 = Reference | `[ ]` = not generated | `[x]` = generated

---

## Group A — Clean Architecture and Layering (7.001–7.030)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.001|Clean Architecture — The Dependency Rule|1|[ ]|
|7.002|Clean Architecture — Domain Layer Structure|1|[ ]|
|7.003|Clean Architecture — Application Layer — Use Cases|1|[ ]|
|7.004|Clean Architecture — Infrastructure Layer|1|[ ]|
|7.005|Clean Architecture — Presentation Layer|2|[ ]|
|7.006|Clean Architecture — Cross-Cutting Concerns|2|[ ]|
|7.007|Clean Architecture — Dependency Injection Wiring|2|[ ]|
|7.008|Clean Architecture — Testing Strategy per Layer|2|[ ]|
|7.009|Clean Architecture — Mapping Between Layers|2|[ ]|
|7.010|Clean Architecture — Result Pattern for Cross-Layer Errors|2|[ ]|
|7.011|Hexagonal Architecture — Ports and Adapters|2|[ ]|
|7.012|Hexagonal Architecture — Primary vs Secondary Adapters|2|[ ]|
|7.013|Onion Architecture — Comparison with Clean Architecture|3|[ ]|
|7.014|Vertical Slice Architecture — Features as Slices|2|[ ]|
|7.015|Vertical Slice Architecture — MediatR per Slice|2|[ ]|
|7.016|Vertical Slice Architecture — When to Choose Over Layered|2|[ ]|
|7.017|Modular Monolith — Internal Module Boundaries|1|[ ]|
|7.018|Modular Monolith — Inter-Module Communication|2|[ ]|
|7.019|Modular Monolith — Shared Kernel vs Separate Data|2|[ ]|
|7.020|Modular Monolith — Migration Path to Microservices|2|[ ]|
|7.021|Strangler Fig Pattern — Migrating Legacy Systems|2|[ ]|
|7.022|Anti-Corruption Layer — Protecting Domain from Legacy|2|[ ]|
|7.023|Shared Kernel — What to Share and What Not To|3|[ ]|
|7.024|Open Host Service Pattern|3|[ ]|
|7.025|Rich Domain Model vs Anemic Domain Model|2|[ ]|
|7.026|Layer Violation — Detection and Prevention|3|[ ]|
|7.027|Architecture Fitness Functions for Layering|3|[ ]|
|7.028|Feature Modules — Organization Strategy|3|[ ]|
|7.029|Aspect-Oriented Cross-Cutting Concerns|3|[ ]|
|7.030|Architecture Anti-Patterns — Big Ball of Mud|2|[ ]|

---

## Group B — Domain-Driven Design (7.031–7.080)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.031|DDD — Strategic vs Tactical Design|1|[ ]|
|7.032|DDD — Ubiquitous Language — Building and Maintaining|1|[ ]|
|7.033|DDD — Bounded Contexts — Identifying Boundaries|1|[ ]|
|7.034|DDD — Bounded Contexts — Context Map|1|[ ]|
|7.035|DDD — Context Mapping — Partnership|2|[ ]|
|7.036|DDD — Context Mapping — Shared Kernel|2|[ ]|
|7.037|DDD — Context Mapping — Customer-Supplier|2|[ ]|
|7.038|DDD — Context Mapping — Conformist|2|[ ]|
|7.039|DDD — Context Mapping — Anticorruption Layer|2|[ ]|
|7.040|DDD — Context Mapping — Open Host Service|2|[ ]|
|7.041|DDD — Context Mapping — Published Language|2|[ ]|
|7.042|DDD — Context Mapping — Separate Ways|3|[ ]|
|7.043|DDD — Entities — Identity and Lifecycle|1|[ ]|
|7.044|DDD — Entities — Invariant Enforcement|2|[ ]|
|7.045|DDD — Value Objects — Equality and Immutability|1|[ ]|
|7.046|DDD — Value Objects — C# Records Implementation|2|[ ]|
|7.047|DDD — Aggregates — Consistency Boundary|1|[ ]|
|7.048|DDD — Aggregates — Aggregate Root Rule|1|[ ]|
|7.049|DDD — Aggregates — Size Heuristics|2|[ ]|
|7.050|DDD — Aggregates — Cross-Aggregate References|2|[ ]|
|7.051|DDD — Domain Services — Stateless Operations|2|[ ]|
|7.052|DDD — Application Services — Orchestration|2|[ ]|
|7.053|DDD — Domain Events — Within Bounded Context|2|[ ]|
|7.054|DDD — Domain Events — MediatR INotification in .NET|2|[ ]|
|7.055|DDD — Integration Events — Across Bounded Contexts|2|[ ]|
|7.056|DDD — Repositories — Interface and Implementation|2|[ ]|
|7.057|DDD — Repositories — EF Core Implementation|2|[ ]|
|7.058|DDD — Repositories — Unit of Work Pattern|2|[ ]|
|7.059|DDD — Specifications — Composable Query Logic|2|[ ]|
|7.060|DDD — Specifications — EF Core Implementation|3|[ ]|
|7.061|DDD — Factories — Complex Object Creation|3|[ ]|
|7.062|DDD — Subdomains — Core, Supporting, Generic|2|[ ]|
|7.063|DDD — Domain Primitives — Solving Primitive Obsession|2|[ ]|
|7.064|DDD — Persisting Value Objects — EF Core Owned Entities|2|[ ]|
|7.065|DDD — Eventual Consistency Between Aggregates|2|[ ]|
|7.066|DDD — Sagas as Process Managers|2|[ ]|
|7.067|DDD — Policy Objects|3|[ ]|
|7.068|DDD — Testing Domain Logic — Unit Tests for Aggregates|2|[ ]|
|7.069|DDD — Multiple Bounded Contexts in One Solution|2|[ ]|
|7.070|DDD — Event Storming — Discovery Workshop|3|[ ]|
|7.071|DDD — Common DDD Mistakes and Anti-Patterns|2|[ ]|
|7.072|DDD — Domain Event Handling — Sync vs Async|2|[ ]|
|7.073|DDD — Tactical Patterns — Full .NET Reference|2|[ ]|
|7.074|DDD — Module vs Bounded Context|3|[ ]|
|7.075|DDD — Strategic Design in a Legacy Codebase|3|[ ]|
|7.076|DDD — Aggregate Versioning — Optimistic Concurrency|2|[ ]|
|7.077|DDD — Read-Side Projections from Domain Events|2|[ ]|
|7.078|DDD — Infrastructure Concerns — Keeping Domain Pure|2|[ ]|
|7.079|DDD — Comparison with CRUD Architecture|2|[ ]|
|7.080|DDD — When DDD Is NOT the Right Choice|2|[ ]|

---

## Group C — CQRS and Event Sourcing (7.081–7.120)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.081|CQRS — Command Query Responsibility Segregation|1|[ ]|
|7.082|CQRS — Commands vs Queries — Strict Separation|1|[ ]|
|7.083|CQRS — Separate Read and Write Models|1|[ ]|
|7.084|CQRS — MediatR — IRequest and IRequestHandler|1|[ ]|
|7.085|CQRS — MediatR Pipeline Behaviors Overview|1|[ ]|
|7.086|CQRS — Validation Behavior — FluentValidation|2|[ ]|
|7.087|CQRS — Logging Pipeline Behavior|2|[ ]|
|7.088|CQRS — Caching Pipeline Behavior|2|[ ]|
|7.089|CQRS — Transaction Pipeline Behavior|2|[ ]|
|7.090|CQRS — Thin vs Thick Commands|2|[ ]|
|7.091|CQRS — Read Model Design — Denormalized Views|2|[ ]|
|7.092|CQRS — Synchronous vs Asynchronous Commands|2|[ ]|
|7.093|CQRS — Without Event Sourcing|2|[ ]|
|7.094|CQRS — With Event Sourcing|2|[ ]|
|7.095|CQRS — When It Adds Value vs Complexity|2|[ ]|
|7.096|CQRS — Read Side — Projections in .NET|2|[ ]|
|7.097|CQRS — Write Side — Transactional Boundary|2|[ ]|
|7.098|CQRS — Eventual Read Consistency — API Handling|2|[ ]|
|7.099|CQRS — Testing Commands and Queries Separately|2|[ ]|
|7.100|CQRS — Anti-Patterns and Over-Engineering|2|[ ]|
|7.101|Event Sourcing — Events as the Source of Truth|1|[ ]|
|7.102|Event Sourcing — Event Store Design|2|[ ]|
|7.103|Event Sourcing — Event Envelope Pattern|2|[ ]|
|7.104|Event Sourcing — Projections — Building Read Models|2|[ ]|
|7.105|Event Sourcing — Projections — Live vs Replay|2|[ ]|
|7.106|Event Sourcing — Snapshots — Performance Optimization|2|[ ]|
|7.107|Event Sourcing — Event Replay — Full and Partial|2|[ ]|
|7.108|Event Sourcing — Temporal Queries — Point-in-Time|2|[ ]|
|7.109|Event Sourcing — Event Versioning — Upcasting|2|[ ]|
|7.110|Event Sourcing — Event Versioning — Weak Schema|3|[ ]|
|7.111|Event Sourcing — When to Use|2|[ ]|
|7.112|Event Sourcing — When NOT to Use|2|[ ]|
|7.113|Event Sourcing — EventStoreDB|3|[ ]|
|7.114|Event Sourcing — Marten in .NET|3|[ ]|
|7.115|Event Sourcing — Aggregate Rehydration|2|[ ]|
|7.116|Event Sourcing — Optimistic Concurrency|2|[ ]|
|7.117|Event Sourcing — Testing Event-Sourced Aggregates|2|[ ]|
|7.118|Event Sourcing — Debugging and Auditability|2|[ ]|
|7.119|Event Sourcing — Multi-Tenant Design|3|[ ]|
|7.120|Event Sourcing — Integration with Message Brokers|2|[ ]|

---

## Group D — Integration Patterns (7.121–7.155)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.121|Outbox Pattern — Reliable Event Publishing|1|[ ]|
|7.122|Outbox Pattern — EF Core Implementation|2|[ ]|
|7.123|Outbox Pattern — Polling Publisher|2|[ ]|
|7.124|Outbox Pattern — Change Data Capture Approach|2|[ ]|
|7.125|Outbox Pattern — Idempotent Publishing|2|[ ]|
|7.126|Inbox Pattern — Idempotent Message Consumption|2|[ ]|
|7.127|Inbox Pattern — Deduplication Table|2|[ ]|
|7.128|Transactional Messaging — Guarantees|2|[ ]|
|7.129|Saga Pattern — Overview and When to Use|1|[ ]|
|7.130|Saga Pattern — Choreography-Based|2|[ ]|
|7.131|Saga Pattern — Orchestration-Based|2|[ ]|
|7.132|Saga Pattern — Compensating Transactions|2|[ ]|
|7.133|Saga Pattern — MassTransit Implementation|2|[ ]|
|7.134|Saga Pattern — Failure Handling and Recovery|2|[ ]|
|7.135|Change Data Capture — Concept and Use Cases|2|[ ]|
|7.136|Change Data Capture — Debezium Architecture|2|[ ]|
|7.137|Change Data Capture — SQL Server CDC|2|[ ]|
|7.138|Change Data Capture — PostgreSQL Logical Replication|3|[ ]|
|7.139|Change Data Capture — MySQL Binlog|4|[ ]|
|7.140|Request-Reply Pattern over Async Messaging|2|[ ]|
|7.141|Correlation ID Pattern — Cross-Service Tracing|2|[ ]|
|7.142|Event-Driven Architecture — Overview|1|[ ]|
|7.143|Event-Driven Architecture — Event Notification|2|[ ]|
|7.144|Event-Driven Architecture — Event-Carried State Transfer|2|[ ]|
|7.145|Competing Consumers Pattern|2|[ ]|
|7.146|Priority Queue Pattern — Tiered Processing|2|[ ]|
|7.147|Claim Check Pattern — Large Message Handling|2|[ ]|
|7.148|Pipes and Filters Pattern|3|[ ]|
|7.149|Scatter-Gather Pattern|3|[ ]|
|7.150|Process Manager Pattern|3|[ ]|
|7.151|Anti-Corruption Layer — Implementation|2|[ ]|
|7.152|Poison Message Handling|2|[ ]|
|7.153|Message Schema Evolution — Versioning Strategies|2|[ ]|
|7.154|Dead Letter Queue — Processing Strategies|2|[ ]|
|7.155|Message Ordering Guarantees — Patterns|2|[ ]|

---

## Group E — Distributed Systems Theory (7.156–7.205)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.156|CAP Theorem — Statement and Proof|1|[ ]|
|7.157|CAP Theorem — CP Systems — Examples|1|[ ]|
|7.158|CAP Theorem — AP Systems — Examples|1|[ ]|
|7.159|CAP Theorem — Common Misunderstandings|2|[ ]|
|7.160|PACELC — Extending CAP with Latency|2|[ ]|
|7.161|Consistency Models — Strong Consistency|1|[ ]|
|7.162|Consistency Models — Eventual Consistency|1|[ ]|
|7.163|Consistency Models — Causal Consistency|2|[ ]|
|7.164|Consistency Models — Read-Your-Writes|2|[ ]|
|7.165|Consistency Models — Monotonic Reads|2|[ ]|
|7.166|Consistency Models — Monotonic Writes|2|[ ]|
|7.167|Consistency Models — Session Guarantees|2|[ ]|
|7.168|Linearizability — Definition and Guarantees|2|[ ]|
|7.169|Serializability — vs Linearizability|2|[ ]|
|7.170|Snapshot Isolation — MVCC Mechanism|2|[ ]|
|7.171|Consensus — What Problems Require It|1|[ ]|
|7.172|Consensus — Raft — Leader Election|2|[ ]|
|7.173|Consensus — Raft — Log Replication|2|[ ]|
|7.174|Consensus — Raft — Safety and Liveness|2|[ ]|
|7.175|Consensus — Paxos — Conceptual Overview|3|[ ]|
|7.176|Leader Election — Algorithms and Patterns|2|[ ]|
|7.177|Leader Election — Bully Algorithm|3|[ ]|
|7.178|Leader Election — Ring Algorithm|3|[ ]|
|7.179|Distributed Clocks — Physical vs Logical|2|[ ]|
|7.180|Lamport Timestamps|2|[ ]|
|7.181|Vector Clocks|2|[ ]|
|7.182|Hybrid Logical Clocks|3|[ ]|
|7.183|Distributed Transactions — Two-Phase Commit|1|[ ]|
|7.184|Distributed Transactions — 3PC Problems|2|[ ]|
|7.185|Distributed Transactions — 2PC Failure Modes|2|[ ]|
|7.186|Distributed Transactions — Sagas as Alternative|1|[ ]|
|7.187|Idempotency — Design for Retry Safety|1|[ ]|
|7.188|Idempotency — Idempotency Key Pattern|2|[ ]|
|7.189|Idempotency — Natural vs Synthetic|2|[ ]|
|7.190|Delivery Guarantees — At-Most-Once|1|[ ]|
|7.191|Delivery Guarantees — At-Least-Once|1|[ ]|
|7.192|Delivery Guarantees — Exactly-Once Mechanisms|1|[ ]|
|7.193|Partial Failure — Detection and Handling|2|[ ]|
|7.194|Network Partition — System Behavior|2|[ ]|
|7.195|Split Brain — Problem and Resolution|2|[ ]|
|7.196|Fallacies of Distributed Computing — All Eight|2|[ ]|
|7.197|Byzantine Fault Tolerance — Overview|3|[ ]|
|7.198|FLP Impossibility — Implications|3|[ ]|
|7.199|Gossip Protocol — Information Dissemination|2|[ ]|
|7.200|Anti-Entropy — Self-Healing Consistency|3|[ ]|
|7.201|Quorum — W + R > N Consistency|2|[ ]|
|7.202|Hinted Handoff — Temporary Failure Handling|2|[ ]|
|7.203|Read Repair — Consistency During Read|3|[ ]|
|7.204|CRDTs — Conflict-Free Replicated Data Types|3|[ ]|
|7.205|Distributed System Design Tradeoffs — Summary|2|[ ]|

---

## Group F — Scalability Patterns (7.206–7.255)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.206|Horizontal vs Vertical Scaling — Tradeoffs|1|[ ]|
|7.207|Stateless Services — Design Principles|1|[ ]|
|7.208|Stateless Services — Session Externalization|2|[ ]|
|7.209|Sticky Sessions — Problem and Impact|2|[ ]|
|7.210|Load Balancing — Overview|1|[ ]|
|7.211|Load Balancing — Layer 4 vs Layer 7|2|[ ]|
|7.212|Load Balancing — Round Robin|2|[ ]|
|7.213|Load Balancing — Least Connections|2|[ ]|
|7.214|Load Balancing — IP Hash|2|[ ]|
|7.215|Load Balancing — Weighted Round Robin|2|[ ]|
|7.216|Load Balancing — Health Check Integration|2|[ ]|
|7.217|Load Balancing — SSL Termination|2|[ ]|
|7.218|Load Balancing — Power of Two Choices|3|[ ]|
|7.219|Database Read Replicas — Setup and Tradeoffs|1|[ ]|
|7.220|Database Read Replicas — Replication Lag|2|[ ]|
|7.221|Database Read Replicas — Read-Your-Writes Problem|2|[ ]|
|7.222|Database Sharding — Overview|1|[ ]|
|7.223|Database Sharding — Partition Key Selection|2|[ ]|
|7.224|Database Sharding — Range-Based|2|[ ]|
|7.225|Database Sharding — Hash-Based|2|[ ]|
|7.226|Database Sharding — Directory-Based|3|[ ]|
|7.227|Database Sharding — Cross-Shard Queries|2|[ ]|
|7.228|Database Sharding — Resharding and Migration|2|[ ]|
|7.229|Consistent Hashing — Algorithm|1|[ ]|
|7.230|Consistent Hashing — Virtual Nodes|2|[ ]|
|7.231|Consistent Hashing — Node Add and Remove|2|[ ]|
|7.232|Consistent Hashing — Use Cases|2|[ ]|
|7.233|Auto-Scaling — Reactive vs Predictive|2|[ ]|
|7.234|Auto-Scaling — Kubernetes HPA|2|[ ]|
|7.235|Auto-Scaling — Cooldown Periods|2|[ ]|
|7.236|Connection Pooling — SQL at Scale|2|[ ]|
|7.237|Connection Pooling — HTTP Connection Reuse|2|[ ]|
|7.238|Backpressure — Detection and Handling|2|[ ]|
|7.239|Queue-Based Load Leveling|2|[ ]|
|7.240|Competing Consumers — Scaling Workers|2|[ ]|
|7.241|Rate Limiting — Token Bucket Algorithm|1|[ ]|
|7.242|Rate Limiting — Leaky Bucket Algorithm|2|[ ]|
|7.243|Rate Limiting — Fixed Window Counter|2|[ ]|
|7.244|Rate Limiting — Sliding Window Log|2|[ ]|
|7.245|Rate Limiting — Sliding Window Counter|2|[ ]|
|7.246|Rate Limiting — Distributed with Redis|1|[ ]|
|7.247|Rate Limiting — ASP.NET Core RateLimiterMiddleware|2|[ ]|
|7.248|Throttling vs Rate Limiting — Differences|2|[ ]|
|7.249|Bulkhead Pattern — Resource Isolation|2|[ ]|
|7.250|Database Federation — Functional Partitioning|3|[ ]|
|7.251|CQRS for Scalability — Read-Write Split|2|[ ]|
|7.252|Denormalization for Read Performance|2|[ ]|
|7.253|Caching as a Scalability Tool|2|[ ]|
|7.254|Eventual Consistency Trade-Off for Scale|2|[ ]|
|7.255|Scale Cube — X, Y, Z Axes|2|[ ]|

---

## Group G — Caching (7.256–7.295)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.256|Caching — Why Cache and When|1|[ ]|
|7.257|Cache-Aside Pattern|1|[ ]|
|7.258|Write-Through Caching|2|[ ]|
|7.259|Write-Behind Caching|2|[ ]|
|7.260|Read-Through Caching|2|[ ]|
|7.261|Refresh-Ahead Caching|3|[ ]|
|7.262|Cache TTL — Design and Selection|2|[ ]|
|7.263|TTL Jitter — Preventing Thundering Herd|2|[ ]|
|7.264|Cache Stampede — Prevention Strategies|2|[ ]|
|7.265|Cache Stampede — Probabilistic Early Expiration|3|[ ]|
|7.266|Cache Stampede — Distributed Lock Prevention|2|[ ]|
|7.267|Cache Invalidation — The Hard Problem|1|[ ]|
|7.268|Cache Invalidation — Event-Driven|2|[ ]|
|7.269|Cache Invalidation — Time-Based Expiry|2|[ ]|
|7.270|Cache Invalidation — Versioned Cache Keys|2|[ ]|
|7.271|Cache Eviction — LRU Policy|2|[ ]|
|7.272|Cache Eviction — LFU Policy|2|[ ]|
|7.273|Cache Eviction — FIFO Policy|2|[ ]|
|7.274|Cache Eviction — ARC Adaptive Replacement|3|[ ]|
|7.275|Distributed Cache vs In-Process Cache|1|[ ]|
|7.276|Multi-Level Caching Architecture|2|[ ]|
|7.277|Cache Warm-Up Strategies|2|[ ]|
|7.278|Cache Sizing and Capacity Planning|2|[ ]|
|7.279|Cache Monitoring — Hit Rate, Miss Rate|2|[ ]|
|7.280|HTTP Caching — Cache-Control Headers|2|[ ]|
|7.281|HTTP Caching — ETag and Conditional Requests|2|[ ]|
|7.282|HTTP Caching — Vary Header|3|[ ]|
|7.283|CDN Caching — Push vs Pull|2|[ ]|
|7.284|CDN Caching — Cache Hit Ratio Optimization|2|[ ]|
|7.285|CDN Caching — Purging Strategies|2|[ ]|
|7.286|Semantic Caching for LLM Responses|3|[ ]|
|7.287|Redis as Cache — Patterns in .NET|2|[ ]|
|7.288|Redis Cache — ASP.NET Core IDistributedCache|2|[ ]|
|7.289|Output Caching — ASP.NET Core|2|[ ]|
|7.290|Response Caching — ASP.NET Core|2|[ ]|
|7.291|Cache Partitioning Strategy|3|[ ]|
|7.292|Cache Consistency in Microservices|2|[ ]|
|7.293|Cache-Aside vs Read-Through — Decision|2|[ ]|
|7.294|Session Storage — Redis vs Cookie vs DB|2|[ ]|
|7.295|Caching Anti-Patterns|2|[ ]|

---

## Group H — Message Brokers — RabbitMQ (7.296–7.320)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.296|RabbitMQ — Architecture and AMQP|2|[ ]|
|7.297|RabbitMQ — Exchanges — Direct|2|[ ]|
|7.298|RabbitMQ — Exchanges — Fanout|2|[ ]|
|7.299|RabbitMQ — Exchanges — Topic|2|[ ]|
|7.300|RabbitMQ — Exchanges — Headers|3|[ ]|
|7.301|RabbitMQ — Queues — Durable vs Transient|2|[ ]|
|7.302|RabbitMQ — Bindings and Routing Keys|2|[ ]|
|7.303|RabbitMQ — Consumer Acknowledgements|2|[ ]|
|7.304|RabbitMQ — Dead Letter Exchanges|2|[ ]|
|7.305|RabbitMQ — Message TTL|2|[ ]|
|7.306|RabbitMQ — Priority Queues|3|[ ]|
|7.307|RabbitMQ — Publisher Confirms|2|[ ]|
|7.308|RabbitMQ — Prefetch Count and QoS|2|[ ]|
|7.309|RabbitMQ — Quorum Queues|2|[ ]|
|7.310|RabbitMQ — Streams|3|[ ]|
|7.311|RabbitMQ — Clustering|2|[ ]|
|7.312|RabbitMQ — Management API|3|[ ]|
|7.313|RabbitMQ — .NET MassTransit Integration|2|[ ]|
|7.314|RabbitMQ — .NET RabbitMQ.Client|3|[ ]|
|7.315|RabbitMQ — Poison Message Handling|2|[ ]|
|7.316|RabbitMQ — Message Ordering|2|[ ]|
|7.317|RabbitMQ — At-Least-Once with Idempotent Consumers|2|[ ]|
|7.318|RabbitMQ — Shovel and Federation|3|[ ]|
|7.319|RabbitMQ — Security|3|[ ]|
|7.320|RabbitMQ — Capacity Planning|3|[ ]|

---

## Group I — Message Brokers — Azure Service Bus (7.321–7.340)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.321|Azure Service Bus — Architecture Overview|2|[ ]|
|7.322|Azure Service Bus — Queues vs Topics|2|[ ]|
|7.323|Azure Service Bus — Subscriptions and Filters|2|[ ]|
|7.324|Azure Service Bus — Message Sessions|2|[ ]|
|7.325|Azure Service Bus — Dead Letter Queue|2|[ ]|
|7.326|Azure Service Bus — Message Deferral|2|[ ]|
|7.327|Azure Service Bus — Scheduled Messages|2|[ ]|
|7.328|Azure Service Bus — Duplicate Detection|2|[ ]|
|7.329|Azure Service Bus — Message Lock and Renewal|2|[ ]|
|7.330|Azure Service Bus — Partitioned Entities|3|[ ]|
|7.331|Azure Service Bus — Premium vs Standard|2|[ ]|
|7.332|Azure Service Bus — ServiceBusClient SDK|2|[ ]|
|7.333|Azure Service Bus — ServiceBusProcessor SDK|2|[ ]|
|7.334|Azure Service Bus — Monitoring and DLQ|2|[ ]|
|7.335|Azure Service Bus — Geo-Disaster Recovery|3|[ ]|
|7.336|Azure Service Bus — Transaction Support|2|[ ]|
|7.337|Azure Service Bus — ASP.NET Core Integration|2|[ ]|
|7.338|Azure Service Bus — Claim Check for Large Messages|2|[ ]|
|7.339|Azure Service Bus — Message Batching|3|[ ]|
|7.340|Broker Decision — RabbitMQ vs Service Bus vs Kafka|1|[ ]|

---

## Group J — Message Brokers — Apache Kafka (7.341–7.370)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.341|Kafka — Architecture and Core Concepts|2|[ ]|
|7.342|Kafka — Topics and Configuration|2|[ ]|
|7.343|Kafka — Partitions — Parallelism|2|[ ]|
|7.344|Kafka — Consumer Groups — Rebalancing|2|[ ]|
|7.345|Kafka — Offsets — Storage and Management|2|[ ]|
|7.346|Kafka — Log Compaction|2|[ ]|
|7.347|Kafka — Retention Policies|2|[ ]|
|7.348|Kafka — Producer Acks — 0, 1, all|2|[ ]|
|7.349|Kafka — Idempotent Producer|2|[ ]|
|7.350|Kafka — Batching and Compression|3|[ ]|
|7.351|Kafka — Consumer Poll Loop|2|[ ]|
|7.352|Kafka — Consumer Lag Monitoring|2|[ ]|
|7.353|Kafka — Exactly-Once Semantics|2|[ ]|
|7.354|Kafka — Replication and ISR|2|[ ]|
|7.355|Kafka — KRaft Mode|3|[ ]|
|7.356|Kafka Streams — Stateless vs Stateful|3|[ ]|
|7.357|Kafka Streams — KTable and KStream|3|[ ]|
|7.358|Kafka Streams — Windowing|3|[ ]|
|7.359|Kafka Connect — Source and Sink|3|[ ]|
|7.360|Kafka — Schema Registry|2|[ ]|
|7.361|Kafka — Schema Evolution|2|[ ]|
|7.362|Kafka — .NET Confluent.Kafka|2|[ ]|
|7.363|Kafka — Monitoring — Lag and Throughput|2|[ ]|
|7.364|Kafka — Multi-Region MirrorMaker 2|3|[ ]|
|7.365|Kafka — Security — TLS, SASL, ACLs|3|[ ]|
|7.366|Kafka — When It Is the Right Choice|2|[ ]|
|7.367|Kafka — When It Is Overkill|2|[ ]|
|7.368|Kafka — Capacity Planning|3|[ ]|
|7.369|Kafka — MassTransit Rider Integration|3|[ ]|
|7.370|Kafka vs RabbitMQ vs Service Bus — Full Decision|1|[ ]|

---

## Group K — Microservices Architecture (7.371–7.425)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.371|Monolith vs Microservices — Decision Framework|1|[ ]|
|7.372|Modular Monolith — First Step|1|[ ]|
|7.373|Service Decomposition — By Business Capability|2|[ ]|
|7.374|Service Decomposition — By Subdomain|2|[ ]|
|7.375|Service Decomposition — Conway's Law|2|[ ]|
|7.376|Service Granularity — Too Fine vs Too Coarse|2|[ ]|
|7.377|Service Ownership — Team and Database|2|[ ]|
|7.378|Database per Service Pattern|1|[ ]|
|7.379|Shared Database Anti-Pattern|2|[ ]|
|7.380|Service Communication — Sync vs Async Decision|1|[ ]|
|7.381|Service Communication — HTTP/REST for External|2|[ ]|
|7.382|Service Communication — gRPC for Internal|2|[ ]|
|7.383|Service Communication — Message Broker for Async|2|[ ]|
|7.384|API Gateway — Purpose and Architecture|1|[ ]|
|7.385|API Gateway — Routing and Load Balancing|2|[ ]|
|7.386|API Gateway — Authentication Offloading|2|[ ]|
|7.387|API Gateway — Rate Limiting|2|[ ]|
|7.388|API Gateway — Request Aggregation|2|[ ]|
|7.389|API Gateway — Response Transformation|2|[ ]|
|7.390|API Gateway — Azure API Management|2|[ ]|
|7.391|Backend for Frontend (BFF) Pattern|2|[ ]|
|7.392|Service Discovery — Client-Side|2|[ ]|
|7.393|Service Discovery — Server-Side|2|[ ]|
|7.394|Service Discovery — Kubernetes Services|2|[ ]|
|7.395|Service Mesh — Problem Statement|2|[ ]|
|7.396|Service Mesh — Istio Architecture|3|[ ]|
|7.397|Service Mesh — Istio Traffic Management|3|[ ]|
|7.398|Service Mesh — Istio mTLS|3|[ ]|
|7.399|Service Mesh — Linkerd|3|[ ]|
|7.400|Service Mesh — Observability Integration|3|[ ]|
|7.401|Sidecar Pattern|2|[ ]|
|7.402|Ambassador Pattern|3|[ ]|
|7.403|gRPC — Protocol Buffers|2|[ ]|
|7.404|gRPC — Service Definition (.proto)|2|[ ]|
|7.405|gRPC — Unary RPC|2|[ ]|
|7.406|gRPC — Server Streaming|2|[ ]|
|7.407|gRPC — Client Streaming|2|[ ]|
|7.408|gRPC — Bidirectional Streaming|2|[ ]|
|7.409|gRPC — Deadlines and Cancellation|2|[ ]|
|7.410|gRPC — Interceptors|2|[ ]|
|7.411|gRPC — Health Checking Protocol|2|[ ]|
|7.412|gRPC — gRPC-Web for Browser|3|[ ]|
|7.413|gRPC — HTTP/JSON Transcoding|3|[ ]|
|7.414|gRPC — .NET Grpc.AspNetCore|2|[ ]|
|7.415|gRPC vs REST — Decision Matrix|1|[ ]|
|7.416|Distributed Tracing in Microservices|2|[ ]|
|7.417|Health Checks in Microservices|2|[ ]|
|7.418|Configuration Management — Per-Service|2|[ ]|
|7.419|Secrets Management in Microservices|2|[ ]|
|7.420|Service Versioning — API Compatibility|2|[ ]|
|7.421|Data Consistency in Microservices|1|[ ]|
|7.422|Testing Microservices — Contract Testing|2|[ ]|
|7.423|Testing Microservices — Pact Framework|3|[ ]|
|7.424|Microservices Anti-Pattern — Distributed Monolith|2|[ ]|
|7.425|Microservices Anti-Pattern — Chatty Services|2|[ ]|

---

## Group L — Resilience Patterns and Polly (7.426–7.450)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.426|Resilience Engineering — Core Concepts|1|[ ]|
|7.427|Retry Pattern — When and How|2|[ ]|
|7.428|Retry Pattern — Exponential Backoff|2|[ ]|
|7.429|Retry Pattern — Jitter|2|[ ]|
|7.430|Retry Pattern — Polly v8 ResiliencePipeline|2|[ ]|
|7.431|Circuit Breaker — State Machine|1|[ ]|
|7.432|Circuit Breaker — Polly Implementation|2|[ ]|
|7.433|Circuit Breaker — Threshold Configuration|2|[ ]|
|7.434|Circuit Breaker — Half-Open Probe|2|[ ]|
|7.435|Timeout Pattern — Polly Implementation|2|[ ]|
|7.436|Timeout Pattern — CancellationToken Propagation|2|[ ]|
|7.437|Bulkhead Pattern — Semaphore Isolation|2|[ ]|
|7.438|Hedging Pattern — Polly|2|[ ]|
|7.439|Fallback Pattern — Graceful Degradation|2|[ ]|
|7.440|Rate Limiter — Polly Pipeline|2|[ ]|
|7.441|Polly v8 — ResiliencePipelineBuilder|2|[ ]|
|7.442|Polly v8 — Telemetry and Events|2|[ ]|
|7.443|Polly v8 — AddResilienceHandler in IHttpClientFactory|2|[ ]|
|7.444|Polly v8 — Composition of Strategies|2|[ ]|
|7.445|Transient Fault Handling — HTTP Status Codes|2|[ ]|
|7.446|Graceful Shutdown — .NET|2|[ ]|
|7.447|Graceful Degradation — Feature Flags|2|[ ]|
|7.448|Resilience in Background Services|2|[ ]|
|7.449|Chaos Engineering — Testing Polly|3|[ ]|
|7.450|Resilience — End-to-End Pipeline Design|2|[ ]|

---

## Group M — API Design — REST (7.451–7.490)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.451|REST — Architectural Constraints|1|[ ]|
|7.452|REST — Uniform Interface|2|[ ]|
|7.453|REST — Statelessness|2|[ ]|
|7.454|REST — Cacheability|2|[ ]|
|7.455|REST — Layered System|2|[ ]|
|7.456|REST — Resource Naming — Nouns vs Verbs|1|[ ]|
|7.457|REST — Resource Hierarchy and Sub-Resources|2|[ ]|
|7.458|REST — HTTP GET Semantics|2|[ ]|
|7.459|REST — HTTP POST Semantics|2|[ ]|
|7.460|REST — HTTP PUT vs PATCH|2|[ ]|
|7.461|REST — HTTP DELETE Semantics|2|[ ]|
|7.462|REST — HTTP Status Codes 2xx|2|[ ]|
|7.463|REST — HTTP Status Codes 3xx|2|[ ]|
|7.464|REST — HTTP Status Codes 4xx|2|[ ]|
|7.465|REST — HTTP Status Codes 5xx|2|[ ]|
|7.466|API Versioning — URL Path|1|[ ]|
|7.467|API Versioning — Query String|2|[ ]|
|7.468|API Versioning — Header-Based|2|[ ]|
|7.469|API Versioning — Content Negotiation|3|[ ]|
|7.470|API Versioning — Deprecation and Sunset|2|[ ]|
|7.471|API Versioning — Asp.Versioning in .NET|2|[ ]|
|7.472|Idempotency Keys — Design|1|[ ]|
|7.473|Pagination — Offset-Based|1|[ ]|
|7.474|Pagination — Cursor-Based|2|[ ]|
|7.475|Pagination — Keyset Pagination|2|[ ]|
|7.476|Pagination — Performance at Scale|2|[ ]|
|7.477|Filtering and Sorting — API Design|2|[ ]|
|7.478|Error Response Design — RFC 9457 Problem Details|1|[ ]|
|7.479|Error Response Design — Machine-Readable Codes|2|[ ]|
|7.480|Error Response Design — Actionable Messages|2|[ ]|
|7.481|API Documentation — OpenAPI 3.0|2|[ ]|
|7.482|API Documentation — Swashbuckle in .NET|2|[ ]|
|7.483|API Documentation — NSwag|2|[ ]|
|7.484|HATEOAS — Hypermedia Controls|3|[ ]|
|7.485|REST API Security Patterns|2|[ ]|
|7.486|REST — Backward Compatibility|2|[ ]|
|7.487|REST API Design Anti-Patterns|2|[ ]|
|7.488|REST — Long-Running Ops — 202 Accepted|2|[ ]|
|7.489|REST — Bulk Operations Design|2|[ ]|
|7.490|REST — Health Endpoint Convention|2|[ ]|

---

## Group N — API Design — GraphQL, gRPC, Real-Time (7.491–7.525)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.491|GraphQL — Queries|2|[ ]|
|7.492|GraphQL — Mutations|2|[ ]|
|7.493|GraphQL — Subscriptions|2|[ ]|
|7.494|GraphQL — Schema Definition Language|2|[ ]|
|7.495|GraphQL — Resolvers|2|[ ]|
|7.496|GraphQL — N+1 Problem and DataLoader|2|[ ]|
|7.497|GraphQL — Federation|3|[ ]|
|7.498|GraphQL — Schema Stitching|3|[ ]|
|7.499|GraphQL — Persisted Queries|3|[ ]|
|7.500|GraphQL — Error Handling|2|[ ]|
|7.501|GraphQL — Auth and Authorization|2|[ ]|
|7.502|GraphQL — Rate Limiting and Complexity|2|[ ]|
|7.503|GraphQL — When to Choose Over REST|2|[ ]|
|7.504|GraphQL — .NET Hot Chocolate|2|[ ]|
|7.505|GraphQL — .NET Strawberry Shake|3|[ ]|
|7.506|WebSockets — Full-Duplex Communication|1|[ ]|
|7.507|WebSockets — Connection Lifecycle|2|[ ]|
|7.508|WebSockets — Authentication|2|[ ]|
|7.509|WebSockets — Scaling with Backplane|2|[ ]|
|7.510|SignalR — Hubs and Groups|2|[ ]|
|7.511|SignalR — Connection Lifecycle|2|[ ]|
|7.512|SignalR — Azure SignalR Service|2|[ ]|
|7.513|SignalR — Redis Backplane|2|[ ]|
|7.514|SignalR — Streaming|2|[ ]|
|7.515|SignalR — Hub Protocol — JSON vs MessagePack|3|[ ]|
|7.516|Server-Sent Events — One-Way Streaming|2|[ ]|
|7.517|SSE — .NET ASP.NET Core Implementation|2|[ ]|
|7.518|Long Polling — Implementation|2|[ ]|
|7.519|WebSockets vs SSE vs Long Polling — Decision|1|[ ]|
|7.520|Webhook Design — Delivery and Retry|2|[ ]|
|7.521|Webhook Design — HMAC Signature|2|[ ]|
|7.522|Webhook Design — Reliability|2|[ ]|
|7.523|Streaming APIs — LLM Response Streaming|2|[ ]|
|7.524|API Mocking and Contract Testing|2|[ ]|
|7.525|API Changelog and Communication|2|[ ]|

---

## Group O — Networking and Infrastructure (7.526–7.565)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.526|DNS — Resolution Process|1|[ ]|
|7.527|DNS — Record Types A, AAAA, CNAME|2|[ ]|
|7.528|DNS — Record Types MX, TXT, NS, SOA, SRV|2|[ ]|
|7.529|DNS — TTL — Caching and Propagation|2|[ ]|
|7.530|DNS — Load Balancing with DNS|2|[ ]|
|7.531|DNS — Failover and Health Checking|2|[ ]|
|7.532|DNS — DNSSEC|3|[ ]|
|7.533|HTTP/1.1 — Keep-Alive and Pipelining|2|[ ]|
|7.534|HTTP/2 — Multiplexing|1|[ ]|
|7.535|HTTP/2 — Header Compression HPACK|2|[ ]|
|7.536|HTTP/2 — Server Push|3|[ ]|
|7.537|HTTP/3 — QUIC Protocol|2|[ ]|
|7.538|HTTP/3 — 0-RTT|3|[ ]|
|7.539|TLS 1.3 — Handshake|2|[ ]|
|7.540|TLS — Certificate Management|2|[ ]|
|7.541|TLS — Mutual TLS (mTLS)|2|[ ]|
|7.542|TLS — Certificate Pinning|3|[ ]|
|7.543|TCP — Three-Way Handshake|2|[ ]|
|7.544|TCP — Congestion Control|2|[ ]|
|7.545|TCP — Flow Control|2|[ ]|
|7.546|TCP — Connection Pooling|2|[ ]|
|7.547|UDP — Use Cases|2|[ ]|
|7.548|CDN — Architecture and Operation|1|[ ]|
|7.549|CDN — Cache Hit Ratio|2|[ ]|
|7.550|CDN — Dynamic Content Acceleration|2|[ ]|
|7.551|CDN — Edge Computing|3|[ ]|
|7.552|CDN — Azure Front Door|2|[ ]|
|7.553|CDN — Cloudflare Architecture|2|[ ]|
|7.554|Load Balancer — Azure Application Gateway|2|[ ]|
|7.555|Reverse Proxy — Nginx|2|[ ]|
|7.556|Reverse Proxy — Caddy|3|[ ]|
|7.557|Network Policies — Kubernetes|2|[ ]|
|7.558|Service-to-Service Networking — Kubernetes|2|[ ]|
|7.559|Private Endpoints — Azure|2|[ ]|
|7.560|VPN Gateway vs ExpressRoute|3|[ ]|
|7.561|Zero-Downtime DNS Changes|2|[ ]|
|7.562|Network Latency — RTT Analysis|2|[ ]|
|7.563|API Gateway — Networking|2|[ ]|
|7.564|IPv6 — Implications|3|[ ]|
|7.565|NAT and IP Translation|3|[ ]|

---

## Group P — Storage Systems (7.566–7.595)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.566|Object Storage — Architecture|1|[ ]|
|7.567|Object Storage — Azure Blob Storage|2|[ ]|
|7.568|Object Storage — AWS S3|2|[ ]|
|7.569|Object Storage — Cloudflare R2|2|[ ]|
|7.570|Object Storage — Multipart Upload|2|[ ]|
|7.571|Object Storage — Presigned URLs|2|[ ]|
|7.572|Object Storage — Lifecycle Management|2|[ ]|
|7.573|Object Storage — Cross-Region Replication|2|[ ]|
|7.574|Object Storage — Access Tiers|2|[ ]|
|7.575|Object Storage — Consistency Model|2|[ ]|
|7.576|Block vs Object vs File Storage|1|[ ]|
|7.577|Write-Ahead Log — Applications|2|[ ]|
|7.578|LSM Tree — Log-Structured Merge Tree|2|[ ]|
|7.579|B-Tree Storage — System Design Level|2|[ ]|
|7.580|Column-Oriented Storage|2|[ ]|
|7.581|Data Warehouse — OLAP vs OLTP|2|[ ]|
|7.582|Data Lake Architecture|2|[ ]|
|7.583|Lakehouse — Delta Lake and Iceberg|3|[ ]|
|7.584|Immutable Storage — Append-Only|2|[ ]|
|7.585|WORM Storage — Compliance|3|[ ]|
|7.586|Storage Capacity Planning|2|[ ]|
|7.587|Storage Tiering — Hot to Cold|2|[ ]|
|7.588|Backup and Recovery Strategies|2|[ ]|
|7.589|Point-in-Time Recovery|2|[ ]|
|7.590|Storage Encryption at Rest|2|[ ]|
|7.591|Content-Addressable Storage|3|[ ]|
|7.592|Deduplication|3|[ ]|
|7.593|SSD vs HDD Performance|2|[ ]|
|7.594|NVMe — Architecture Impact|3|[ ]|
|7.595|Storage Monitoring — IOPS, Throughput|2|[ ]|

---

## Group Q — Stream Processing and Data Pipelines (7.596–7.620)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.596|Batch vs Stream Processing|2|[ ]|
|7.597|Lambda Architecture|2|[ ]|
|7.598|Kappa Architecture|2|[ ]|
|7.599|Stream Processing — Tumbling Window|2|[ ]|
|7.600|Stream Processing — Sliding Window|2|[ ]|
|7.601|Stream Processing — Session Window|2|[ ]|
|7.602|Stream Processing — Stateless vs Stateful|2|[ ]|
|7.603|Stream Processing — Watermarks and Late Data|2|[ ]|
|7.604|Stream Processing — Kafka Streams|2|[ ]|
|7.605|Stream Processing — Azure Stream Analytics|2|[ ]|
|7.606|Stream Processing — Apache Flink|3|[ ]|
|7.607|ETL vs ELT|2|[ ]|
|7.608|Data Pipeline — Azure Data Factory|2|[ ]|
|7.609|Data Pipeline — Apache Airflow|3|[ ]|
|7.610|Real-Time Analytics Architecture|2|[ ]|
|7.611|Materialized Views — Incremental|2|[ ]|
|7.612|Event Aggregation Patterns|2|[ ]|
|7.613|Exactly-Once in Stream Processing|2|[ ]|
|7.614|Backfill Strategy|3|[ ]|
|7.615|MapReduce — Overview|2|[ ]|
|7.616|Micro-Batch Processing|3|[ ]|
|7.617|Real-Time Dashboards — Architecture|2|[ ]|
|7.618|OLAP Cube vs Columnar Store|3|[ ]|
|7.619|ClickHouse — Columnar Analytics|3|[ ]|
|7.620|Stream Processing Testing|2|[ ]|

---

## Group R — Search Systems (7.621–7.650)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.621|Full-Text Search — Inverted Index|1|[ ]|
|7.622|Full-Text Search — Tokenization|2|[ ]|
|7.623|Full-Text Search — Stemming and Lemmatization|2|[ ]|
|7.624|Full-Text Search — TF-IDF|2|[ ]|
|7.625|Full-Text Search — BM25|2|[ ]|
|7.626|Elasticsearch — Architecture|2|[ ]|
|7.627|Elasticsearch — Indices and Shards|2|[ ]|
|7.628|Elasticsearch — Replication|2|[ ]|
|7.629|Elasticsearch — Query DSL Match, Term, Range|2|[ ]|
|7.630|Elasticsearch — Boolean Queries|2|[ ]|
|7.631|Elasticsearch — Aggregations|2|[ ]|
|7.632|Elasticsearch — Mappings|2|[ ]|
|7.633|Elasticsearch — ILM|2|[ ]|
|7.634|Elasticsearch — .NET Client|2|[ ]|
|7.635|OpenSearch — Differences|2|[ ]|
|7.636|Azure AI Search|2|[ ]|
|7.637|Vector Search — Embedding-Based|2|[ ]|
|7.638|Vector Search — HNSW Index|2|[ ]|
|7.639|Vector Search — ANN vs Exact KNN|2|[ ]|
|7.640|Vector Search — Product Quantization|3|[ ]|
|7.641|Hybrid Search — BM25 + Vector|2|[ ]|
|7.642|Hybrid Search — RRF|2|[ ]|
|7.643|Semantic Search — Pipeline|2|[ ]|
|7.644|Search Relevance Tuning|2|[ ]|
|7.645|Search Monitoring|2|[ ]|
|7.646|Search — Multi-Language|3|[ ]|
|7.647|Search — Geo-Search|3|[ ]|
|7.648|Search — Spell Correction|3|[ ]|
|7.649|Search — A/B Testing|3|[ ]|
|7.650|SQL Server Full-Text Search|2|[ ]|

---

## Group S — Reliability, SLO, Incident Management (7.651–7.690)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.651|SLI — Service Level Indicators|1|[ ]|
|7.652|SLO — Service Level Objectives|1|[ ]|
|7.653|SLA — Service Level Agreements|2|[ ]|
|7.654|Error Budget — Concept|2|[ ]|
|7.655|Availability — 9s|1|[ ]|
|7.656|MTTR — Mean Time to Recovery|2|[ ]|
|7.657|MTBF — Mean Time Between Failures|2|[ ]|
|7.658|RTO — Recovery Time Objective|2|[ ]|
|7.659|RPO — Recovery Point Objective|2|[ ]|
|7.660|Disaster Recovery — Active-Active|2|[ ]|
|7.661|Disaster Recovery — Active-Passive|2|[ ]|
|7.662|Disaster Recovery — Geo-Replication|2|[ ]|
|7.663|Disaster Recovery — DR Testing|2|[ ]|
|7.664|Chaos Engineering — Principles|2|[ ]|
|7.665|Chaos Engineering — Chaos Monkey|2|[ ]|
|7.666|Chaos Engineering — Game Days|3|[ ]|
|7.667|Fault Injection Testing|2|[ ]|
|7.668|Health Checks — Readiness vs Liveness vs Startup|1|[ ]|
|7.669|Health Checks — ASP.NET Core Implementation|2|[ ]|
|7.670|Health Checks — Dependency Health|2|[ ]|
|7.671|Health Checks — Kubernetes Probes|2|[ ]|
|7.672|Graceful Shutdown — .NET|2|[ ]|
|7.673|Feature Flags — Architecture|2|[ ]|
|7.674|Feature Flags — Microsoft.FeatureManagement|2|[ ]|
|7.675|Feature Flags — LaunchDarkly|3|[ ]|
|7.676|Incident Response — On-Call|2|[ ]|
|7.677|Incident Response — Severity Levels|2|[ ]|
|7.678|Incident Response — Communication|2|[ ]|
|7.679|Post-Mortem — Blameless Culture|2|[ ]|
|7.680|Post-Mortem — Template|2|[ ]|
|7.681|Post-Mortem — Action Items|2|[ ]|
|7.682|Runbooks — Writing Effective|2|[ ]|
|7.683|Alerting — Alert Fatigue|2|[ ]|
|7.684|Alerting — Page vs Ticket|2|[ ]|
|7.685|SRE — Google SRE Principles|2|[ ]|
|7.686|Reliability Testing|2|[ ]|
|7.687|Error Budget — Freeze Policy|3|[ ]|
|7.688|On-Call Rotation Design|3|[ ]|
|7.689|Alerting — Dead Man's Switch|3|[ ]|
|7.690|Toil — Definition and Reduction|3|[ ]|

---

## Group T — Deployment Strategies (7.691–7.715)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.691|Blue-Green Deployment|1|[ ]|
|7.692|Blue-Green — Database Schema Compatibility|2|[ ]|
|7.693|Canary Deployment — Traffic Splitting|2|[ ]|
|7.694|Canary — Automated Rollback|2|[ ]|
|7.695|Rolling Deployment — Zero Downtime|2|[ ]|
|7.696|Rolling Deployment — Kubernetes|2|[ ]|
|7.697|A/B Testing Architecture|2|[ ]|
|7.698|Shadow Traffic|2|[ ]|
|7.699|Feature Flags — Deploy vs Release|2|[ ]|
|7.700|Database Migrations — Zero Downtime|1|[ ]|
|7.701|Database Migrations — Expand-Contract|2|[ ]|
|7.702|Database Migrations — Backward-Compatible|2|[ ]|
|7.703|Immutable Infrastructure|2|[ ]|
|7.704|GitOps — IaC from Git|2|[ ]|
|7.705|ArgoCD — Kubernetes GitOps|2|[ ]|
|7.706|FluxCD — Kubernetes GitOps|3|[ ]|
|7.707|Rollback Strategy|2|[ ]|
|7.708|Multi-Region Deployment — Traffic Routing|2|[ ]|
|7.709|Environment Parity|2|[ ]|
|7.710|Production Readiness Checklist|2|[ ]|
|7.711|Dark Launch|3|[ ]|
|7.712|Infrastructure Drift Detection|3|[ ]|
|7.713|Deployment Automation — End-to-End|2|[ ]|
|7.714|Release Train|3|[ ]|
|7.715|Deployment Strategies — Summary|2|[ ]|

---

## Group U — Observability — Logging (7.716–7.740)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.716|Observability — The Three Pillars|1|[ ]|
|7.717|Structured Logging — Why Unstructured Fails|1|[ ]|
|7.718|Serilog — .NET Integration|1|[ ]|
|7.719|Serilog — appsettings Configuration|2|[ ]|
|7.720|Serilog — Enrichers — RequestId, CorrelationId|2|[ ]|
|7.721|Serilog — Destructuring Policies|2|[ ]|
|7.722|Serilog — Sinks — Console, File, Seq|2|[ ]|
|7.723|Serilog — Sinks — Elasticsearch|2|[ ]|
|7.724|Serilog — Async Wrapper|2|[ ]|
|7.725|Serilog — Filtering per Namespace|2|[ ]|
|7.726|Correlation ID — Generation and Propagation|1|[ ]|
|7.727|Correlation ID — HTTP Header Convention|2|[ ]|
|7.728|Correlation ID — Middleware Implementation|2|[ ]|
|7.729|Log Levels — Selection Strategy|2|[ ]|
|7.730|Log Context — Scoped Properties|2|[ ]|
|7.731|What to Log|2|[ ]|
|7.732|What NOT to Log — PII, Tokens|2|[ ]|
|7.733|Log Aggregation — ELK Stack|2|[ ]|
|7.734|Log Aggregation — Grafana Loki|2|[ ]|
|7.735|Log Aggregation — Azure Monitor|2|[ ]|
|7.736|Log Retention and Cost|2|[ ]|
|7.737|Log-Based Alerting|2|[ ]|
|7.738|Audit Logging Architecture|2|[ ]|
|7.739|Log Sampling — High Volume|3|[ ]|
|7.740|Log Search and KQL|2|[ ]|

---

## Group V — Observability — Metrics and Tracing (7.741–7.775)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.741|Metrics — Counters, Gauges, Histograms|1|[ ]|
|7.742|Metrics — Naming Conventions|2|[ ]|
|7.743|Metrics — Prometheus Exposition Format|2|[ ]|
|7.744|Metrics — ASP.NET Core Integration|2|[ ]|
|7.745|Metrics — System.Diagnostics.Metrics API|2|[ ]|
|7.746|Prometheus — Scraping Configuration|2|[ ]|
|7.747|Prometheus — Labels and Cardinality|2|[ ]|
|7.748|Prometheus — PromQL|2|[ ]|
|7.749|Prometheus — Alertmanager|2|[ ]|
|7.750|Grafana — Dashboard Design|2|[ ]|
|7.751|Grafana — Panel Types|2|[ ]|
|7.752|Grafana — Alerting Rules|2|[ ]|
|7.753|Application Insights — SDK Integration|2|[ ]|
|7.754|Application Insights — Custom Events|2|[ ]|
|7.755|Application Insights — Dependency Tracking|2|[ ]|
|7.756|Application Insights — Live Metrics|2|[ ]|
|7.757|Application Insights — Availability Tests|2|[ ]|
|7.758|Application Insights — Smart Detection|3|[ ]|
|7.759|OpenTelemetry — Architecture|1|[ ]|
|7.760|OpenTelemetry — ActivitySource and Activity|2|[ ]|
|7.761|OpenTelemetry — W3C TraceContext|2|[ ]|
|7.762|OpenTelemetry — Metrics API|2|[ ]|
|7.763|OpenTelemetry — Logs API|2|[ ]|
|7.764|OpenTelemetry — Auto-Instrumentation|2|[ ]|
|7.765|OpenTelemetry — OTLP Exporter|2|[ ]|
|7.766|OpenTelemetry — Collector|2|[ ]|
|7.767|Distributed Tracing — Trace and Span|1|[ ]|
|7.768|Distributed Tracing — Jaeger|2|[ ]|
|7.769|Distributed Tracing — Sampling|2|[ ]|
|7.770|RED Method|2|[ ]|
|7.771|USE Method|2|[ ]|
|7.772|P50/P95/P99 — Percentile Latency|1|[ ]|
|7.773|Tail Latency — Causes and Mitigation|2|[ ]|
|7.774|Flame Graphs|2|[ ]|
|7.775|Observability — Cost vs Value|2|[ ]|

---

## Group W — Azure Architecture (7.776–7.845)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.776|Azure Well-Architected Framework|1|[ ]|
|7.777|Azure — Reliability Pillar|2|[ ]|
|7.778|Azure — Security Pillar|2|[ ]|
|7.779|Azure — Cost Optimization|2|[ ]|
|7.780|Azure — Operational Excellence|2|[ ]|
|7.781|Azure — Performance Efficiency|2|[ ]|
|7.782|Azure App Service — Architecture|2|[ ]|
|7.783|Azure App Service — Deployment Slots|2|[ ]|
|7.784|Azure App Service — Auto-Scaling|2|[ ]|
|7.785|Azure App Service — TLS and Domains|2|[ ]|
|7.786|Azure Container Apps — Overview|2|[ ]|
|7.787|Azure Container Apps — KEDA|2|[ ]|
|7.788|Azure Container Apps — Dapr|2|[ ]|
|7.789|Azure Container Apps — Ingress|2|[ ]|
|7.790|Azure Container Apps — Revisions|3|[ ]|
|7.791|AKS — Architecture|2|[ ]|
|7.792|AKS — Node Pools|2|[ ]|
|7.793|AKS — Cluster Autoscaler|2|[ ]|
|7.794|AKS — Networking|2|[ ]|
|7.795|AKS — Private Cluster|2|[ ]|
|7.796|Azure SQL — DTU vs vCore|2|[ ]|
|7.797|Azure SQL — Elastic Pools|2|[ ]|
|7.798|Azure SQL — Geo-Replication|2|[ ]|
|7.799|Azure SQL — Auto-Failover Groups|2|[ ]|
|7.800|Azure SQL — Automatic Tuning|3|[ ]|
|7.801|Azure Cosmos DB — Multi-Model|2|[ ]|
|7.802|Azure Cosmos DB — Partition Key Design|1|[ ]|
|7.803|Azure Cosmos DB — Consistency Levels|2|[ ]|
|7.804|Azure Cosmos DB — Multi-Region Write|2|[ ]|
|7.805|Azure Cosmos DB — Change Feed|2|[ ]|
|7.806|Azure Cosmos DB — SDK|2|[ ]|
|7.807|Azure Cosmos DB — RU Capacity|2|[ ]|
|7.808|Azure Cosmos DB — Serverless vs Provisioned|2|[ ]|
|7.809|Azure Event Hubs — Streaming|2|[ ]|
|7.810|Azure Event Hubs — Consumer Groups|2|[ ]|
|7.811|Azure Event Hubs — Capture|2|[ ]|
|7.812|Azure Event Hubs — Kafka Support|2|[ ]|
|7.813|Azure Event Hubs — Schema Registry|2|[ ]|
|7.814|Azure Cache for Redis|2|[ ]|
|7.815|Azure Cache for Redis — Tiers|2|[ ]|
|7.816|Azure Functions — Triggers|2|[ ]|
|7.817|Azure Functions — HTTP Trigger|2|[ ]|
|7.818|Azure Functions — Timer and Service Bus|2|[ ]|
|7.819|Azure Functions — Durable — Orchestration|2|[ ]|
|7.820|Azure Functions — Durable — Fan-Out/Fan-In|2|[ ]|
|7.821|Azure Functions — Cold Start|2|[ ]|
|7.822|Azure Key Vault — Secrets|1|[ ]|
|7.823|Azure Key Vault — Managed Identity|2|[ ]|
|7.824|Azure AD — App Registration|2|[ ]|
|7.825|Azure AD — Service Principal|2|[ ]|
|7.826|Azure AD — Managed Identity|2|[ ]|
|7.827|Azure AD — OAuth 2.0 Flows|2|[ ]|
|7.828|Azure API Management — Policies|2|[ ]|
|7.829|Azure API Management — Portal|2|[ ]|
|7.830|Azure API Management — Rate Limiting|2|[ ]|
|7.831|Azure Front Door — Global LB|2|[ ]|
|7.832|Azure Front Door — WAF|2|[ ]|
|7.833|Azure Front Door — Caching|2|[ ]|
|7.834|Azure Monitor — Alerts|2|[ ]|
|7.835|Azure Monitor — Workbooks|2|[ ]|
|7.836|Azure DevOps Pipelines|2|[ ]|
|7.837|Azure DevOps — Environments|2|[ ]|
|7.838|IaC — Bicep|2|[ ]|
|7.839|IaC — Terraform on Azure|2|[ ]|
|7.840|Azure Private Link|2|[ ]|
|7.841|Azure Logic Apps|3|[ ]|
|7.842|Azure Virtual Network|2|[ ]|
|7.843|Azure Load Testing Service|3|[ ]|
|7.844|Azure Container Registry|2|[ ]|
|7.845|Azure — Multi-Region Architecture Pattern|2|[ ]|

---

## Group X — Containerization — Docker (7.846–7.865)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.846|Docker — Image Layers and Union FS|1|[ ]|
|7.847|Docker — Dockerfile Commands|2|[ ]|
|7.848|Docker — ENTRYPOINT vs CMD|2|[ ]|
|7.849|Docker — Multi-Stage Builds|1|[ ]|
|7.850|Docker — Layer Caching and .dockerignore|2|[ ]|
|7.851|Docker — Minimal Base Images|2|[ ]|
|7.852|Docker — Image Scanning|2|[ ]|
|7.853|Docker — Compose — Service Definition|2|[ ]|
|7.854|Docker — Compose — Networking|2|[ ]|
|7.855|Docker — Compose — Volumes|2|[ ]|
|7.856|Docker — Compose — Depends-On|2|[ ]|
|7.857|Docker — Container Registries|2|[ ]|
|7.858|Docker — Networking Modes|2|[ ]|
|7.859|Docker — Volume Types|2|[ ]|
|7.860|Docker — Resource Limits|2|[ ]|
|7.861|Docker — Multi-Platform BuildKit|3|[ ]|
|7.862|Docker — ASP.NET Core Best Practices|2|[ ]|
|7.863|Docker — Non-Root User|2|[ ]|
|7.864|Docker — .NET Chiseled Images|2|[ ]|
|7.865|Docker — Health Check Instruction|2|[ ]|

---

## Group Y — Kubernetes (7.866–7.915)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.866|Kubernetes — Control Plane Architecture|1|[ ]|
|7.867|Kubernetes — Worker Node Components|2|[ ]|
|7.868|Kubernetes — Pod Lifecycle|1|[ ]|
|7.869|Kubernetes — Init Containers|2|[ ]|
|7.870|Kubernetes — Sidecar Containers|2|[ ]|
|7.871|Kubernetes — ReplicaSet and Deployment|1|[ ]|
|7.872|Kubernetes — Rolling Update|2|[ ]|
|7.873|Kubernetes — Rollback|2|[ ]|
|7.874|Kubernetes — StatefulSet|2|[ ]|
|7.875|Kubernetes — DaemonSet|2|[ ]|
|7.876|Kubernetes — Job and CronJob|2|[ ]|
|7.877|Kubernetes — Services — ClusterIP|2|[ ]|
|7.878|Kubernetes — Services — NodePort|2|[ ]|
|7.879|Kubernetes — Services — LoadBalancer|2|[ ]|
|7.880|Kubernetes — Ingress — Routing|2|[ ]|
|7.881|Kubernetes — Ingress — TLS|2|[ ]|
|7.882|Kubernetes — Ingress — NGINX|2|[ ]|
|7.883|Kubernetes — ConfigMaps|2|[ ]|
|7.884|Kubernetes — Secrets|2|[ ]|
|7.885|Kubernetes — External Secrets Operator|2|[ ]|
|7.886|Kubernetes — PersistentVolume and PVC|2|[ ]|
|7.887|Kubernetes — StorageClass|2|[ ]|
|7.888|Kubernetes — Resource Requests and Limits|2|[ ]|
|7.889|Kubernetes — QoS Classes|2|[ ]|
|7.890|Kubernetes — HPA|2|[ ]|
|7.891|Kubernetes — VPA|2|[ ]|
|7.892|Kubernetes — KEDA|2|[ ]|
|7.893|Kubernetes — Node Affinity|2|[ ]|
|7.894|Kubernetes — Taints and Tolerations|2|[ ]|
|7.895|Kubernetes — Topology Spread|3|[ ]|
|7.896|Kubernetes — Liveness Probe|2|[ ]|
|7.897|Kubernetes — Readiness Probe|2|[ ]|
|7.898|Kubernetes — Startup Probe|2|[ ]|
|7.899|Kubernetes — RBAC|2|[ ]|
|7.900|Kubernetes — Network Policies|2|[ ]|
|7.901|Kubernetes — Operators and CRDs|2|[ ]|
|7.902|Kubernetes — Helm — Chart Structure|2|[ ]|
|7.903|Kubernetes — Helm — Values|2|[ ]|
|7.904|Kubernetes — Helm — Release Management|2|[ ]|
|7.905|Kubernetes — Kustomize|2|[ ]|
|7.906|Kubernetes — Namespace Strategy|2|[ ]|
|7.907|Kubernetes — Multi-Tenancy|2|[ ]|
|7.908|Kubernetes — kubectl Commands|2|[ ]|
|7.909|Kubernetes — Debugging|2|[ ]|
|7.910|Kubernetes — Pod Security|2|[ ]|
|7.911|Kubernetes — Cost Optimization|3|[ ]|
|7.912|Kubernetes — Cluster Upgrade|3|[ ]|
|7.913|Kubernetes — Service Accounts|2|[ ]|
|7.914|Kubernetes — Workload Identity|2|[ ]|
|7.915|Kubernetes — CrashLoopBackOff Debugging|2|[ ]|

---

## Group Z — CI/CD (7.916–7.955)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.916|CI/CD — Pipeline Fundamentals|1|[ ]|
|7.917|Git — Trunk-Based Development|2|[ ]|
|7.918|Git — GitFlow|2|[ ]|
|7.919|Git — GitHub Flow|2|[ ]|
|7.920|Git — Conventional Commits|2|[ ]|
|7.921|Git — Branch Protection Rules|2|[ ]|
|7.922|GitHub Actions — Workflow YAML|2|[ ]|
|7.923|GitHub Actions — Jobs and Steps|2|[ ]|
|7.924|GitHub Actions — Triggers|2|[ ]|
|7.925|GitHub Actions — Matrix Builds|2|[ ]|
|7.926|GitHub Actions — Reusable Workflows|2|[ ]|
|7.927|GitHub Actions — Secrets and OIDC|2|[ ]|
|7.928|GitHub Actions — Environments|2|[ ]|
|7.929|GitHub Actions — .NET CI Pipeline|1|[ ]|
|7.930|GitHub Actions — Docker Build and Push|2|[ ]|
|7.931|GitHub Actions — Deploy to App Service|2|[ ]|
|7.932|GitHub Actions — Deploy to AKS|2|[ ]|
|7.933|Azure DevOps — YAML Pipelines|2|[ ]|
|7.934|Azure DevOps — Variable Groups|2|[ ]|
|7.935|Azure DevOps — Service Connections|2|[ ]|
|7.936|Azure DevOps — Approval Gates|2|[ ]|
|7.937|Semantic Versioning — GitVersion|2|[ ]|
|7.938|Semantic Versioning — MinVer|2|[ ]|
|7.939|Pipeline Security — Secret Scanning|2|[ ]|
|7.940|Pipeline Security — Dependency Scanning|2|[ ]|
|7.941|Pipeline Security — SAST|2|[ ]|
|7.942|Pipeline Security — Container Scanning Trivy|2|[ ]|
|7.943|Pipeline Security — SBOM|3|[ ]|
|7.944|Test Reporting in CI|2|[ ]|
|7.945|Code Coverage Reporting|2|[ ]|
|7.946|IaC Deployment from CI|2|[ ]|
|7.947|GitOps — ArgoCD|2|[ ]|
|7.948|GitOps — FluxCD|3|[ ]|
|7.949|Monorepo CI/CD|3|[ ]|
|7.950|DORA Metrics|2|[ ]|
|7.951|Feature Branch — Ephemeral Environments|3|[ ]|
|7.952|Artifact — Registry Tagging|2|[ ]|
|7.953|Pipeline Rollback|2|[ ]|
|7.954|Pipeline Optimization — Caching|2|[ ]|
|7.955|CI/CD Security Best Practices|2|[ ]|
# Domain 7 — System Design & Distributed Systems

## Phonebook — Part 2 of 2 (Topics 7.956 – 7.1355)

---

## Group AA — NoSQL Systems (7.956–7.999)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.956|NoSQL — Categories and Decision Framework|1|[ ]|
|7.957|MongoDB — Document Model and BSON|2|[ ]|
|7.958|MongoDB — Collections and Indexes|2|[ ]|
|7.959|MongoDB — Embedded vs Referenced Documents|2|[ ]|
|7.960|MongoDB — Aggregation Pipeline|2|[ ]|
|7.961|MongoDB — Index Types — Single, Compound|2|[ ]|
|7.962|MongoDB — Text and Geospatial Indexes|3|[ ]|
|7.963|MongoDB — Replica Sets|2|[ ]|
|7.964|MongoDB — Sharding Architecture|2|[ ]|
|7.965|MongoDB — Multi-Document Transactions|2|[ ]|
|7.966|MongoDB — Change Streams|2|[ ]|
|7.967|MongoDB — .NET Driver — MongoDB.Driver|2|[ ]|
|7.968|Cassandra — Wide-Column Data Model|2|[ ]|
|7.969|Cassandra — Partition Key and Clustering Key|2|[ ]|
|7.970|Cassandra — Query-First Design|2|[ ]|
|7.971|Cassandra — Consistency Levels|2|[ ]|
|7.972|Cassandra — Tombstones and Compaction|3|[ ]|
|7.973|Cassandra — CQL Data Modeling|2|[ ]|
|7.974|Redis — String Commands and Patterns|2|[ ]|
|7.975|Redis — Hash Commands|2|[ ]|
|7.976|Redis — List Commands|2|[ ]|
|7.977|Redis — Sets and Sorted Sets|2|[ ]|
|7.978|Redis — Streams Data Type|2|[ ]|
|7.979|Redis — HyperLogLog|2|[ ]|
|7.980|Redis — Geospatial Commands|3|[ ]|
|7.981|Redis — Pub/Sub|2|[ ]|
|7.982|Redis — MULTI/EXEC Transactions|2|[ ]|
|7.983|Redis — Lua Scripting|2|[ ]|
|7.984|Redis — Redlock Distributed Lock|2|[ ]|
|7.985|Redis — Sentinel — High Availability|2|[ ]|
|7.986|Redis — Cluster — Sharding|2|[ ]|
|7.987|Redis — Persistence — RDB vs AOF|2|[ ]|
|7.988|Redis — Keyspace Notifications|3|[ ]|
|7.989|Redis — ACL Security|3|[ ]|
|7.990|Redis — StackExchange.Redis — ConnectionMultiplexer|2|[ ]|
|7.991|Redis — StackExchange.Redis — Batch and Pipeline|2|[ ]|
|7.992|DynamoDB — Partition Key and Sort Key|2|[ ]|
|7.993|DynamoDB — GSI and LSI|2|[ ]|
|7.994|DynamoDB — Single-Table Design|2|[ ]|
|7.995|DynamoDB — Streams|3|[ ]|
|7.996|Neo4j — Graph Data Model|3|[ ]|
|7.997|Neo4j — Cypher Query Language|3|[ ]|
|7.998|InfluxDB — Time-Series Model|3|[ ]|
|7.999|TimescaleDB — PostgreSQL Extension|3|[ ]|

---

## Group AB — Distributed Algorithms and Data Structures (7.1000–7.1025)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1000|Bloom Filters — Probabilistic Membership|2|[ ]|
|7.1001|Count-Min Sketch — Frequency Estimation|2|[ ]|
|7.1002|HyperLogLog — Cardinality Estimation|2|[ ]|
|7.1003|Merkle Trees — Data Integrity|2|[ ]|
|7.1004|Skip List — Probabilistic Structure|3|[ ]|
|7.1005|Quorum — W + R > N in Practice|2|[ ]|
|7.1006|Hinted Handoff|2|[ ]|
|7.1007|Read Repair|3|[ ]|
|7.1008|CRDTs — G-Counter and PN-Counter|3|[ ]|
|7.1009|CRDTs — LWW-Register and 2P-Set|3|[ ]|
|7.1010|Operational Transformation|3|[ ]|
|7.1011|Distributed Locking — Fencing Tokens|2|[ ]|
|7.1012|Jump Hash Algorithm|3|[ ]|
|7.1013|Rendezvous Hashing|3|[ ]|
|7.1014|Power of Two Choices|3|[ ]|
|7.1015|Probabilistic Data Structures — Summary|2|[ ]|
|7.1016|Anti-Entropy Repair Protocols|3|[ ]|
|7.1017|Gossip Protocol — Implementation|3|[ ]|
|7.1018|Vector Clock — Causality Tracking|2|[ ]|
|7.1019|Write-Ahead Log — Replication Use|2|[ ]|
|7.1020|Snapshot Isolation — MVCC Implementation|2|[ ]|
|7.1021|Log Structured Storage — Compaction|2|[ ]|
|7.1022|Consistent Hashing — Full Implementation|2|[ ]|
|7.1023|Randomized Algorithms in Distributed Systems|3|[ ]|
|7.1024|Approximate Computing — When Exact Isn't Needed|3|[ ]|
|7.1025|Two-Phase Locking vs MVCC — Comparison|2|[ ]|

---

## Group AC — Real-Time and Streaming Systems (7.1026–7.1060)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1026|Real-Time Systems — Definition and Requirements|2|[ ]|
|7.1027|WebSocket Server — Scalable Architecture|2|[ ]|
|7.1028|WebSocket — Load Balancing — Sticky Sessions|2|[ ]|
|7.1029|WebSocket — Pub/Sub Backend — Redis|2|[ ]|
|7.1030|WebSocket — Authentication Patterns|2|[ ]|
|7.1031|SignalR — Architecture Overview|2|[ ]|
|7.1032|SignalR — Hub Protocol — JSON vs MessagePack|3|[ ]|
|7.1033|SignalR — Groups and Connections|2|[ ]|
|7.1034|SignalR — Azure SignalR Service Scaling|2|[ ]|
|7.1035|SignalR — Redis Backplane|2|[ ]|
|7.1036|SignalR — Async Enumerable Streaming|2|[ ]|
|7.1037|SSE — .NET ASP.NET Core|2|[ ]|
|7.1038|SSE — Reconnection Behavior|2|[ ]|
|7.1039|Push Notifications — Architecture Overview|2|[ ]|
|7.1040|FCM — Firebase Cloud Messaging|2|[ ]|
|7.1041|APNs — Apple Push Notifications|2|[ ]|
|7.1042|Web Push — Protocol|3|[ ]|
|7.1043|Presence Detection — Online Status|2|[ ]|
|7.1044|Real-Time Collaboration Architecture|3|[ ]|
|7.1045|Live Feed — Architecture|2|[ ]|
|7.1046|Streaming APIs — LLM Response in .NET|2|[ ]|
|7.1047|MQTT — IoT Messaging Protocol|3|[ ]|
|7.1048|AMQP — Protocol Fundamentals|3|[ ]|
|7.1049|STOMP Protocol|4|[ ]|
|7.1050|Real-Time Gaming — Architecture|3|[ ]|
|7.1051|WebRTC — Video Conferencing Overview|3|[ ]|
|7.1052|Real-Time Analytics — Event Pipeline|2|[ ]|
|7.1053|Observability for Real-Time Systems|2|[ ]|
|7.1054|Backpressure in Streaming|2|[ ]|
|7.1055|Long Polling — Scaling Problems|2|[ ]|
|7.1056|Comet Pattern — Historical Context|4|[ ]|
|7.1057|Real-Time Bidding — Architecture|3|[ ]|
|7.1058|Event Bus — In-Process vs Distributed|2|[ ]|
|7.1059|Actor Model — Overview|3|[ ]|
|7.1060|Reactive Systems — Manifesto Principles|3|[ ]|

---

## Group AD — Performance and Capacity Planning (7.1061–7.1100)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1061|Performance Testing vs Load vs Stress|2|[ ]|
|7.1062|Load Testing — k6|2|[ ]|
|7.1063|Load Testing — NBomber in .NET|2|[ ]|
|7.1064|Load Testing — JMeter|3|[ ]|
|7.1065|Capacity Planning — QPS Estimation|1|[ ]|
|7.1066|Capacity Planning — Storage Estimation|1|[ ]|
|7.1067|Capacity Planning — Bandwidth Estimation|1|[ ]|
|7.1068|Capacity Planning — Memory Estimation|2|[ ]|
|7.1069|Latency Numbers — Every Engineer Must Know|1|[ ]|
|7.1070|Latency Budget — End-to-End Design|2|[ ]|
|7.1071|P50/P95/P99/P999 — Percentile Analysis|2|[ ]|
|7.1072|Tail Latency — Hedged Requests|2|[ ]|
|7.1073|Database Query Performance at Scale|2|[ ]|
|7.1074|Connection Pool Exhaustion — Prevention|2|[ ]|
|7.1075|Thread Pool Starvation — .NET Async|2|[ ]|
|7.1076|Memory Pressure Under Load|2|[ ]|
|7.1077|GC Pauses — P99 Impact|2|[ ]|
|7.1078|Hot Path Optimization|2|[ ]|
|7.1079|Profiling — dotnet-trace|2|[ ]|
|7.1080|Profiling — dotnet-counters|2|[ ]|
|7.1081|Profiling — dotnet-dump|2|[ ]|
|7.1082|Flame Graphs — Reading|2|[ ]|
|7.1083|CPU Profiling — dotTrace|2|[ ]|
|7.1084|Memory Profiling — dotMemory|2|[ ]|
|7.1085|Cache Performance — Hit Rate Impact|2|[ ]|
|7.1086|Network Latency — Measurement|2|[ ]|
|7.1087|Database Index — Read vs Write Tradeoff|2|[ ]|
|7.1088|Async I/O — Throughput vs Latency|2|[ ]|
|7.1089|Serialization — JSON vs Protobuf vs MessagePack|2|[ ]|
|7.1090|Compression — CPU vs Bandwidth|2|[ ]|
|7.1091|Performance Regression — Detection in CI|2|[ ]|
|7.1092|N+1 Queries at Scale — Consequences|2|[ ]|
|7.1093|Bulk Operations — Performance Pattern|2|[ ]|
|7.1094|Connection Pool — Configuration|2|[ ]|
|7.1095|Read Replicas — Latency Routing|2|[ ]|
|7.1096|Heap Snapshots — Production Analysis|2|[ ]|
|7.1097|SIMD — System Design Relevance|3|[ ]|
|7.1098|Lock Contention — Detection and Fix|2|[ ]|
|7.1099|StringBuilder vs String — Hot Path|3|[ ]|
|7.1100|ArrayPool and ObjectPool at Scale|2|[ ]|

---

## Group AE — Security Architecture (7.1101–7.1145)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1101|Defense in Depth — Layered Security|1|[ ]|
|7.1102|Zero Trust Architecture|1|[ ]|
|7.1103|Zero Trust — .NET and Azure Implementation|2|[ ]|
|7.1104|Threat Modeling — STRIDE|2|[ ]|
|7.1105|Threat Modeling — PASTA|3|[ ]|
|7.1106|Threat Modeling — Data Flow Diagrams|2|[ ]|
|7.1107|Secrets Management — Azure Key Vault|1|[ ]|
|7.1108|Secrets Management — HashiCorp Vault|2|[ ]|
|7.1109|Secrets Management — .NET User Secrets|2|[ ]|
|7.1110|IAM — Architecture Overview|2|[ ]|
|7.1111|OAuth 2.0 — Authorization Code with PKCE|2|[ ]|
|7.1112|OAuth 2.0 — Client Credentials Flow|2|[ ]|
|7.1113|OAuth 2.0 — Device Code Flow|2|[ ]|
|7.1114|OAuth 2.0 — Token Introspection|2|[ ]|
|7.1115|OAuth 2.0 — Token Revocation|2|[ ]|
|7.1116|OpenID Connect — ID Token and Flows|2|[ ]|
|7.1117|OpenID Connect — UserInfo Endpoint|2|[ ]|
|7.1118|JWT — Anatomy — Header, Payload, Signature|1|[ ]|
|7.1119|JWT — Signing — HS256 vs RS256 vs ES256|2|[ ]|
|7.1120|JWT — Access vs Refresh Token Lifecycle|2|[ ]|
|7.1121|JWT — Refresh Token Rotation|2|[ ]|
|7.1122|JWT — JWK — JSON Web Keys|2|[ ]|
|7.1123|API Security — Key Management|2|[ ]|
|7.1124|API Security — HMAC Signing|2|[ ]|
|7.1125|API Gateway — Auth Offloading|2|[ ]|
|7.1126|CORS — Same-Origin Policy|2|[ ]|
|7.1127|CORS — Wildcard Anti-Pattern|2|[ ]|
|7.1128|Security Headers — CSP, HSTS, X-Frame|2|[ ]|
|7.1129|Input Validation at System Boundary|2|[ ]|
|7.1130|WAF — Web Application Firewall|2|[ ]|
|7.1131|DDoS Protection Architecture|2|[ ]|
|7.1132|Encryption at Rest — Key Management|2|[ ]|
|7.1133|Data Masking and Tokenization|2|[ ]|
|7.1134|Audit Logging Architecture|2|[ ]|
|7.1135|GDPR — Technical Implications|2|[ ]|
|7.1136|PCI-DSS — Architecture Requirements|2|[ ]|
|7.1137|SOC 2 — Technical Controls|3|[ ]|
|7.1138|SSRF — Server-Side Request Forgery|2|[ ]|
|7.1139|Injection Prevention at Architecture|2|[ ]|
|7.1140|Certificate Management at Scale|2|[ ]|
|7.1141|API Key Rotation — Zero Downtime|2|[ ]|
|7.1142|mTLS — Service-to-Service|2|[ ]|
|7.1143|Supply Chain Security — Dependencies|2|[ ]|
|7.1144|Security Scanning in CI/CD|2|[ ]|
|7.1145|Privilege Escalation — Prevention|2|[ ]|

---

## Group AF — Classic System Design Problems (7.1146–7.1310)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1146|Design URL Shortener — Requirements and Scale|1|[ ]|
|7.1147|Design URL Shortener — Short Code Generation|2|[ ]|
|7.1148|Design URL Shortener — Database Schema|2|[ ]|
|7.1149|Design URL Shortener — Caching Layer|2|[ ]|
|7.1150|Design URL Shortener — Analytics|2|[ ]|
|7.1151|Design Rate Limiter — Requirements|1|[ ]|
|7.1152|Design Rate Limiter — Algorithm Selection|2|[ ]|
|7.1153|Design Rate Limiter — Distributed with Redis|2|[ ]|
|7.1154|Design Rate Limiter — Multi-Tier Limiting|2|[ ]|
|7.1155|Design Notification Service — Requirements|1|[ ]|
|7.1156|Design Notification Service — Push Architecture|2|[ ]|
|7.1157|Design Notification Service — Email Delivery|2|[ ]|
|7.1158|Design Notification Service — SMS|2|[ ]|
|7.1159|Design Notification Service — Fan-Out|2|[ ]|
|7.1160|Design Chat System — Requirements (WhatsApp Scale)|1|[ ]|
|7.1161|Design Chat System — WebSocket Management|2|[ ]|
|7.1162|Design Chat System — Message Storage|2|[ ]|
|7.1163|Design Chat System — Online Presence|2|[ ]|
|7.1164|Design Chat System — Group Chat|2|[ ]|
|7.1165|Design Chat System — E2E Encryption|2|[ ]|
|7.1166|Design Video Streaming — Requirements|1|[ ]|
|7.1167|Design Video Streaming — Upload Pipeline|2|[ ]|
|7.1168|Design Video Streaming — Transcoding|2|[ ]|
|7.1169|Design Video Streaming — CDN Distribution|2|[ ]|
|7.1170|Design Video Streaming — Adaptive Bitrate|2|[ ]|
|7.1171|Design News Feed — Requirements (Twitter Scale)|1|[ ]|
|7.1172|Design News Feed — Fan-Out on Write|2|[ ]|
|7.1173|Design News Feed — Fan-Out on Read|2|[ ]|
|7.1174|Design News Feed — Hybrid Fan-Out|2|[ ]|
|7.1175|Design News Feed — Storage and Ranking|2|[ ]|
|7.1176|Design Search Autocomplete — Requirements|1|[ ]|
|7.1177|Design Search Autocomplete — Trie Architecture|2|[ ]|
|7.1178|Design Search Autocomplete — Top-K Frequencies|2|[ ]|
|7.1179|Design Search Autocomplete — Distributed Trie|2|[ ]|
|7.1180|Design Search Autocomplete — Personalization|2|[ ]|
|7.1181|Design Distributed Cache — Requirements|1|[ ]|
|7.1182|Design Distributed Cache — Consistent Hashing|2|[ ]|
|7.1183|Design Distributed Cache — Eviction|2|[ ]|
|7.1184|Design Distributed Cache — Replication|2|[ ]|
|7.1185|Design Payment System — Requirements|1|[ ]|
|7.1186|Design Payment System — Idempotency|2|[ ]|
|7.1187|Design Payment System — Exactly-Once|2|[ ]|
|7.1188|Design Payment System — Reconciliation|2|[ ]|
|7.1189|Design Ride-Sharing — Requirements|1|[ ]|
|7.1190|Design Ride-Sharing — Geospatial Indexing|2|[ ]|
|7.1191|Design Ride-Sharing — Driver Matching|2|[ ]|
|7.1192|Design Ride-Sharing — Real-Time Location|2|[ ]|
|7.1193|Design Ride-Sharing — Trip State Machine|2|[ ]|
|7.1194|Design Web Crawler — Requirements|2|[ ]|
|7.1195|Design Web Crawler — URL Frontier|2|[ ]|
|7.1196|Design Web Crawler — Politeness|2|[ ]|
|7.1197|Design Web Crawler — Distributed|2|[ ]|
|7.1198|Design Google Drive — Requirements|1|[ ]|
|7.1199|Design Google Drive — Chunked Upload|2|[ ]|
|7.1200|Design Google Drive — Sync Protocol|2|[ ]|
|7.1201|Design Google Drive — Conflict Resolution|2|[ ]|
|7.1202|Design Key-Value Store — Requirements|1|[ ]|
|7.1203|Design Key-Value Store — Partitioning|2|[ ]|
|7.1204|Design Key-Value Store — Replication|2|[ ]|
|7.1205|Design Key-Value Store — Consistency|2|[ ]|
|7.1206|Design Unique ID Generator — Requirements|1|[ ]|
|7.1207|Design Unique ID Generator — Snowflake|2|[ ]|
|7.1208|Design Unique ID Generator — ULID|2|[ ]|
|7.1209|Design Unique ID Generator — Distributed|2|[ ]|
|7.1210|Design Search Engine — Inverted Index|2|[ ]|
|7.1211|Design Search Engine — Indexing Pipeline|2|[ ]|
|7.1212|Design Search Engine — Ranking|2|[ ]|
|7.1213|Design Leaderboard — Redis Sorted Sets|2|[ ]|
|7.1214|Design Ticket Booking — Concurrency|2|[ ]|
|7.1215|Design Ticket Booking — Seat Reservation TTL|2|[ ]|
|7.1216|Design Ad Click Aggregator — Lambda|2|[ ]|
|7.1217|Design Ad Click Aggregator — Stream Processing|2|[ ]|
|7.1218|Design Proximity Service — Geohash|2|[ ]|
|7.1219|Design Proximity Service — Quadtree|2|[ ]|
|7.1220|Design Proximity Service — Google S2|3|[ ]|
|7.1221|Design Hotel Reservation System|2|[ ]|
|7.1222|Design Stock Exchange — Order Book|2|[ ]|
|7.1223|Design Email Service — Architecture|2|[ ]|
|7.1224|Design Metrics and Monitoring System|2|[ ]|
|7.1225|Design Distributed Message Queue|2|[ ]|
|7.1226|Design Live Comment System|2|[ ]|
|7.1227|Design API Gateway — From Scratch|2|[ ]|
|7.1228|Design CDN — From Scratch|2|[ ]|
|7.1229|Design Collaborative Document Editing|2|[ ]|
|7.1230|Design IoT Data Platform|3|[ ]|
|7.1231|Design Fraud Detection — Real-Time|2|[ ]|
|7.1232|Design Recommendation Engine|2|[ ]|
|7.1233|Design Location-Based Services|2|[ ]|
|7.1234|Design Event Ticketing — Flash Sale|2|[ ]|
|7.1235|Design Multiplayer Game Server|3|[ ]|
|7.1236|Design Distributed Scheduler|2|[ ]|
|7.1237|Design Content Moderation System|2|[ ]|
|7.1238|Design Social Graph — Connections at Scale|2|[ ]|
|7.1239|Design Live Streaming Platform — Requirements|2|[ ]|
|7.1240|Design Live Streaming — Ingest Pipeline|2|[ ]|
|7.1241|Design E-Commerce Product Catalog|2|[ ]|
|7.1242|Design Shopping Cart — Consistency|2|[ ]|
|7.1243|Design Order Management System|2|[ ]|
|7.1244|Design Inventory System — Overselling Prevention|2|[ ]|
|7.1245|Design Multi-Tenant SaaS Platform|2|[ ]|
|7.1246|Design Audit Log System|2|[ ]|
|7.1247|Design Notification Preferences System|2|[ ]|
|7.1248|Design Coupon and Discount Service|2|[ ]|
|7.1249|Design Time-Series Metrics Store|2|[ ]|
|7.1250|Design Feature Flag Service|2|[ ]|
|7.1251|Design A/B Testing Platform|2|[ ]|
|7.1252|Design File Conversion Service|3|[ ]|
|7.1253|Design Background Job Scheduler|2|[ ]|
|7.1254|Design Service Health Dashboard|2|[ ]|
|7.1255|Design Distributed Configuration Store|2|[ ]|
|7.1256|Design API Analytics Platform|2|[ ]|
|7.1257|Design Subscription Billing System|2|[ ]|
|7.1258|Design Customer Support Ticketing System|3|[ ]|
|7.1259|Design Real-Time Sports Scores|2|[ ]|
|7.1260|Design Auction System|2|[ ]|
|7.1261|Design Trending Topics — Twitter-Scale|2|[ ]|
|7.1262|Design Comments System at Scale|2|[ ]|
|7.1263|Design Image Processing Pipeline|2|[ ]|
|7.1264|Design Document Signing Service|3|[ ]|
|7.1265|Design Multi-Region Failover Strategy|2|[ ]|
|7.1266|Design Zero-Downtime Database Migration|2|[ ]|
|7.1267|Design Distributed Configuration — etcd|2|[ ]|
|7.1268|Design Webhook Platform|2|[ ]|
|7.1269|Design Event Sourcing Platform|2|[ ]|
|7.1270|Design Microservice Authorization System|2|[ ]|
|7.1271|Design Log Aggregation System|2|[ ]|
|7.1272|Design Distributed Tracing System|2|[ ]|
|7.1273|Design CI/CD Pipeline System|3|[ ]|
|7.1274|Design Container Orchestration (K8s-level)|3|[ ]|
|7.1275|Design Cloud Storage (S3-level)|2|[ ]|
|7.1276|Design DNS System|2|[ ]|
|7.1277|Design Load Balancer — From Scratch|2|[ ]|
|7.1278|Design Message Broker — From Scratch|2|[ ]|
|7.1279|Design Caching System — From Scratch|2|[ ]|
|7.1280|Design Rate Limiting Service — Standalone|2|[ ]|
|7.1281|Design Service Registry — Eureka-Style|2|[ ]|
|7.1282|Design Pub/Sub System|2|[ ]|
|7.1283|Design Workflow Engine|2|[ ]|
|7.1284|Design Permission/RBAC System|2|[ ]|
|7.1285|Design Reporting and Analytics Service|2|[ ]|
|7.1286|Design Data Export Service — Large Datasets|2|[ ]|
|7.1287|Design Bulk Import Service|2|[ ]|
|7.1288|Design Multi-Currency Payment System|2|[ ]|
|7.1289|Design KYC Verification Service|3|[ ]|
|7.1290|Design Escrow Payment Service|3|[ ]|
|7.1291|Design Insurance Quote Engine|3|[ ]|
|7.1292|Design Vehicle Fleet Tracking|3|[ ]|
|7.1293|Design Supply Chain System|3|[ ]|
|7.1294|Design Clinical Trial Data Platform|3|[ ]|
|7.1295|Design Drug Interaction Checker|3|[ ]|
|7.1296|Design Smart Grid Energy System|4|[ ]|
|7.1297|Design High-Frequency Trading Platform|3|[ ]|
|7.1298|Design Real Estate Listing Platform|3|[ ]|
|7.1299|Design Healthcare Appointment System|3|[ ]|
|7.1300|Design Food Delivery Platform|2|[ ]|
|7.1301|Design Travel Booking System|2|[ ]|
|7.1302|Design Movie Ticket Booking|2|[ ]|
|7.1303|Design Music Streaming Platform|2|[ ]|
|7.1304|Design Podcast Distribution System|3|[ ]|
|7.1305|Design Q&A Platform (Stack Overflow-Scale)|2|[ ]|
|7.1306|Design Code Review Platform|3|[ ]|
|7.1307|Design SaaS Multi-Tenant Architecture|2|[ ]|
|7.1308|Design Developer Portal|3|[ ]|
|7.1309|Design API Marketplace|3|[ ]|
|7.1310|Design Serverless Platform|3|[ ]|

---

## Group AG — System Design Interview Process (7.1311–7.1355)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|7.1311|System Design Interview — Structured Approach|1|[ ]|
|7.1312|System Design — Clarifying Functional Requirements|1|[ ]|
|7.1313|System Design — Non-Functional Requirements|1|[ ]|
|7.1314|System Design — Scale Estimation Step|1|[ ]|
|7.1315|System Design — High-Level Design Drawing|1|[ ]|
|7.1316|System Design — Component Deep Dive|2|[ ]|
|7.1317|System Design — Failure Mode Analysis|2|[ ]|
|7.1318|System Design — Wrap-Up and Tradeoffs|2|[ ]|
|7.1319|System Design — Common Mistakes|2|[ ]|
|7.1320|System Design — Driving the Conversation|2|[ ]|
|7.1321|System Design — Clarification Questions Bank|2|[ ]|
|7.1322|System Design — Scale Estimation Drills|2|[ ]|
|7.1323|System Design — Drawing Clarity Standards|2|[ ]|
|7.1324|Back-of-Envelope — QPS Formula|1|[ ]|
|7.1325|Back-of-Envelope — Storage Formula|1|[ ]|
|7.1326|Back-of-Envelope — Bandwidth Formula|1|[ ]|
|7.1327|Back-of-Envelope — Memory Estimation|2|[ ]|
|7.1328|Back-of-Envelope — Reference Numbers to Memorize|1|[ ]|
|7.1329|System Design — Reading Engineering Blogs|2|[ ]|
|7.1330|System Design — Post-Mortem Reading List|2|[ ]|
|7.1331|Architecture Decision Records — System Level|2|[ ]|
|7.1332|Conway's Law — Technical Implications|2|[ ]|
|7.1333|Technical Debt at System Scale|2|[ ]|
|7.1334|Evolutionary Architecture|2|[ ]|
|7.1335|Fitness Functions for Architecture|3|[ ]|
|7.1336|Platform Engineering|3|[ ]|
|7.1337|Internal Developer Platforms|3|[ ]|
|7.1338|API-First Design Strategy|2|[ ]|
|7.1339|Design for Failure — Principles|2|[ ]|
|7.1340|Design for Operability|2|[ ]|
|7.1341|System Design — 30 Core Problems Index|2|[ ]|
|7.1342|System Design — Whiteboard Communication|2|[ ]|
|7.1343|System Design — Time Management in Interview|2|[ ]|
|7.1344|System Design — When to Go Deep vs Broad|2|[ ]|
|7.1345|System Design — Vocabulary and Naming|2|[ ]|
|7.1346|System Design — Evaluating Your Own Design|2|[ ]|
|7.1347|System Design — Handling Ambiguous Requirements|2|[ ]|
|7.1348|System Design — Estimation Under Pressure|2|[ ]|
|7.1349|System Design — Senior vs Staff Level Expectations|2|[ ]|
|7.1350|System Design — Explaining Tradeoffs Clearly|2|[ ]|
|7.1351|System Design — Database Selection Interview|2|[ ]|
|7.1352|System Design — Caching Interview|2|[ ]|
|7.1353|System Design — Messaging Interview|2|[ ]|
|7.1354|System Design — Consistency vs Availability Interview|2|[ ]|
|7.1355|System Design — Full Interview Simulation Notes|2|[ ]|

---

## Generation Order by Priority

### Tier 1 — Critical (Generate First)

|#|ID|Topic|
|---|---|---|
|1|7.001|Clean Architecture — The Dependency Rule|
|2|7.017|Modular Monolith|
|3|7.031|DDD — Strategic vs Tactical|
|4|7.033|DDD — Bounded Contexts|
|5|7.043|DDD — Entities|
|6|7.045|DDD — Value Objects|
|7|7.047|DDD — Aggregates|
|8|7.048|DDD — Aggregate Root Rule|
|9|7.081|CQRS — Overview|
|10|7.084|CQRS — MediatR|
|11|7.085|CQRS — Pipeline Behaviors|
|12|7.101|Event Sourcing — Events as Truth|
|13|7.121|Outbox Pattern|
|14|7.129|Saga Pattern|
|15|7.142|Event-Driven Architecture|
|16|7.156|CAP Theorem|
|17|7.157|CAP — CP Systems|
|18|7.158|CAP — AP Systems|
|19|7.161|Strong Consistency|
|20|7.162|Eventual Consistency|
|21|7.171|Consensus|
|22|7.183|2PC|
|23|7.186|Sagas vs 2PC|
|24|7.187|Idempotency|
|25|7.190|At-Most-Once|
|26|7.191|At-Least-Once|
|27|7.192|Exactly-Once|
|28|7.206|Horizontal vs Vertical Scaling|
|29|7.207|Stateless Services|
|30|7.210|Load Balancing|
|31|7.219|Read Replicas|
|32|7.222|Database Sharding|
|33|7.229|Consistent Hashing|
|34|7.241|Rate Limiting — Token Bucket|
|35|7.246|Rate Limiting — Distributed Redis|
|36|7.256|Caching — Why and When|
|37|7.257|Cache-Aside|
|38|7.267|Cache Invalidation|
|39|7.275|Distributed vs In-Process Cache|
|40|7.340|Broker Decision Matrix|
|41|7.370|Kafka vs RabbitMQ vs Service Bus|
|42|7.371|Monolith vs Microservices|
|43|7.372|Modular Monolith First|
|44|7.378|Database per Service|
|45|7.380|Sync vs Async Decision|
|46|7.384|API Gateway|
|47|7.415|gRPC vs REST|
|48|7.421|Data Consistency in Microservices|
|49|7.426|Resilience Engineering|
|50|7.431|Circuit Breaker|
|51|7.451|REST Constraints|
|52|7.456|Resource Naming|
|53|7.466|API Versioning — URL Path|
|54|7.472|Idempotency Keys|
|55|7.473|Pagination — Offset|
|56|7.478|Error Response RFC 9457|
|57|7.506|WebSockets|
|58|7.519|WebSockets vs SSE vs Long Polling|
|59|7.526|DNS Resolution|
|60|7.534|HTTP/2 Multiplexing|
|61|7.548|CDN Architecture|
|62|7.566|Object Storage|
|63|7.576|Block vs Object vs File|
|64|7.621|Full-Text Search Inverted Index|
|65|7.651|SLI|
|66|7.652|SLO|
|67|7.655|Availability 9s|
|68|7.668|Health Checks|
|69|7.691|Blue-Green Deployment|
|70|7.700|DB Migrations Zero Downtime|
|71|7.716|Observability Three Pillars|
|72|7.717|Structured Logging|
|73|7.718|Serilog|
|74|7.726|Correlation ID|
|75|7.741|Metrics|
|76|7.759|OpenTelemetry|
|77|7.767|Distributed Tracing|
|78|7.772|P99 Latency|
|79|7.776|Azure Well-Architected|
|80|7.802|Cosmos DB Partition Key|
|81|7.822|Azure Key Vault|
|82|7.846|Docker Image Layers|
|83|7.849|Docker Multi-Stage|
|84|7.866|Kubernetes Control Plane|
|85|7.868|Kubernetes Pod Lifecycle|
|86|7.871|Kubernetes Deployment|
|87|7.916|CI/CD Fundamentals|
|88|7.929|GitHub Actions .NET Pipeline|
|89|7.956|NoSQL Decision Framework|
|90|7.1065|QPS Estimation|
|91|7.1066|Storage Estimation|
|92|7.1067|Bandwidth Estimation|
|93|7.1069|Latency Numbers|
|94|7.1101|Defense in Depth|
|95|7.1102|Zero Trust|
|96|7.1107|Secrets — Key Vault|
|97|7.1118|JWT Anatomy|
|98|7.1146|Design URL Shortener|
|99|7.1151|Design Rate Limiter|
|100|7.1155|Design Notification Service|
|101|7.1160|Design Chat System|
|102|7.1166|Design Video Streaming|
|103|7.1171|Design News Feed|
|104|7.1176|Design Autocomplete|
|105|7.1181|Design Distributed Cache|
|106|7.1185|Design Payment System|
|107|7.1189|Design Ride-Sharing|
|108|7.1198|Design Google Drive|
|109|7.1202|Design Key-Value Store|
|110|7.1206|Design Unique ID Generator|
|111|7.1311|Interview — Structured Approach|
|112|7.1312|Interview — Functional Requirements|
|113|7.1313|Interview — Non-Functional|
|114|7.1314|Interview — Scale Estimation|
|115|7.1315|Interview — High-Level Design|
|116|7.1324|Back-of-Envelope — QPS|
|117|7.1325|Back-of-Envelope — Storage|
|118|7.1326|Back-of-Envelope — Bandwidth|
|119|7.1328|Reference Numbers|

---

_Domain 7 — System Design & Distributed Systems | 1,355 topics | 33 groups_ _Tags: #engineering #knowledge-base #system-design #distributed-systems #dotnet_