---
title: "ASP.NET Core Domain - Complete Topic Index"
type: "master-index"
domain: "ASP.NET Core Mastery"
status: "active"
tags:
  - aspnetcore
  - dotnet
  - roadmap
  - study-plan
  - mastery
created: 2026-06-07
studied_well: false
---


> **Purpose of this file:** The master list of every topic in the ASP.NET Core Mastery domain. Use it to track progress, pick the next topic to generate, and copy the `RELATED_TOPICS` value directly into the generation prompt. This domain intentionally covers all levels — beginner through expert — and all major subsystems of ASP.NET Core.

---

## PROGRESS TRACKER

```
Total Topics:  252
Generated:       0
Remaining:     252
```

**Status Legend**

- ✅ Complete — note generated, reviewed
- 🔄 In Progress — being written
- ⬜ Not Started — queued

---

## DOMAIN MAP — ASP.NET CORE SUBSYSTEMS

```
ASP.NET Core Mastery
│
├── A. Host & Application Lifecycle       (4.001–4.010)
├── B. Configuration System               (4.011–4.022)
├── C. Logging & Diagnostics              (4.023–4.033)
├── D. Dependency Injection               (4.034–4.048)
├── E. Middleware Pipeline                (4.049–4.063)
├── F. Routing System                     (4.064–4.077)
├── G. Minimal APIs                       (4.078–4.097)
├── H. MVC & Controllers                  (4.098–4.122)
├── I. HTTP Fundamentals                  (4.123–4.133)
├── J. Authentication                     (4.134–4.153)
├── K. Authorization                      (4.154–4.166)
├── L. Validation                         (4.167–4.176)
├── M. Error Handling & Problem Details   (4.177–4.185)
├── N. Caching & Output                   (4.186–4.201)
├── O. Rate Limiting                      (4.202–4.207)
├── P. Security                           (4.208–4.218)
├── Q. SignalR & Real-Time                (4.219–4.230)
├── R. Background Services                (4.231–4.239)
├── S. gRPC                               (4.240–4.248)
├── T. HttpClientFactory & HTTP Clients   (4.249–4.256)
├── U. Testing                            (4.257–4.267)
├── V. Serialization                      (4.268–4.276)
├── W. API Design Patterns                (4.277–4.287)
├── X. Filters (MVC & Endpoint)           (4.288–4.296)
├── Y. Observability & OpenTelemetry      (4.297–4.307)
├── Z. Globalization & Localization       (4.308–4.314)
├── AA. File Handling & Static Files      (4.315–4.322)
├── AB. Health Checks                     (4.323–4.327)
├── AC. Deployment & Hosting              (4.328–4.339)
└── AD. Advanced & Internals              (4.340–4.352)
```

---

## STUDY PRIORITY GUIDE

Before picking what to generate next, use this priority map:

```
TIER 1 — Generate First (beginner foundation + interview critical)
  4.001    The ASP.NET Core Request Pipeline: A Mental Model
  4.002    WebApplication and WebApplicationBuilder: The New Hosting Model
  4.003    IWebHostEnvironment: Environments and ASPNETCORE_ENVIRONMENT
  4.011    IConfiguration: The Layered Configuration System
  4.012    Configuration Providers: JSON, Env Vars, Command Line, In-Memory
  4.016    IOptions<T>: The Type-Safe Configuration Binding Pattern
  4.023    ILogger<T>: The .NET Logging Abstraction
  4.024    Log Levels, Categories, and Filtering
  4.034    The Built-In DI Container: Service Registration and Resolution
  4.035    Service Lifetimes: Singleton, Scoped, Transient — Rules and Pitfalls
  4.049    The Middleware Pipeline: Request Delegation Chain
  4.050    Writing Middleware: IMiddleware vs Convention-Based
  4.052    Middleware Ordering: The Canonical Order and Why It Matters
  4.064    Endpoint Routing: The Modern Routing System
  4.065    Route Templates: Syntax, Parameters, Constraints, and Wildcards
  4.078    Minimal APIs: Why They Exist and When to Use Them
  4.079    Defining Endpoints: MapGet, MapPost, MapPut, MapDelete
  4.080    Route Parameter Binding in Minimal APIs
  4.082    IResult and TypedResults: Shaping HTTP Responses
  4.098    ControllerBase vs Controller: API vs MVC Controllers
  4.099    Action Results: IActionResult, ActionResult<T>, and Typed Results
  4.100    Model Binding: Sources, Order, and How It Works
  4.102    Model Validation: DataAnnotations and ModelState
  4.134    Authentication Architecture: Schemes, Handlers, and Middleware
  4.136    JWT Bearer Authentication: AddJwtBearer and Token Validation
  4.137    Generating JWT Access Tokens with Claims
  4.154    Authorization Architecture: Middleware, Policies, and Requirements
  4.155    Role-Based and Claims-Based Authorization
  4.167    DataAnnotations Validation in ASP.NET Core
  4.177    Exception Handling Middleware: UseExceptionHandler
  4.179    Problem Details (RFC 7807): IProblemDetailsService

TIER 2 — Generate Second (production daily use + interview important)
  4.004    Generic Host (IHost): Configuration and Application Lifecycle
  4.005    IHostedService and IHostApplicationLifetime
  4.007    Kestrel: The Edge Web Server — Configuration and Limits
  4.013    User Secrets: Development-Time Secret Management
  4.017    IOptionsSnapshot<T> vs IOptionsMonitor<T>: Hot Reload
  4.018    Named Options: Multiple Instances of the Same Configuration Type
  4.019    Options Validation: Fail-Fast on Startup with ValidateOnBuild
  4.025    Structured Logging: Log Templates and Semantic Values
  4.026    Log Scopes: Contextual Information Across a Request
  4.028    Serilog Integration: Sinks, Enrichers, and Output Templates
  4.031    High-Performance Logging: LoggerMessage.Define and Source Generators
  4.036    IServiceProvider and IServiceScope: Manual Resolution
  4.037    Factory-Based DI: ImplementationFactory and Func<T>
  4.038    Keyed Services (.NET 8): Named Resolution Without Hacks
  4.040    Multiple Implementations: IEnumerable<T> Registration
  4.042    The Captive Dependency Problem: Singleton → Scoped is a Bug
  4.044    Decorators in the Built-In Container: The Scrutor Pattern
  4.046    Validation of Service Registrations at Startup
  4.051    Short-Circuiting and Pipeline Branching: Map, MapWhen, UseWhen
  4.053    Built-In Middleware Reference and Their Responsibilities
  4.054    HttpContext and IHttpContextAccessor: Thread-Safe Access
  4.055    Custom Exception Middleware: Domain Exceptions to HTTP Responses
  4.057    Middleware and DI: Injecting Scoped Services Correctly
  4.066    Route Constraints: Types, Custom Constraints, and Regex
  4.067    Attribute Routing on Controllers
  4.070    Route Groups: Prefix, Filters, and Metadata Grouping
  4.071    Link Generation: IUrlHelper, LinkGenerator, and Route Values
  4.083    Minimal API Filters: IEndpointFilter Pipeline
  4.084    Route Groups in Minimal APIs: Shared Prefix and Authorization
  4.085    OpenAPI Integration in Minimal APIs: WithOpenApi and Tags
  4.086    Validation in Minimal APIs: IValidator<T> and Manual Validation
  4.089    Authorization on Minimal API Endpoints: RequireAuthorization
  4.092    Minimal API vs MVC Controller: The Decision Framework
  4.093    Organizing Minimal APIs: Extension Methods and Feature Slices
  4.101    ApiController Attribute: Automatic 400, Binding Source Inference
  4.103    Content Type Negotiation: Produces, Consumes, Accept Headers
  4.107    Output Formatters: JSON, XML, and Custom Formatters
  4.110    Controller Filters: The Six Filter Types and Pipeline Order
  4.118    Problem Details in MVC: ValidationProblemDetails and ProblemDetails
  4.123    HttpContext Deep Dive: Features, Items, and Request Lifecycle
  4.124    HttpRequest: Reading URL, Headers, Cookies, and Body
  4.125    HttpResponse: Writing Status Codes, Headers, and Streaming Body
  4.127    HTTP/2: Multiplexing and Kestrel Configuration
  4.135    Cookie Authentication: AddCookie, SignInAsync, ClaimsPrincipal
  4.138    Refresh Token Pattern: Rotation, Storage, and Revocation
  4.139    OAuth 2.0 in ASP.NET Core: Authorization Code and PKCE Flow
  4.140    OpenID Connect: AddOpenIdConnect and Identity Provider Integration
  4.142    ASP.NET Core Identity: UserManager, RoleManager, and IdentityDbContext
  4.143    ASP.NET Core Identity: Password Hashing, Lockout, Two-Factor Auth
  4.148    Multiple Authentication Schemes: Scheme Selection at Endpoint Level
  4.149    Claims Transformation: IClaimsTransformation for Enriching Principals
  4.156    Policy-Based Authorization: AddPolicy, IAuthorizationRequirement
  4.157    IAuthorizationHandler: Implementing Custom Authorization Logic
  4.158    Resource-Based Authorization: Passing Resources to Handlers
  4.159    IAuthorizationService: Programmatic Authorization in Services
  4.163    Authorization in Minimal APIs: RequireAuthorization and Metadata
  4.168    ModelState: Checking Validity, Reading Errors, Custom Responses
  4.170    FluentValidation: Validators, RuleFor, and ASP.NET Core Integration
  4.172    FluentValidation: Async Validators and Database-Level Validation
  4.174    Global Validation Responses: SuppressModelStateInvalidFilter
  4.180    Status Code Pages and Custom Error Responses
  4.181    Exception Filters: Controller-Scoped Exception Handling
  4.182    Global Exception Handler (.NET 8): IExceptionHandler Interface
  4.183    Correlation IDs: Request Tracing Across Services
  4.186    IMemoryCache: In-Process Caching with Expiry, Size, and Priority
  4.187    IDistributedCache: The Abstraction for Out-of-Process Caching
  4.188    Redis as IDistributedCache: StackExchange.Redis Integration
  4.189    Cache-Aside Pattern: Load-on-Miss Strategy
  4.190    Response Caching: Cache-Control Headers and ResponseCache Attribute
  4.191    Output Caching (.NET 7+): Server-Side Response Cache
  4.192    Output Caching Policies: VaryBy, Tags, and Manual Eviction
  4.202    Rate Limiting (.NET 7+): Fixed Window, Sliding Window, Token Bucket, Concurrency
  4.203    Rate Limiting Partitioning: Per-User, Per-IP, Per-API-Key Strategies
  4.208    HTTPS Enforcement: UseHttpsRedirection, HSTS, and Kestrel TLS
  4.209    CORS: UseCors, CorsPolicy, AllowedOrigins, and Preflight Requests
  4.210    CSRF / Antiforgery: IAntiforgery and ValidateAntiforgeryToken
  4.219    SignalR Architecture: Hubs, Connections, and Transport Negotiation
  4.220    SignalR Hubs: Hub<T>, Hub Methods, Caller/Group/All Targeting
  4.231    IHostedService: Running Code on Application Startup
  4.232    BackgroundService: The Base Class for Long-Running Work
  4.233    Timed Background Service: PeriodicTimer for Recurring Jobs
  4.234    Queued Background Tasks: Channel<T>-Based Producer/Consumer
  4.249    IHttpClientFactory: Why HttpClient Must Never Be Newed Directly
  4.250    Named and Typed HTTP Clients: Registration Patterns
  4.251    DelegatingHandler: Message Handler Pipeline for Cross-Cutting Concerns
  4.252    Polly Integration: Retry, Circuit Breaker, and Hedging
  4.257    WebApplicationFactory<T>: Integration Testing the Full Pipeline
  4.258    Customizing WebApplicationFactory: Replacing Services for Tests
  4.259    Authentication in Integration Tests: Fake Auth Schemes
  4.260    Database in Integration Tests: TestContainers vs SQLite vs InMemory
  4.268    System.Text.Json in ASP.NET Core: Global Options Configuration
  4.269    JsonSerializerOptions: Naming, Null Handling, Enum Serialization
  4.277    API Versioning: URL Path, Query String, and Header Strategies
  4.279    OpenAPI / Swagger: Swashbuckle and NSwag Integration
  4.280    OpenAPI in .NET 9: Microsoft.AspNetCore.OpenApi Built-In
  4.288    Filter Pipeline: Six Filter Types and Execution Order
  4.289    Action Filters: IAsyncActionFilter Before and After Execution
  4.297    Activity API: System.Diagnostics.Activity and Distributed Tracing
  4.299    OpenTelemetry .NET SDK: Tracing, Metrics, and Logs
  4.323    Health Check Middleware and Custom IHealthCheck
  4.328    Kestrel Advanced Configuration: Limits, TLS, and Protocol Selection
  4.329    Reverse Proxy: X-Forwarded Headers and ForwardedHeaders Middleware
  4.330    Docker: Containerizing ASP.NET Core Applications
  4.331    Docker: Multi-Stage Builds for Minimal Production Images

TIER 3 — Generate Third (production important, interview moderate)
  4.006    Program.cs Evolution: Startup.cs to Top-Level Statements
  4.008    IIS Hosting: In-Process and Out-of-Process Models
  4.009    Linux Hosting: Nginx Reverse Proxy and Unix Socket Configuration
  4.010    Graceful Shutdown: CancellationToken Propagation and Drain Time
  4.014    Azure Key Vault Provider: Production Secret Management
  4.015    Configuration Hot Reload: Reload-on-Change Without Restart
  4.020    Custom Configuration Providers: Implementing IConfigurationProvider
  4.021    Feature Flags: Microsoft.FeatureManagement in ASP.NET Core
  4.027    Built-In Logging Providers: Console, Debug, EventSource, EventLog
  4.029    NLog Integration in ASP.NET Core
  4.030    Application Insights SDK: Request Tracking and Dependency Telemetry
  4.032    Log Redaction and Sensitive Data Masking in Structured Logs
  4.033    HTTP Logging Middleware (.NET 6+) and W3C Logging
  4.039    Open Generic DI Registration: typeof(IRepository<>)
  4.041    IServiceCollection Extension Methods: Builder Pattern for Libraries
  4.043    Replacing the Built-In Container: Autofac and Lamar
  4.045    IDisposable in DI: Who Owns the Lifetime?
  4.047    DI Scope in Middleware vs Background Services
  4.048    DI with Static Analysis: Source-Generated DI (.NET 8)
  4.056    Response Buffering vs Streaming in Middleware
  4.058    Endpoint Middleware vs Request Middleware: The Distinction
  4.059    Conditional Middleware: Environment-Specific Pipeline
  4.060    Zero-Allocation Middleware: IBufferWriter<byte> and PipeReader
  4.061    Custom Middleware: Cross-Cutting Concerns Catalog
  4.062    Anti-Corruption Middleware: Normalizing Upstream API Responses
  4.063    Middleware Testing: Isolating Middleware from the Full Pipeline
  4.068    Route Order and Precedence: Conflict Resolution Rules
  4.069    Area Routing: Namespace Partitioning for Large Applications
  4.072    Custom Route Constraints: IRouteConstraint Implementation
  4.073    Catch-All Routes, Fallback Routes, and 404 Handling
  4.074    Endpoint Metadata: Decorating Endpoints with Custom Attributes
  4.075    Route Performance: Trie-Based Matching and Route Cache
  4.076    Host and Port Routing: MapWhen with HostString Matching
  4.077    Route Value Transformers: IOutboundParameterTransformer
  4.087    File Upload in Minimal APIs: IFormFile and Large File Streaming
  4.088    Streaming Responses: IAsyncEnumerable<T> and Server-Sent Events
  4.090    Antiforgery in Minimal APIs (.NET 8)
  4.091    Form Binding in Minimal APIs (.NET 8): [FromForm] and IFormCollection
  4.094    Minimal API Source Generators: RequestDelegateGenerator
  4.095    Minimal API Metadata Providers: IEndpointMetadataProvider
  4.096    Minimal API with IResult Customization: IResult and INestedHttpResult
  4.097    Minimal API AOT Compatibility: Trim-Safe Patterns
  4.104    Razor Pages: PageModel, Handlers, and When to Use vs MVC
  4.105    MVC Areas: Code Organization for Large Applications
  4.106    ViewComponents: Encapsulated UI Logic with Razor Rendering
  4.108    Model Binding: Custom Binders and IModelBinder
  4.109    Model Binding: Binding Sources — FromBody, FromRoute, FromQuery, FromHeader
  4.111    Global Model State Validation: Custom Invalid Model State Factory
  4.112    Input Formatters: Deserializing Non-JSON Request Bodies
  4.113    Action Selectors: AcceptVerbs and Custom Selection Attributes
  4.114    API Explorer: ApiDescription and Powering Documentation Tools
  4.115    Application Model Conventions: IControllerModelConvention
  4.116    Controller DI: Constructor Injection vs [FromServices] Inline
  4.117    Async Actions: Task<IActionResult> and Cancellation Token Patterns
  4.119    Response Caching on Controllers: [ResponseCache] and CacheProfiles
  4.120    Binding Large Payloads: Streaming Body and EnableBuffering
  4.121    File Download: FileStreamResult, FileContentResult, PhysicalFileResult
  4.122    Content Negotiation Deep Dive: Accept Header Algorithm
  4.126    Cookies: SameSite Policy, Secure Flag, and HttpOnly Security
  4.128    Sessions: ISession, Cookie Identity, and Distributed Session
  4.129    HTTP/3 and QUIC: ASP.NET Core (.NET 7+) and Kestrel QUIC
  4.130    Request Body Reading Patterns: EnableBuffering and GetRawBodyAsync
  4.131    WebSockets Manual: Low-Level WebSocket API Without SignalR
  4.132    Server-Sent Events Manual: Without SignalR
  4.133    HTTP Connection Features: IHttpConnectionFeature and Raw Access
  4.141    External Login Providers: Google, GitHub, Microsoft via OAuth
  4.144    ASP.NET Core Identity: Custom User Store and IUserStore<T>
  4.145    API Key Authentication: Custom IAuthenticationHandler
  4.146    Certificate Authentication: mTLS with AddCertificate
  4.147    Authentication Events: OnTokenValidated, OnAuthenticationFailed
  4.150    Token Storage Security: HttpOnly Cookies vs Authorization Header
  4.151    IAuthenticationService: Programmatic Auth, Challenge, and Sign-Out
  4.152    Multi-Scheme API Authentication: JWT + Cookie Parallel
  4.153    Auth in Background Services: IServiceScope for Auth Operations
  4.160    Authorization Filters vs Policy Handlers vs Middleware
  4.161    Permission-Based Authorization: Fine-Grained Action Permissions
  4.162    Hierarchical Roles and Dynamic Policy Building
  4.164    Authorization Caching: Avoiding Per-Request Database Hits
  4.165    [AllowAnonymous]: Bypassing Global Authorization Filters
  4.166    Custom [Authorize] Attributes: AuthorizeAttribute Subclassing
  4.169    Custom Validation Attributes: ValidationAttribute and IValidatableObject
  4.171    FluentValidation: Conditional Rules, Severity, and Custom Messages
  4.173    Input Sanitization: Preventing XSS at the Model Binding Layer
  4.175    Validation Across Layers: Where Validation Lives (Domain vs HTTP)
  4.176    Client-Side Validation Coordination: data-val Attributes
  4.178    Developer Exception Page: UseDevExceptionPage and Diagnostics
  4.184    Error Monitoring: Structured Exceptions and Alert Integration
  4.185    Retry-After Headers and Transient Error Signaling
  4.193    Cache Stampede: GetOrCreateAsync Locking Patterns
  4.194    Distributed Cache Serialization: System.Text.Json and MessagePack
  4.195    HTTP Caching Headers: ETags, Last-Modified, and Conditional Requests
  4.196    HybridCache (.NET 9): Unified In-Process and Distributed Cache
  4.197    Response Compression: UseResponseCompression, Gzip, and Brotli
  4.198    Request Decompression (.NET 7+): UseRequestDecompression
  4.199    Request Timeouts (.NET 8): IHttpRequestTimeoutFeature
  4.200    Minimal Allocation Patterns: PipeReader and IBufferWriter<byte>
  4.201    Connection Pool Tuning: MaxConnections and Socket Lifetime
  4.204    Rate Limiting Events: OnRejected and Custom Rejection Responses
  4.205    Rate Limiting with Redis: Distributed Rate Limit State
  4.206    Rate Limiting Response Headers: RateLimit-* Standard Headers
  4.207    Combining Rate Limiting and Auth: Per-User API Quotas
  4.211    Data Protection API: IDataProtector, Key Ring, and Purpose Strings
  4.212    Data Protection: Key Management, Key Rotation, and Azure Key Ring
  4.213    Security Headers Middleware: X-Frame-Options, CSP, HSTS Preload
  4.214    XSS Prevention: Output Encoding and Content Security Policy
  4.215    IDOR Prevention: Resource Ownership in Authorization Handlers
  4.216    SQL Injection in ASP.NET Core: EF Core Safety vs Raw SQL Risk
  4.217    Secrets in Production: Key Vault, Managed Identity, and No appsettings
  4.218    OWASP Top 10 Applied to ASP.NET Core APIs
  4.221    SignalR Transports: WebSockets, SSE, Long Polling Negotiation
  4.222    SignalR Scale-Out: Redis Backplane and Azure SignalR Service
  4.223    SignalR Authentication: JWT in WebSocket Connection Upgrade
  4.224    SignalR Groups: Managing Group Membership and Targeted Sends
  4.225    SignalR Streaming: IAsyncEnumerable<T> from Hub to Client
  4.226    SignalR .NET Client: HubConnection and Reconnect Strategies
  4.227    SignalR JavaScript Client: hubConnection.on and invoke
  4.228    SignalR with Minimal APIs: MapHub and Authorization
  4.229    Server-Sent Events with IAsyncEnumerable<T>
  4.230    Long Polling: When and How Without SignalR
  4.235    Scoped Services in BackgroundService: IServiceScopeFactory Pattern
  4.236    Worker Services: Console Host with Background Processing
  4.237    Graceful Shutdown in Background Services: CancellationToken Contract
  4.238    Hangfire Integration: Recurring Jobs and Fire-and-Forget in ASP.NET Core
  4.239    Health Checks for Background Services: Signaling Worker Liveness
  4.240    gRPC in ASP.NET Core: Proto Contracts and Service Implementation
  4.241    gRPC Streaming: Unary, Server, Client, and Bidirectional
  4.242    gRPC Authentication: JWT and Certificate Interceptors
  4.243    gRPC Error Handling: StatusCode and RpcException
  4.244    gRPC Interceptors: Server-Side and Client-Side Cross-Cutting Concerns
  4.245    gRPC-Web: Browser Support via Grpc.AspNetCore.Web
  4.246    gRPC Client Factory: AddGrpcClient<T> and Typed Clients
  4.247    gRPC JSON Transcoding: REST-to-gRPC Translation Layer
  4.248    gRPC vs REST vs GraphQL: Decision Framework
  4.253    HttpClient Timeout and CancellationToken Patterns
  4.254    HttpClient Logging: Built-In Logging and Custom Handlers
  4.255    Primary HttpMessageHandler Lifetime and Socket Exhaustion
  4.256    HttpClient with Credentials: Auth Headers and Certificate Clients
  4.261    Testing Middleware in Isolation: TestServer Without WebAppFactory
  4.262    Testing SignalR: HubConnection in Integration Tests
  4.263    Testing Background Services: IHostedService Test Harnesses
  4.264    Mocking HttpClient: MockHttpMessageHandler Pattern
  4.265    Snapshot Testing for API Responses: Verify Library
  4.266    Contract Testing: Pact for Consumer-Driven API Contracts
  4.267    Load Testing ASP.NET Core: k6, NBomber, and BenchmarkDotNet
  4.270    Custom JSON Converters: JsonConverter<T> for Complex Types
  4.271    JSON Source Generation: [JsonSerializable] and Zero-Reflection
  4.272    Newtonsoft.Json Migration: AddNewtonsoftJson Compatibility
  4.273    XML Serialization: AddXmlSerializerFormatters in ASP.NET Core
  4.274    MessagePack Serialization: Binary for gRPC and SignalR
  4.275    Custom Input/Output Formatters: IInputFormatter and IOutputFormatter
  4.276    Polymorphic JSON Serialization: [JsonDerivedType] (.NET 7+)
  4.278    Asp.Versioning: AddApiVersioning and MapToApiVersion
  4.281    Scalar: The Modern OpenAPI UI Alternative to Swagger UI
  4.282    GraphQL in ASP.NET Core: Hot Chocolate Integration
  4.283    REST API Design Conventions in ASP.NET Core
  4.284    Idempotency Keys: Preventing Duplicate POST Operations
  4.285    Pagination in REST APIs: Keyset and Offset with Link Headers
  4.286    HATEOAS: Hypermedia Controls in API Responses
  4.287    API Deprecation: Sunset Headers and Version Sunset Policies
  4.290    Result Filters: IAsyncResultFilter Before and After Response
  4.291    Exception Filters: Scoped Exception Handling in MVC
  4.292    Resource Filters: IAsyncResourceFilter Before Model Binding
  4.293    Authorization Filters: IAsyncAuthorizationFilter — First in Pipeline
  4.294    Global Filters: Registering Application-Wide Filter Behavior
  4.295    Filter Ordering: IOrderedFilter and Execution Sequence
  4.296    DI in Filters: ServiceFilter vs TypeFilter vs Constructor Injection
  4.298    DiagnosticSource and DiagnosticListener: Internal Event Bus
  4.300    OpenTelemetry: Exporting to Jaeger, Zipkin, and OTLP Collector
  4.301    Metrics in .NET 8+: System.Diagnostics.Metrics and IMeterFactory
  4.302    Prometheus Metrics: prometheus-net in ASP.NET Core
  4.303    Application Insights: Dependency Tracking and Custom Telemetry
  4.304    EventSource and EventCounter: High-Performance Runtime Metrics
  4.305    QueryTagWith and SQL Annotation: Correlating App and DB Traces
  4.308    IStringLocalizer<T>: Resource-Based Localization
  4.309    Request Localization Middleware: Culture Providers and Selection
  4.310    Resource Files: .resx Files and XLIFF for Translation Teams
  4.311    Date, Number, and Currency Formatting by Culture
  4.312    Right-to-Left (RTL) Layout Support in ASP.NET Core
  4.313    PO File Localization: OrchardCore Localization Alternative
  4.314    Localization in Minimal APIs and Validation Messages
  4.315    Static Files Middleware: UseStaticFiles and wwwroot
  4.316    Physical File Provider: Reading Files from Disk in Middleware
  4.317    File Upload: IFormFile, Streaming Large Files, and Antivirus Hooks
  4.318    File Download: Streaming from Blob Storage with Range Support
  4.319    Virtual File System: EmbeddedFileProvider for Library Resources
  4.320    Image Processing in ASP.NET Core: SixLabors.ImageSharp Pipeline
  4.321    Azure Blob Storage Integration: Upload, Serve, and SAS URLs
  4.322    File Security: Path Traversal Prevention and Content Type Validation
  4.324    Health Check UI: AspNetCore.Diagnostics.HealthChecks Dashboard
  4.325    Readiness vs Liveness Probes: Kubernetes Health Check Mapping
  4.326    Dependency Health Checks: Database, Redis, and External HTTP
  4.327    Health Check Authorization: Securing the /health Endpoint
  4.332    Docker Compose: Local Dev with SQL Server, Redis, and the API
  4.333    Kubernetes: Deployments, Services, and ConfigMaps for ASP.NET Core
  4.334    Kubernetes: Secrets, IConfiguration, and Pod Identity
  4.335    Azure App Service: Deployment Slots, Configuration, and Scaling
  4.336    GitHub Actions: CI/CD Pipeline for ASP.NET Core
  4.337    Windows Service Hosting: UseWindowsService
  4.338    Linux Daemon: UseSystemd and systemd Integration
  4.339    Native AOT (.NET 8): ASP.NET Core Requirements and Limitations

TIER 4 — Generate Last (advanced internals, specialist, expert)
  4.306    W3C and HTTP Logging: UseHttpLogging and UseW3CLogging
  4.307    Log Sampling and Rate Limiting in Production Logging
  4.323    Custom IHealthCheck: Implementing Complex Dependency Checks
  4.340    Request Delegate Compilation: How MapGet Becomes a RequestDelegate
  4.341    Minimal API Source Generation: RequestDelegateFactory Internals
  4.342    Blazor Server: Component Model, Circuits, and SignalR Underpinning
  4.343    Blazor WebAssembly: WASM Runtime and Hosting Models
  4.344    Blazor United (.NET 8): Static SSR, Streaming SSR, Interactive Islands
  4.345    YARP: Yet Another Reverse Proxy — Gateway with ASP.NET Core
  4.346    Custom Kestrel Protocols: IConnectionListenerFactory
  4.347    ASP.NET Core with Orleans: Actor Model Co-Hosting
  4.348    Request Coalescing: Preventing Duplicate Expensive In-Flight Operations
  4.349    Multipart Form Data: Advanced Streaming Upload Without Buffering
  4.350    IEndpointMetadataProvider: Pushing Metadata from Parameter Types
  4.351    ASP.NET Core Performance Anatomy: The Full Request Lifecycle
  4.352    ASP.NET Core Internals: Source-Generated Route Dispatcher
```

---

## LEARNING PATH — Beginner → Expert Progression

> This section maps the **learning difficulty progression**, separate from generation priority. Use this if you are studying from scratch or onboarding a junior engineer.

```
BEGINNER (weeks 1–4: understand before writing any ASP.NET Core code)
  4.001    The ASP.NET Core Request Pipeline: A Mental Model
  4.002    WebApplication and WebApplicationBuilder
  4.003    IWebHostEnvironment: Environments and Configuration
  4.011    IConfiguration: The Layered Configuration System
  4.012    Configuration Providers: JSON, Env Vars
  4.023    ILogger<T>: The .NET Logging Abstraction
  4.024    Log Levels, Categories, and Filtering
  4.034    The Built-In DI Container: Service Registration
  4.035    Service Lifetimes: Singleton, Scoped, Transient
  4.049    The Middleware Pipeline: Request Delegation Chain
  4.050    Writing Middleware: Convention-Based
  4.064    Endpoint Routing: The Modern Routing System
  4.065    Route Templates: Syntax, Parameters, Wildcards
  4.078    Minimal APIs: Why They Exist
  4.079    Defining Endpoints: MapGet, MapPost
  4.080    Route Parameter Binding in Minimal APIs
  4.082    IResult and TypedResults
  4.098    ControllerBase vs Controller
  4.099    Action Results: IActionResult and ActionResult<T>
  4.100    Model Binding: Sources and How It Works
  4.102    Model Validation: DataAnnotations and ModelState
  4.134    Authentication Architecture: Schemes and Middleware
  4.136    JWT Bearer Authentication: AddJwtBearer
  4.137    Generating JWT Access Tokens
  4.154    Authorization Architecture
  4.155    Role-Based and Claims-Based Authorization
  4.167    DataAnnotations Validation
  4.177    Exception Handling Middleware
  4.186    IMemoryCache Basics

INTERMEDIATE (weeks 5–10: production-ready patterns)
  4.004    Generic Host and IHostApplicationLifetime
  4.013    User Secrets
  4.016    IOptions<T>: Type-Safe Configuration Binding
  4.017    IOptionsSnapshot and IOptionsMonitor
  4.025    Structured Logging
  4.028    Serilog Integration
  4.036    IServiceProvider and IServiceScope
  4.037    Factory-Based DI
  4.038    Keyed Services (.NET 8)
  4.042    The Captive Dependency Problem
  4.051    Pipeline Branching: Map, MapWhen, UseWhen
  4.052    Middleware Ordering
  4.054    HttpContext and IHttpContextAccessor
  4.066    Route Constraints
  4.067    Attribute Routing
  4.070    Route Groups
  4.083    Minimal API Filters
  4.084    Route Groups in Minimal APIs
  4.085    OpenAPI Integration in Minimal APIs
  4.092    Minimal API vs MVC Decision Framework
  4.101    ApiController Attribute
  4.110    MVC Filter Pipeline
  4.118    Problem Details RFC 7807
  4.124    HttpRequest Deep Dive
  4.135    Cookie Authentication
  4.138    Refresh Token Pattern
  4.139    OAuth 2.0 Flow
  4.140    OpenID Connect
  4.142    ASP.NET Core Identity
  4.149    Claims Transformation
  4.156    Policy-Based Authorization
  4.157    IAuthorizationHandler
  4.158    Resource-Based Authorization
  4.168    ModelState Errors and Custom Responses
  4.170    FluentValidation Integration
  4.179    Problem Details RFC 7807 (Service Layer)
  4.183    Correlation IDs
  4.187    IDistributedCache
  4.188    Redis as IDistributedCache
  4.191    Output Caching (.NET 7+)
  4.202    Rate Limiting (.NET 7+)
  4.209    CORS
  4.210    CSRF / Antiforgery
  4.231    IHostedService and BackgroundService
  4.233    Timed Background Service
  4.234    Queued Background Tasks
  4.249    IHttpClientFactory
  4.250    Named and Typed Clients
  4.251    DelegatingHandler
  4.252    Polly Integration
  4.257    WebApplicationFactory Integration Testing
  4.268    System.Text.Json Global Configuration
  4.277    API Versioning
  4.279    Swagger / OpenAPI Integration
  4.288    Filter Pipeline: Six Types and Order
  4.289    Action Filters
  4.297    Activity API and Distributed Tracing
  4.299    OpenTelemetry SDK
  4.323    Health Check Middleware
  4.330    Docker and Containerization

ADVANCED (weeks 11–18: senior engineer patterns)
  4.007    Kestrel Advanced Configuration
  4.019    Options Validation at Startup
  4.031    High-Performance Logging: LoggerMessage
  4.040    Multiple DI Implementations
  4.044    Decorators in DI
  4.046    DI Registration Validation
  4.055    Custom Exception Middleware
  4.060    Zero-Allocation Middleware
  4.072    Custom Route Constraints
  4.086    FluentValidation in Minimal APIs
  4.094    Minimal API Source Generators
  4.108    Custom Model Binders
  4.127    HTTP/2 and Kestrel Configuration
  4.145    API Key Authentication Handler
  4.148    Multiple Authentication Schemes
  4.159    IAuthorizationService Programmatic Authorization
  4.164    Authorization Caching
  4.172    Async FluentValidation
  4.182    Global Exception Handler (.NET 8)
  4.193    Cache Stampede Prevention
  4.196    HybridCache (.NET 9)
  4.197    Response Compression
  4.199    Request Timeouts (.NET 8)
  4.205    Distributed Rate Limiting with Redis
  4.211    Data Protection API
  4.212    Data Protection Key Management
  4.213    Security Headers Middleware
  4.218    OWASP Top 10 in ASP.NET Core
  4.219    SignalR Architecture
  4.220    SignalR Hubs
  4.222    SignalR Scale-Out
  4.223    SignalR Authentication (JWT + WS Upgrade)
  4.235    Scoped Services in BackgroundService
  4.240    gRPC Service Implementation
  4.241    gRPC Streaming
  4.244    gRPC Interceptors
  4.254    HttpClient Logging and Custom Handlers
  4.261    Middleware Isolation Testing
  4.265    Snapshot Testing
  4.271    JSON Source Generation
  4.282    GraphQL with Hot Chocolate
  4.284    Idempotency Keys
  4.295    Filter Ordering Deep Dive
  4.296    DI in Filters
  4.300    OpenTelemetry Exporters
  4.301    Metrics (.NET 8+)
  4.304    EventSource and EventCounter
  4.329    Reverse Proxy and ForwardedHeaders
  4.333    Kubernetes Deployment
  4.336    GitHub Actions CI/CD

EXPERT (weeks 19+: internals, custom infrastructure, specialist)
  4.043    Replacing the DI Container (Autofac)
  4.060    PipeReader and IBufferWriter<byte>
  4.095    Minimal API Metadata Providers
  4.097    Minimal API AOT Compatibility
  4.129    HTTP/3 and QUIC
  4.200    Connection Pool Tuning
  4.247    gRPC JSON Transcoding
  4.306    Log Sampling and Rate Limiting
  4.307    W3C Logging
  4.339    Native AOT with ASP.NET Core
  4.340    Request Delegate Compilation Internals
  4.341    Minimal API Source Generation Internals
  4.342    Blazor Server
  4.343    Blazor WebAssembly
  4.344    Blazor United (.NET 8)
  4.345    YARP Reverse Proxy
  4.346    Custom Kestrel Protocols
  4.347    ASP.NET Core with Orleans
  4.348    Request Coalescing
  4.349    Multipart Streaming Without Buffering
  4.350    IEndpointMetadataProvider
  4.351    ASP.NET Core Request Lifecycle Anatomy
  4.352    Source-Generated Route Dispatcher Internals
```

---

## FULL TOPIC TABLE

| ID | Topic Name | Status | Level | Interview | Production | Tier |
|---|---|---|---|---|---|---|
| 4.001 | The ASP.NET Core Request Pipeline: A Mental Model | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.002 | WebApplication and WebApplicationBuilder: The New Hosting Model | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.003 | IWebHostEnvironment: Environments and ASPNETCORE_ENVIRONMENT | ⬜ | Beginner | 🟠 High | 🔴 Critical | 1 |
| 4.004 | Generic Host (IHost): Configuration and Application Lifecycle | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.005 | IHostedService and IHostApplicationLifetime | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.006 | Program.cs Evolution: Startup.cs to Top-Level Statements | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.007 | Kestrel: Edge Web Server — Configuration, Limits, and Protocols | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.008 | IIS Hosting: In-Process and Out-of-Process Models | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.009 | Linux Hosting: Nginx Reverse Proxy and Unix Socket Configuration | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.010 | Graceful Shutdown: CancellationToken Propagation and Drain Time | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.011 | IConfiguration: The Layered Configuration System | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.012 | Configuration Providers: JSON, Env Vars, Command Line, In-Memory | ⬜ | Beginner | 🟠 High | 🔴 Critical | 1 |
| 4.013 | User Secrets: Development-Time Secret Management | ⬜ | Intermediate | 🟡 Medium | 🔴 Critical | 2 |
| 4.014 | Azure Key Vault Provider: Production Secret Management | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.015 | Configuration Hot Reload: Reload-on-Change Without Restart | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.016 | IOptions<T>: Type-Safe Configuration Binding Pattern | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.017 | IOptionsSnapshot<T> vs IOptionsMonitor<T>: Hot Reload Distinction | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.018 | Named Options: Multiple Instances of the Same Configuration Type | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 2 |
| 4.019 | Options Validation: Fail-Fast on Startup with ValidateOnBuild | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.020 | Custom Configuration Providers: Implementing IConfigurationProvider | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.021 | Feature Flags: Microsoft.FeatureManagement in ASP.NET Core | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.022 | Configuration Encryption and Sensitive Value Handling | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.023 | ILogger<T>: The .NET Logging Abstraction | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.024 | Log Levels, Categories, and Filtering Configuration | ⬜ | Beginner | 🟠 High | 🔴 Critical | 1 |
| 4.025 | Structured Logging: Log Templates and Semantic Property Values | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.026 | Log Scopes: Contextual Information Across a Request Lifetime | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.027 | Built-In Logging Providers: Console, Debug, EventSource, EventLog | ⬜ | Beginner | 🟡 Medium | 🟠 High | 3 |
| 4.028 | Serilog Integration: Sinks, Enrichers, and Output Templates | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.029 | NLog Integration in ASP.NET Core | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.030 | Application Insights SDK: Request Tracking and Dependency Telemetry | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.031 | High-Performance Logging: LoggerMessage.Define and Source Generators | ⬜ | Advanced | 🟠 High | 🟠 High | 2 |
| 4.032 | Log Redaction and Sensitive Data Masking in Structured Logs | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.033 | HTTP Logging Middleware (.NET 6+) and W3C Logging | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.034 | The Built-In DI Container: Service Registration and Resolution | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.035 | Service Lifetimes: Singleton, Scoped, Transient — Rules and Pitfalls | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.036 | IServiceProvider and IServiceScope: Manual Resolution Patterns | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.037 | Factory-Based DI: ImplementationFactory and Func<T> Injection | ⬜ | Intermediate | 🟠 High | 🟠 High | 2 |
| 4.038 | Keyed Services (.NET 8): Named Resolution Without Hacks | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.039 | Open Generic DI Registration: typeof(IRepository<>) Patterns | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.040 | Multiple Implementations: IEnumerable<T> Registration | ⬜ | Intermediate | 🟠 High | 🟠 High | 2 |
| 4.041 | IServiceCollection Extension Methods: Builder Pattern for Libraries | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.042 | The Captive Dependency Problem: Singleton Consuming Scoped | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.043 | Replacing the Built-In Container: Autofac and Lamar | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.044 | Decorators in the Built-In Container: The Scrutor Pattern | ⬜ | Advanced | 🟠 High | 🟠 High | 2 |
| 4.045 | IDisposable in DI: Ownership and Disposal Responsibility | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.046 | DI Validation at Startup: ValidateOnBuild and ValidateScopes | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.047 | DI Scope in Background Services: The IServiceScopeFactory Pattern | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.048 | Source-Generated DI (.NET 8): Compile-Time Service Registration | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.049 | The Middleware Pipeline: Request Delegation Chain | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.050 | Writing Middleware: IMiddleware vs Convention-Based Approach | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.051 | Short-Circuiting and Pipeline Branching: Map, MapWhen, UseWhen | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.052 | Middleware Ordering: The Canonical Order and Why It Matters | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.053 | Built-In Middleware Reference: What Each Middleware Does | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.054 | HttpContext and IHttpContextAccessor: Safe Shared Request State | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.055 | Custom Exception Middleware: Domain Exceptions to HTTP Responses | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.056 | Response Buffering vs Streaming in Middleware | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.057 | Middleware and Scoped DI: Injecting Scoped Services Correctly | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.058 | Endpoint Middleware vs Request Middleware: The Distinction | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.059 | Conditional Middleware: Environment and Feature-Specific Pipelines | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.060 | Zero-Allocation Middleware: PipeReader and IBufferWriter<byte> | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.061 | Custom Middleware Catalog: Logging, Correlation ID, Timing | ⬜ | Intermediate | 🟡 Medium | 🔴 Critical | 3 |
| 4.062 | Anti-Corruption Middleware: Normalizing Upstream API Responses | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.063 | Middleware Testing: Isolating Middleware Without the Full Pipeline | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.064 | Endpoint Routing: The Modern Routing Architecture | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.065 | Route Templates: Syntax, Literals, Parameters, and Wildcards | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.066 | Route Constraints: Type Constraints, Regex, and Custom Constraints | ⬜ | Intermediate | 🟠 High | 🟠 High | 2 |
| 4.067 | Attribute Routing on Controllers: [Route], [HttpGet], Token Replacement | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.068 | Route Order and Precedence: How Conflicts Are Resolved | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.069 | Area Routing: Namespace Partitioning for Large Codebases | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.070 | Route Groups: Prefix, Filters, Metadata, and Shared Middleware | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.071 | Link Generation: IUrlHelper, LinkGenerator, and Named Routes | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.072 | Custom Route Constraints: IRouteConstraint Implementation | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.073 | Catch-All Routes, Fallback Routes, and 404 Response Handling | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.074 | Endpoint Metadata: Decorating Endpoints with Custom Attributes | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.075 | Route Performance: Trie-Based Matching and Route Cache | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.076 | Host and Port Routing: MapWhen with HostString Matching | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.077 | Route Value Transformers: IOutboundParameterTransformer | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.078 | Minimal APIs: Why They Exist and When to Use Them | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.079 | Defining Endpoints: MapGet, MapPost, MapPut, MapDelete, MapPatch | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.080 | Route Parameter Binding in Minimal APIs | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.081 | Query String Binding and [FromQuery] in Minimal APIs | ⬜ | Beginner | 🟠 High | 🔴 Critical | 1 |
| 4.082 | IResult and TypedResults: Shaping HTTP Responses in Minimal APIs | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.083 | Minimal API Filters: IEndpointFilter Pipeline | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.084 | Route Groups in Minimal APIs: Shared Prefix and Authorization | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.085 | OpenAPI Integration: WithOpenApi(), Tags, and Summaries | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.086 | Validation in Minimal APIs: IValidator<T> and Manual Validation | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.087 | File Upload in Minimal APIs: IFormFile and Large File Streaming | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.088 | Streaming Responses: IAsyncEnumerable<T> and Server-Sent Events | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.089 | Authorization on Endpoints: RequireAuthorization and WithMetadata | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.090 | Antiforgery in Minimal APIs (.NET 8) | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.091 | Form Binding in Minimal APIs (.NET 8): [FromForm] and IFormCollection | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.092 | Minimal API vs MVC Controller: The Decision Framework | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.093 | Organizing Minimal APIs: Feature Slices and Extension Methods | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.094 | Minimal API Source Generators: RequestDelegateGenerator | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.095 | IEndpointMetadataProvider: Pushing Metadata from Parameter Types | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.096 | Custom IResult: IResult and INestedHttpResult for Reusable Responses | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.097 | Minimal API AOT Compatibility: Trim-Safe and Source-Gen Patterns | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.098 | ControllerBase vs Controller: API vs MVC Controllers | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.099 | Action Results: IActionResult, ActionResult<T>, and TypedResults | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.100 | Model Binding: Sources, Order, and the Binding Algorithm | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.101 | ApiController Attribute: Automatic 400, Binding Source Inference | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.102 | Model Validation: DataAnnotations, ModelState, and 400 Responses | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.103 | Content Type Negotiation: Produces, Consumes, and Accept Headers | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.104 | Razor Pages: PageModel, Handlers, and When to Use vs MVC | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.105 | MVC Areas: Namespace Partitioning for Large Applications | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.106 | ViewComponents: Encapsulated Server-Side UI Fragments | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.107 | Output Formatters: JSON, XML, and Custom Formatter Registration | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.108 | Model Binding: Custom IModelBinder for Domain Types | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.109 | Binding Source Attributes: [FromBody], [FromRoute], [FromQuery], [FromHeader] | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.110 | MVC Filter Pipeline: Six Filter Types and Execution Order | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.111 | Global Model State: Custom InvalidModelStateResponseFactory | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.112 | Input Formatters: Deserializing Non-JSON Request Bodies | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.113 | Action Selectors: AcceptVerbs and Custom Selection Attributes | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.114 | API Explorer and ApiDescription: Powering Swagger and Versioning | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.115 | Application Model Conventions: IControllerModelConvention | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.116 | Controller DI: Constructor Injection vs [FromServices] at Action Level | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.117 | Async Actions: Task<IActionResult> and CancellationToken in Controllers | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.118 | Problem Details in MVC: ProblemDetails and ValidationProblemDetails | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.119 | Response Caching on Controllers: [ResponseCache] and Cache Profiles | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.120 | Binding Large Payloads: Streaming Body Without Buffering | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.121 | File Download: FileStreamResult, FileContentResult, PhysicalFileResult | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.122 | Content Negotiation Deep Dive: Accept Header Algorithm | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.123 | HttpContext Deep Dive: Features, Items, and Request Lifetime | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.124 | HttpRequest: Reading URL, Headers, Query, Cookies, and Body | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.125 | HttpResponse: Writing Status, Headers, Cookies, and Streaming Body | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.126 | Cookies: SameSite Policy, Secure Flag, HttpOnly, and Encryption | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.127 | HTTP/2: Multiplexing, Header Compression, and Kestrel Setup | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.128 | Sessions: ISession, Cookie Identity, and Distributed Session Backend | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.129 | HTTP/3 and QUIC: ASP.NET Core (.NET 7+) and Kestrel QUIC | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.130 | Request Body Reading Patterns: EnableBuffering and Raw Body Access | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.131 | WebSockets Manual: Low-Level WebSocket API Without SignalR | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.132 | Server-Sent Events Manual: Streaming Without SignalR | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.133 | HTTP Connection Features: IHttpConnectionFeature and Raw Access | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.134 | Authentication Architecture: Schemes, Handlers, and the Middleware | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.135 | Cookie Authentication: AddCookie, SignInAsync, and ClaimsPrincipal | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.136 | JWT Bearer Authentication: AddJwtBearer and Token Validation Pipeline | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.137 | Generating JWT Access Tokens: Claims, Signing, and Expiry | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.138 | Refresh Token Pattern: Rotation, Secure Storage, and Revocation | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.139 | OAuth 2.0 in ASP.NET Core: Authorization Code and PKCE Flow | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.140 | OpenID Connect: AddOpenIdConnect and Identity Provider Integration | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.141 | External Login Providers: Google, GitHub, Microsoft via OAuth | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.142 | ASP.NET Core Identity: UserManager, RoleManager, IdentityDbContext | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.143 | ASP.NET Core Identity: Password Hashing, Lockout, and Two-Factor | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.144 | ASP.NET Core Identity: Custom User Store and IUserStore<T> | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.145 | API Key Authentication: Custom IAuthenticationHandler Implementation | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.146 | Certificate Authentication: mTLS with AddCertificate | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.147 | Authentication Events: OnTokenValidated and OnAuthenticationFailed | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.148 | Multiple Authentication Schemes: Parallel JWT + Cookie Selection | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 2 |
| 4.149 | Claims Transformation: IClaimsTransformation for Principal Enrichment | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.150 | Token Storage Security: HttpOnly Cookies vs Authorization Header | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 3 |
| 4.151 | IAuthenticationService: Programmatic Auth, Challenge, and Sign-Out | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.152 | Multi-Scheme APIs: JWT for Mobile, Cookie for Browser | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.153 | Auth in Background Services: Headless Identity and Service Accounts | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.154 | Authorization Architecture: Middleware, Policy Evaluation, and Requirements | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.155 | Role-Based and Claims-Based Authorization: [Authorize] Attributes | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.156 | Policy-Based Authorization: AddPolicy and IAuthorizationRequirement | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.157 | IAuthorizationHandler: Implementing Custom Authorization Logic | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.158 | Resource-Based Authorization: Passing Domain Objects to Handlers | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.159 | IAuthorizationService: Programmatic Authorization in Service Layer | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.160 | Authorization Filters vs Policy Handlers vs Middleware: When Each | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.161 | Permission-Based Authorization: Fine-Grained Action Permissions | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.162 | Hierarchical Roles and Dynamic Policy Building | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.163 | Authorization in Minimal APIs: RequireAuthorization and Metadata | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.164 | Authorization Caching: Avoiding Per-Request Database Hits | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.165 | [AllowAnonymous]: Bypassing Global Authorization Cleanly | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.166 | Custom [Authorize] Attributes: AuthorizeAttribute Subclassing | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.167 | DataAnnotations Validation in ASP.NET Core | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.168 | ModelState: Checking Validity, Reading Errors, Custom Responses | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.169 | Custom Validation Attributes: ValidationAttribute and IValidatableObject | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.170 | FluentValidation: Validators, RuleFor, and ASP.NET Core Integration | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.171 | FluentValidation: Async Validators and Database-Level Validation | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.172 | FluentValidation: Conditional Rules, Severity, and Custom Messages | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.173 | Input Sanitization: Preventing XSS at the Model Binding Layer | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.174 | Global Validation: SuppressModelStateInvalidFilter and Custom Factory | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.175 | Validation Across Layers: Where Validation Lives (HTTP vs Domain) | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.176 | Client-Side Validation Coordination: data-val Attributes in Razor | ⬜ | Beginner | 🟡 Medium | 🟡 Medium | 3 |
| 4.177 | Exception Handling Middleware: UseExceptionHandler and Error Pipelines | ⬜ | Beginner | 🔴 Critical | 🔴 Critical | 1 |
| 4.178 | Developer Exception Page: UseDevExceptionPage and Diagnostics Mode | ⬜ | Beginner | 🟡 Medium | 🟠 High | 3 |
| 4.179 | Problem Details (RFC 7807): IProblemDetailsService in ASP.NET Core | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 1 |
| 4.180 | Status Code Pages and Custom HTTP Error Response Shaping | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.181 | Exception Filters: Controller-Scoped Exception Interception | ⬜ | Intermediate | 🟠 High | 🟠 High | 2 |
| 4.182 | Global Exception Handler (.NET 8): IExceptionHandler Interface | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.183 | Correlation IDs: Request Tracing Across Service Boundaries | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.184 | Error Monitoring Integration: Sentry, Raygun, and Application Insights | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.185 | Retry-After and Transient Error Signaling in HTTP Responses | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.186 | IMemoryCache: In-Process Caching with Expiry, Size, and Priority | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.187 | IDistributedCache: The Abstraction for Out-of-Process Caching | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.188 | Redis as IDistributedCache: StackExchange.Redis Integration | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.189 | Cache-Aside Pattern: Load-on-Miss with Async Fallback | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.190 | Response Caching: Cache-Control Headers and [ResponseCache] | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.191 | Output Caching (.NET 7+): Server-Side Response Cache | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.192 | Output Caching Policies: VaryBy, Tags, and Manual Eviction | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.193 | Cache Stampede Prevention: GetOrCreateAsync Locking Patterns | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.194 | Distributed Cache Serialization: System.Text.Json and MessagePack | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.195 | HTTP Caching Headers: ETags, Last-Modified, and Conditional Requests | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.196 | HybridCache (.NET 9): Unified In-Process and Distributed Cache | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.197 | Response Compression: UseResponseCompression, Gzip, and Brotli | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.198 | Request Decompression (.NET 7+): UseRequestDecompression | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.199 | Request Timeouts (.NET 8): IHttpRequestTimeoutFeature | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.200 | Minimal Allocation in Hot Paths: PipeReader and Zero-Copy Patterns | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.201 | Connection Pool Tuning: MaxConnections, Socket Lifetime, DNS TTL | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.202 | Rate Limiting (.NET 7+): Fixed Window, Sliding Window, Token Bucket | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.203 | Rate Limiting Partitioning: Per-User, Per-IP, Per-API-Key | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.204 | Rate Limiting: OnRejected Events and Custom 429 Response Bodies | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.205 | Distributed Rate Limiting with Redis: Coordinating Across Instances | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.206 | Rate Limiting Response Headers: RateLimit-* Standard Headers | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.207 | Rate Limiting Layered with Auth: Per-Tenant API Quotas | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.208 | HTTPS Enforcement: UseHttpsRedirection, HSTS, and Kestrel TLS | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.209 | CORS: UseCors, CorsPolicy, AllowedOrigins, and Preflight Handling | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.210 | CSRF / Antiforgery: IAntiforgery and ValidateAntiforgeryToken | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.211 | Data Protection API: IDataProtector, Purpose Strings, and Payloads | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.212 | Data Protection Key Management: Key Ring, Rotation, Azure Storage | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.213 | Security Headers Middleware: X-Frame-Options, X-Content-Type, CSP | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.214 | XSS Prevention: HTML Encoding, CSP, and the HtmlEncoder Service | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.215 | IDOR Prevention: Resource Ownership Verification in Auth Handlers | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 3 |
| 4.216 | SQL Injection in ASP.NET Core: EF Core Safety vs Raw SQL Risk | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 3 |
| 4.217 | Secrets in Production: Key Vault, Managed Identity, No appsettings | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.218 | OWASP Top 10 Applied to ASP.NET Core APIs | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 3 |
| 4.219 | SignalR Architecture: Hubs, Connections, and Transport Negotiation | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.220 | SignalR Hubs: Hub<T>, Methods, Caller, Client, Groups, All Targeting | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.221 | SignalR Transports: WebSockets, SSE, and Long Polling Negotiation | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.222 | SignalR Scale-Out: Redis Backplane and Azure SignalR Service | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.223 | SignalR Authentication: JWT in WebSocket Connection Upgrade | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 2 |
| 4.224 | SignalR Groups: Membership Management and Targeted Message Delivery | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.225 | SignalR Streaming: IAsyncEnumerable<T> from Hub to Client | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.226 | SignalR .NET Client: HubConnection, Reconnect, and Error Handling | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.227 | SignalR JavaScript Client: hubConnection.on, invoke, and Lifecycle | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.228 | SignalR with Minimal APIs: MapHub and Endpoint Authorization | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.229 | Server-Sent Events with IAsyncEnumerable<T>: Push Without SignalR | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.230 | Long Polling: Correct Implementation When WebSockets Are Unavailable | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.231 | IHostedService: Running Code at Application Startup and Shutdown | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.232 | BackgroundService: The Base Class for Long-Running Work | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.233 | Timed Background Service: PeriodicTimer for Recurring Scheduled Jobs | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.234 | Queued Background Tasks: Channel<T>-Based Producer/Consumer | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.235 | Scoped Services in BackgroundService: IServiceScopeFactory Pattern | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 3 |
| 4.236 | Worker Services: Standalone Console Host with BackgroundService | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.237 | Graceful Shutdown in Background Services: CancellationToken Contract | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.238 | Hangfire in ASP.NET Core: Recurring Jobs and Fire-and-Forget | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.239 | Health Checks for Background Services: Signaling Worker Liveness | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.240 | gRPC in ASP.NET Core: Proto Contracts and Service Implementation | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.241 | gRPC Streaming: Unary, Server, Client, and Bidirectional Patterns | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.242 | gRPC Authentication: JWT and Certificate Interceptors | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.243 | gRPC Error Handling: StatusCode and RpcException | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.244 | gRPC Interceptors: Server-Side and Client-Side Cross-Cutting | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.245 | gRPC-Web: Browser Support via Grpc.AspNetCore.Web | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.246 | gRPC Client Factory: AddGrpcClient<T> and Typed Client Pattern | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.247 | gRPC JSON Transcoding: REST-to-gRPC Translation Layer | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 3 |
| 4.248 | gRPC vs REST vs GraphQL vs SignalR: The Decision Framework | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 3 |
| 4.249 | IHttpClientFactory: Why HttpClient Must Never Be Newed Directly | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.250 | Named and Typed HTTP Clients: AddHttpClient Registration Patterns | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.251 | DelegatingHandler: Message Handler Pipeline for Cross-Cutting Concerns | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.252 | Polly Integration: Retry, Circuit Breaker, and Hedging via AddHttpClient | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.253 | HttpClient Timeout, CancellationToken, and Request Cancellation | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.254 | HttpClient Logging: Built-In Logging Categories and Custom Handlers | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.255 | Primary HttpMessageHandler Lifetime: Socket Exhaustion vs Stale DNS | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 3 |
| 4.256 | HttpClient with Credentials: Auth Headers, Certs, and Bearer Tokens | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.257 | WebApplicationFactory<T>: Integration Testing the Full HTTP Pipeline | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.258 | Customizing WebApplicationFactory: Replacing Services and Config | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.259 | Authentication in Integration Tests: Custom Fake Auth Schemes | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 2 |
| 4.260 | Database in Integration Tests: TestContainers vs SQLite vs InMemory | ⬜ | Advanced | 🔴 Critical | 🔴 Critical | 2 |
| 4.261 | Middleware Testing: Isolating Middleware Without the Full Pipeline | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.262 | Testing SignalR: HubConnection in Integration Test Scenarios | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.263 | Testing Background Services: IHostedService Test Harnesses | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.264 | Mocking HttpClient: MockHttpMessageHandler in Unit Tests | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.265 | Snapshot Testing: Verify Library for API Response Regression | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.266 | Contract Testing: Pact for Consumer-Driven API Contracts | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.267 | Load Testing ASP.NET Core: k6, NBomber, and BenchmarkDotNet | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.268 | System.Text.Json in ASP.NET Core: Global Options and Defaults | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.269 | JsonSerializerOptions: Naming Policies, Null Handling, Enum Conventions | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.270 | Custom JSON Converters: JsonConverter<T> for Domain Types | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.271 | JSON Source Generation: [JsonSerializable] and Zero-Reflection Ser. | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.272 | Newtonsoft.Json Migration: AddNewtonsoftJson and Compatibility Shim | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.273 | XML Serialization: AddXmlSerializerFormatters in ASP.NET Core | ⬜ | Intermediate | 🟡 Medium | 🟡 Medium | 3 |
| 4.274 | MessagePack Serialization: Binary for gRPC and High-Throughput APIs | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.275 | Custom Input/Output Formatters: IInputFormatter and IOutputFormatter | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.276 | Polymorphic JSON Serialization: [JsonDerivedType] in .NET 7+ | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.277 | API Versioning: URL Path, Query String, and Header Strategies | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.278 | Asp.Versioning: AddApiVersioning and MapToApiVersion | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.279 | OpenAPI / Swagger: Swashbuckle and NSwag Integration | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.280 | OpenAPI in .NET 9: Microsoft.AspNetCore.OpenApi Built-In | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 2 |
| 4.281 | Scalar: The Modern OpenAPI UI Alternative to Swagger UI | ⬜ | Beginner | 🟡 Medium | 🟠 High | 3 |
| 4.282 | GraphQL in ASP.NET Core: Hot Chocolate Integration Overview | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.283 | REST API Design Conventions in ASP.NET Core: Verbs, Status Codes | ⬜ | Beginner | 🟠 High | 🔴 Critical | 3 |
| 4.284 | Idempotency Keys: Preventing Duplicate POST Operations | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.285 | Pagination in REST APIs: Keyset and Offset with Link Headers | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.286 | HATEOAS: Hypermedia Controls in REST API Responses | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.287 | API Deprecation: Sunset Headers and Version Lifecycle Management | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.288 | Filter Pipeline: Six Filter Types, Execution Order, and Scope | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.289 | Action Filters: IAsyncActionFilter Before and After Action Execution | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.290 | Result Filters: IAsyncResultFilter Before and After Response | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.291 | Exception Filters: Controller-Scoped Exception Handling | ⬜ | Intermediate | 🟠 High | 🟠 High | 3 |
| 4.292 | Resource Filters: IAsyncResourceFilter Before Model Binding | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.293 | Authorization Filters: IAsyncAuthorizationFilter — First in Pipeline | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.294 | Global Filters: Registering Application-Wide Filter Behavior | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.295 | Filter Ordering: IOrderedFilter and Explicit Execution Sequence | ⬜ | Advanced | 🟠 High | 🟠 High | 3 |
| 4.296 | DI in Filters: ServiceFilter vs TypeFilter vs Constructor Injection | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.297 | Activity API: System.Diagnostics.Activity and Distributed Tracing | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.298 | DiagnosticSource and DiagnosticListener: The ASP.NET Core Event Bus | ⬜ | Expert | 🟡 Medium | 🟠 High | 3 |
| 4.299 | OpenTelemetry .NET SDK: Tracing, Metrics, and Logs Integration | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.300 | OpenTelemetry: Exporters — Jaeger, Zipkin, and OTLP Collector | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.301 | Metrics in .NET 8+: System.Diagnostics.Metrics and IMeterFactory | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.302 | Prometheus Metrics: prometheus-net Integration in ASP.NET Core | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.303 | Application Insights Deep Dive: Custom Events, Metrics, Dependency | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.304 | EventSource and EventCounter: High-Performance Runtime Metrics | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.305 | QueryTagWith and Correlation: Linking App Traces to DB Query Logs | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.306 | Log Sampling and Rate Limiting in Production Logging Pipelines | ⬜ | Expert | 🟡 Medium | 🟠 High | 4 |
| 4.307 | W3C Logging: UseW3CLogging for IIS-Compatible Access Log Format | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 4 |
| 4.308 | IStringLocalizer<T>: Resource-Based String Localization | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.309 | Request Localization Middleware: Culture Providers and Selection | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.310 | Resource Files: .resx Files and XLIFF for Professional Translation | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.311 | Date, Number, and Currency Formatting by Culture | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.312 | RTL Layout Support: Arabic, Hebrew, and Bidirectional Text | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.313 | PO File Localization: OrchardCore Localization Alternative | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.314 | Localization in Minimal APIs and FluentValidation Error Messages | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.315 | Static Files Middleware: UseStaticFiles, wwwroot, and File Providers | ⬜ | Beginner | 🟡 Medium | 🟠 High | 3 |
| 4.316 | Physical File Provider: Reading Files from Disk in Custom Middleware | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.317 | File Upload: IFormFile, Streaming Large Files, and Antivirus Hooks | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.318 | File Download: Streaming from Blob Storage with Range Request Support | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.319 | Virtual File System: EmbeddedFileProvider for Shipped Library Resources | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.320 | Image Processing Pipeline: SixLabors.ImageSharp in ASP.NET Core | ⬜ | Advanced | 🟡 Medium | 🟡 Medium | 3 |
| 4.321 | Azure Blob Storage Integration: Upload, Serve, and SAS URL Generation | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.322 | File Security: Path Traversal Prevention and Content Type Validation | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.323 | Health Check Middleware: HealthCheck Registration and Custom IHealthCheck | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.324 | Health Check UI: AspNetCore.Diagnostics.HealthChecks Dashboard | ⬜ | Advanced | 🟡 Medium | 🟠 High | 3 |
| 4.325 | Readiness vs Liveness Probes: Kubernetes Health Check Mapping | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.326 | Dependency Health Checks: Database, Redis, and External HTTP | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.327 | Health Check Authorization: Securing the /health Endpoint | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.328 | Kestrel Advanced Configuration: Limits, TLS Certs, and Protocols | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.329 | Reverse Proxy Configuration: X-Forwarded Headers Middleware | ⬜ | Advanced | 🟠 High | 🔴 Critical | 2 |
| 4.330 | Docker: Containerizing ASP.NET Core Applications | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.331 | Docker: Multi-Stage Builds for Minimal Production Images | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.332 | Docker Compose: Local Dev with SQL Server, Redis, and the API | ⬜ | Intermediate | 🟠 High | 🔴 Critical | 3 |
| 4.333 | Kubernetes: Deployments, Services, and ConfigMaps | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.334 | Kubernetes: Secrets, IConfiguration Integration, and Pod Identity | ⬜ | Advanced | 🟠 High | 🔴 Critical | 3 |
| 4.335 | Azure App Service: Deployment Slots, Configuration, and Auto-Scale | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.336 | GitHub Actions: CI/CD Pipeline for ASP.NET Core — Build, Test, Deploy | ⬜ | Intermediate | 🔴 Critical | 🔴 Critical | 2 |
| 4.337 | Windows Service Hosting: UseWindowsService and Service Lifecycle | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.338 | Linux Daemon: UseSystemd and systemd Service Integration | ⬜ | Intermediate | 🟡 Medium | 🟠 High | 3 |
| 4.339 | Native AOT (.NET 8): ASP.NET Core Requirements, Limitations, and Trims | ⬜ | Expert | 🟠 High | 🟠 High | 3 |
| 4.340 | Request Delegate Compilation: How MapGet Becomes a RequestDelegate | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.341 | Minimal API Source Generation: RequestDelegateFactory Internals | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.342 | Blazor Server: Component Model, Circuits, and SignalR Underpinning | ⬜ | Advanced | 🟠 High | 🟠 High | 4 |
| 4.343 | Blazor WebAssembly: WASM Runtime, Hosting, and Security Model | ⬜ | Advanced | 🟠 High | 🟠 High | 4 |
| 4.344 | Blazor United (.NET 8): Static SSR, Streaming SSR, Interactive Islands | ⬜ | Advanced | 🟠 High | 🟠 High | 4 |
| 4.345 | YARP: Yet Another Reverse Proxy — Gateway Patterns in ASP.NET Core | ⬜ | Expert | 🟡 Medium | 🟠 High | 4 |
| 4.346 | Custom Kestrel Protocols: IConnectionListenerFactory and Handlers | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.347 | ASP.NET Core with Orleans: Actor Model Co-Hosting on the Generic Host | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.348 | Request Coalescing: Preventing Duplicate In-Flight Expensive Operations | ⬜ | Expert | 🟡 Medium | 🟠 High | 4 |
| 4.349 | Multipart Streaming Upload: Without Buffering the Entire Body | ⬜ | Expert | 🟡 Medium | 🟠 High | 4 |
| 4.350 | IEndpointMetadataProvider: Pushing Metadata from Parameter Binding | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |
| 4.351 | ASP.NET Core Request Lifecycle Anatomy: Every Step from TCP to Response | ⬜ | Expert | 🟠 High | 🟠 High | 4 |
| 4.352 | ASP.NET Core Internals: Source-Generated Route Dispatcher Deep Dive | ⬜ | Expert | 🟡 Medium | 🟡 Medium | 4 |

---

## TOPIC DETAILS — PROMPT VALUES

> Full details for Tier 1 topics below. Tier 2–4 topics list key areas only; RELATED_TOPICS are filled in at generation time.

---

### 4.001 — The ASP.NET Core Request Pipeline: A Mental Model

**TOPIC_ID:** `4.001`
**TOPIC_NAME:** `The ASP.NET Core Request Pipeline: A Mental Model`
**RELATED_TOPICS:**

```
- [[4.002 — WebApplication and WebApplicationBuilder]] — WebApplication.CreateBuilder() wires the host; the pipeline is built inside it
- [[4.049 — The Middleware Pipeline: Request Delegation Chain]] — the mental model becomes concrete in middleware implementation
- [[4.064 — Endpoint Routing: The Modern Routing System]] — routing is the middleware that resolves which endpoint handles the request
- [[4.134 — Authentication Architecture]] — authentication runs as middleware in the pipeline before authorization
- [[4.154 — Authorization Architecture]] — authorization runs after authentication in the pipeline order
- [[2.14 — Async/Await Internals]] — every middleware delegate is async; the pipeline is a chain of ValueTask continuations
```

**Key topics inside this note:** The five conceptual layers (Kestrel → Middleware → Routing → Endpoint → Response), the request and response journey as a chain of `next()` delegates, why the pipeline is bidirectional (request in, response out through the same chain), the `RequestDelegate` type alias and what it means, how endpoints differ from middleware, the role of `HttpContext` as the shared state across the pipeline, why ordering is not optional.

---

### 4.002 — WebApplication and WebApplicationBuilder: The New Hosting Model

**TOPIC_ID:** `4.002`
**TOPIC_NAME:** `WebApplication and WebApplicationBuilder: The New Hosting Model`
**RELATED_TOPICS:**

```
- [[4.001 — The ASP.NET Core Request Pipeline: A Mental Model]] — WebApplication builds the pipeline the mental model describes
- [[4.004 — Generic Host (IHost): Configuration and Application Lifecycle]] — WebApplicationBuilder wraps IHostBuilder; understanding the Generic Host explains what WebApplication configures
- [[4.034 — The Built-In DI Container: Service Registration and Resolution]] — builder.Services is IServiceCollection; every registration happens here
- [[4.011 — IConfiguration: The Layered Configuration System]] — builder.Configuration is pre-wired with JSON, env vars, and command-line providers
- [[4.049 — The Middleware Pipeline: Request Delegation Chain]] — app.Use/Run/Map calls configure the pipeline after the host is built
- [[4.006 — Program.cs Evolution: Startup.cs to Top-Level Statements]] — WebApplicationBuilder replaced Startup.cs in .NET 6; understanding the evolution prevents confusion with legacy codebases
```

**Key topics inside this note:** `WebApplicationBuilder` vs the old `IHostBuilder + Startup.cs` model, `builder.Services`, `builder.Configuration`, `builder.Logging`, `builder.Environment`, `builder.Host`, `builder.WebHost` — what each exposes and when to use each, `WebApplication.CreateBuilder(args)` vs `WebApplication.CreateSlimBuilder(args)` (.NET 8), the build phase (DI container compiled, configuration frozen) vs run phase, `app.Run()` vs `app.RunAsync()`, why `app` is both the pipeline builder and the application runner, accessing services from the built app with `app.Services`.

---

### 4.003 — IWebHostEnvironment: Environments and ASPNETCORE_ENVIRONMENT

**TOPIC_ID:** `4.003`
**TOPIC_NAME:** `IWebHostEnvironment: Environments and ASPNETCORE_ENVIRONMENT`
**RELATED_TOPICS:**

```
- [[4.002 — WebApplication and WebApplicationBuilder]] — builder.Environment is IWebHostEnvironment; it is set before the pipeline is built
- [[4.011 — IConfiguration: The Layered Configuration System]] — appsettings.{Environment}.json is loaded based on this value
- [[4.059 — Conditional Middleware: Environment-Specific Pipeline Behavior]] — IsEnvironment checks drive conditional middleware registration
- [[4.178 — Developer Exception Page]] — the dev exception page is conditionally enabled by checking IsDevelopment()
```

**Key topics inside this note:** `IWebHostEnvironment` vs `IHostEnvironment` — which to inject and when, `IsDevelopment()`, `IsStaging()`, `IsProduction()`, `IsEnvironment("CustomName")`, how `ASPNETCORE_ENVIRONMENT` maps to environment name, `ContentRootPath` vs `WebRootPath` and what each means, custom environment names beyond the three defaults, environment-specific `appsettings.{Environment}.json` loading order, launchSettings.json and local development environment override, setting environment in Docker via `ASPNETCORE_ENVIRONMENT` env var.

---

### 4.011 — IConfiguration: The Layered Configuration System

**TOPIC_ID:** `4.011`
**TOPIC_NAME:** `IConfiguration: The Layered Configuration System`
**RELATED_TOPICS:**

```
- [[4.002 — WebApplication and WebApplicationBuilder]] — builder.Configuration is the pre-wired IConfiguration with default providers
- [[4.012 — Configuration Providers: JSON, Env Vars, Command Line, In-Memory]] — IConfiguration is the aggregator; providers are the data sources
- [[4.016 — IOptions<T>: Type-Safe Configuration Binding Pattern]] — IOptions<T> is the production way to consume IConfiguration; raw IConfiguration access in services is an anti-pattern
- [[4.003 — IWebHostEnvironment]] — environment name drives which appsettings.{Environment}.json is loaded
- [[4.013 — User Secrets]] — user secrets are a configuration provider with high override priority in development
```

**Key topics inside this note:** Configuration as a layered key-value store (later sources override earlier), the default provider order in WebApplicationBuilder (JSON → JSON.Environment → User Secrets → Env Vars → Command Line), key hierarchy with `:` separator (`"Database:ConnectionString"`), `IConfiguration["Key"]` vs `IConfiguration.GetSection("Section").Get<T>()`, binding complex objects with `config.GetSection("Smtp").Bind(options)`, `GetConnectionString("Name")` as a shortcut for `ConnectionStrings:Name`, `IConfigurationRoot` and `IConfigurationProvider` for debugging override sources, what happens when a key does not exist (`null` not an exception), reloading configuration without restart.

---

### 4.016 — IOptions<T>: The Type-Safe Configuration Binding Pattern

**TOPIC_ID:** `4.016`
**TOPIC_NAME:** `IOptions<T>: Type-Safe Configuration Binding Pattern`
**RELATED_TOPICS:**

```
- [[4.011 — IConfiguration: The Layered Configuration System]] — IOptions<T> is the type-safe consumer of IConfiguration; raw IConfiguration in services is the anti-pattern
- [[4.017 — IOptionsSnapshot<T> vs IOptionsMonitor<T>]] — IOptions<T> is for Singleton services; the other two handle configuration reload in Scoped and Singleton services respectively
- [[4.018 — Named Options]] — Named options extend IOptions<T> to support multiple configurations of the same type
- [[4.019 — Options Validation: Fail-Fast on Startup]] — validation runs at startup to catch misconfiguration before traffic arrives
- [[4.035 — Service Lifetimes: Singleton, Scoped, Transient]] — IOptions<T> is Singleton; injecting it into Scoped services is safe unlike injecting raw IConfiguration
```

**Key topics inside this note:** `builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"))`, the three Options interfaces and their lifetime semantics (`IOptions<T>` — Singleton, cached forever; `IOptionsSnapshot<T>` — Scoped, reloaded per request; `IOptionsMonitor<T>` — Singleton, change notifications), `services.AddOptions<T>().BindConfiguration("Section").ValidateDataAnnotations()`, constructor injection of `IOptions<T>` vs accessing `.Value` directly, `PostConfigure<T>` for modifying options after all configuration runs, `IOptionsFactory<T>` and when it is relevant, why raw `IConfiguration` injected into domain services is a coupling smell.

---

### 4.023 — ILogger<T>: The .NET Logging Abstraction

**TOPIC_ID:** `4.023`
**TOPIC_NAME:** `ILogger<T>: The .NET Logging Abstraction`
**RELATED_TOPICS:**

```
- [[4.024 — Log Levels, Categories, and Filtering]] — ILogger<T> uses T as the category name; filtering rules are applied per category
- [[4.025 — Structured Logging: Log Templates and Semantic Values]] — ILogger<T> supports structured logging natively via message templates
- [[4.026 — Log Scopes]] — ILogger<T>.BeginScope adds ambient context to all log entries within a scope
- [[4.028 — Serilog Integration]] — ILogger<T> is the abstraction Serilog implements; switching providers requires zero application code change
- [[4.031 — High-Performance Logging: LoggerMessage.Define]] — LoggerMessage.Define is the low-allocation alternative to calling ILogger<T> methods directly in hot paths
```

**Key topics inside this note:** `ILogger<T>` vs `ILogger` — the difference (category name), the six log levels and their semantic meanings (`Trace`, `Debug`, `Information`, `Warning`, `Error`, `Critical`), structured logging with named holes (`logger.LogInformation("Processing order {OrderId}", order.Id)` — NOT string interpolation), why string interpolation in log calls defeats structured logging, `logger.IsEnabled(LogLevel.Debug)` for guard clauses before expensive string construction, `LoggerFactory.CreateLogger(categoryName)` for dynamic categories, built-in category scoping from class name, disposing the logger factory on host shutdown.

---

### 4.034 — The Built-In DI Container: Service Registration and Resolution

**TOPIC_ID:** `4.034`
**TOPIC_NAME:** `The Built-In DI Container: Service Registration and Resolution`
**RELATED_TOPICS:**

```
- [[4.035 — Service Lifetimes: Singleton, Scoped, Transient]] — service lifetimes are the most important DI concept; registration without understanding lifetime is dangerous
- [[4.002 — WebApplication and WebApplicationBuilder]] — builder.Services is where all registrations happen; the container is compiled at app.Build()
- [[4.036 — IServiceProvider and IServiceScope]] — the compiled container; used for manual resolution when constructor injection is unavailable
- [[4.042 — The Captive Dependency Problem]] — the most common DI bug; Singleton consuming Scoped is a runtime exception in development
- [[4.046 — DI Validation at Startup]] — ValidateOnBuild catches registration errors at startup, not at first request
- [[2.28 — Dependency Injection Internals]] — DI is a language-level pattern; understanding constructor injection and the DI graph is prerequisite
```

**Key topics inside this note:** `AddSingleton<TService, TImpl>()`, `AddScoped<TService, TImpl>()`, `AddTransient<TService, TImpl>()`, service descriptor anatomy (`ServiceType`, `ImplementationType`, `Lifetime`, `ImplementationFactory`), registering concrete types (no interface), registering with a factory (`AddSingleton<T>(sp => new T(sp.GetRequired<TDep>()))`), `TryAdd*` variants (do not replace if already registered), `AddSingleton<T>(instance)` for pre-created instances, extension method convention for library authors, the container is sealed after `Build()` — no registration after build, `IServiceProvider.GetService<T>()` vs `GetRequiredService<T>()` — never use GetService in production (null return is a silent bug).

---

### 4.035 — Service Lifetimes: Singleton, Scoped, Transient — Rules and Pitfalls

**TOPIC_ID:** `4.035`
**TOPIC_NAME:** `Service Lifetimes: Singleton, Scoped, Transient — Rules and Pitfalls`
**RELATED_TOPICS:**

```
- [[4.034 — The Built-In DI Container]] — lifetime is specified at registration; this topic explains what each choice means at runtime
- [[4.042 — The Captive Dependency Problem: Singleton → Scoped is a Bug]] — the most dangerous lifetime mistake; deserves its own note
- [[4.047 — DI Scope in Background Services]] — BackgroundService runs outside the HTTP request scope; scoped services must be created manually
- [[4.054 — HttpContext and IHttpContextAccessor]] — IHttpContextAccessor is Singleton but accesses Scoped data; the classic lifetime mismatch that works by design
- [[3.01 — DbContext: Lifecycle, Internals, and DI Scoping]] — DbContext is Scoped; using it as Singleton is one of the most common EF Core bugs
```

**Key topics inside this note:** Singleton — one instance per application lifetime, shared across all requests, must be thread-safe; Scoped — one instance per HTTP request (or manually created scope), most services should be Scoped; Transient — new instance every time resolved, appropriate for lightweight stateless services, risk of resource leaks if they hold resources; the scope resolution rules: `IServiceScope` creates a child container, `HttpContext` triggers automatic scope creation per request, the captive dependency trap definition (Singleton holds reference to Scoped — the Scoped service is never released); `ValidateScopes = true` (enabled by default in Development) catches this at startup; memory implications: Singleton allocations live for the app lifetime, Transient allocated and GC'd per resolution.

---

### 4.049 — The Middleware Pipeline: Request Delegation Chain

**TOPIC_ID:** `4.049`
**TOPIC_NAME:** `The Middleware Pipeline: Request Delegation Chain`
**RELATED_TOPICS:**

```
- [[4.001 — The ASP.NET Core Request Pipeline: A Mental Model]] — the mental model becomes implementation detail here
- [[4.050 — Writing Middleware: IMiddleware vs Convention-Based]] — this topic explains the pipeline; next explains how to extend it
- [[4.052 — Middleware Ordering: The Canonical Order]] — the pipeline runs in registration order; ordering determines what wraps what
- [[4.054 — HttpContext and IHttpContextAccessor]] — HttpContext flows through the pipeline; every middleware shares the same context instance
- [[2.14 — Async/Await Internals]] — the RequestDelegate chain is a series of async continuations; understanding async is prerequisite for writing correct middleware
```

**Key topics inside this note:** `RequestDelegate` as `Func<HttpContext, Task>`, the `next()` pattern — calling next passes control downstream, not calling next short-circuits the pipeline, `app.Use(next => async context => { before; await next(context); after; })` — the raw middleware shape, what "before next" and "after next" mean for request and response flow, `app.Run()` as a terminal middleware (never calls next), `app.Map("/path", branch => ...)` — branching creates a sub-pipeline that rejoins only if the branch does not respond, how response headers must be set before the body is written (response has already started), the order of execution for five middleware: request flows in registration order, response flows in reverse, exception handling middleware must be first to catch exceptions from all downstream middleware.

---

### 4.050 — Writing Middleware: IMiddleware vs Convention-Based

**TOPIC_ID:** `4.050`
**TOPIC_NAME:** `Writing Middleware: IMiddleware vs Convention-Based`
**RELATED_TOPICS:**

```
- [[4.049 — The Middleware Pipeline: Request Delegation Chain]] — middleware implementation depends on understanding the pipeline
- [[4.057 — Middleware and Scoped DI: Injecting Scoped Services Correctly]] — IMiddleware enables per-request scoped DI; convention-based middleware receives Singleton-lifetime services in its constructor
- [[4.034 — The Built-In DI Container: Service Registration]] — IMiddleware must be registered in DI; convention-based middleware is not registered in DI (it is instantiated by the pipeline)
- [[4.035 — Service Lifetimes: Singleton, Scoped, Transient]] — convention-based middleware is effectively Singleton; IMiddleware is resolved per request
```

**Key topics inside this note:** Convention-based middleware — `InvokeAsync(HttpContext context, RequestDelegate next)` method, activated once (Singleton-like), constructor receives only Singleton services, method parameters receive Scoped services; `IMiddleware` — interface-based, must be registered in DI, resolved per request (can be Scoped), `InvokeAsync` receives `HttpContext` and `RequestDelegate`; `app.UseMiddleware<T>()` for both; when to use which: IMiddleware when the middleware needs Scoped services or must be Scoped itself, convention-based for stateless cross-cutting concerns; writing an idempotency key middleware, a correlation ID middleware, and a request timing middleware as three concrete examples.

---

### 4.052 — Middleware Ordering: The Canonical Order and Why It Matters

**TOPIC_ID:** `4.052`
**TOPIC_NAME:** `Middleware Ordering: The Canonical Order and Why It Matters`
**RELATED_TOPICS:**

```
- [[4.049 — The Middleware Pipeline: Request Delegation Chain]] — the pipeline executes in registration order; this topic names the correct order
- [[4.177 — Exception Handling Middleware]] — exception handling must be first; if it is not first, exceptions before it are unhandled
- [[4.208 — HTTPS Enforcement: UseHttpsRedirection]] — HTTPS redirect must be before authentication; redirecting after auth exposes credentials
- [[4.209 — CORS]] — CORS must be before routing and auth to correctly handle preflight requests
- [[4.134 — Authentication Architecture]] — authentication must be before authorization; authorization reads the claims set by authentication
```

**Key topics inside this note:** The canonical Microsoft-recommended middleware order and the reasoning behind each position: `UseExceptionHandler` → `UseHttpsRedirection` → `UseStaticFiles` → `UseRouting` → `UseCors` → `UseAuthentication` → `UseAuthorization` → custom middleware → `UseEndpoints/MapControllers/MapGet`, why exception handling is outermost (wraps all downstream errors), why static files are before routing (avoids unnecessary routing cost for static assets), why routing must precede auth (routing sets the endpoint metadata that auth reads), the consequence of putting `UseAuthorization` before `UseAuthentication` (authorization sees an unauthenticated principal and denies everything), the consequence of putting CORS after auth (browser preflight requests fail because auth denies the OPTIONS request).

---

### 4.064 — Endpoint Routing: The Modern Routing Architecture

**TOPIC_ID:** `4.064`
**TOPIC_NAME:** `Endpoint Routing: The Modern Routing Architecture`
**RELATED_TOPICS:**

```
- [[4.001 — The ASP.NET Core Request Pipeline: A Mental Model]] — routing is a two-phase middleware: route matching then endpoint execution
- [[4.065 — Route Templates: Syntax, Parameters, and Wildcards]] — routing matches against templates; this topic explains what templates are
- [[4.052 — Middleware Ordering: The Canonical Order]] — UseRouting must precede UseAuthentication and UseAuthorization
- [[4.070 — Route Groups]] — route groups organize endpoint registrations with shared prefix and metadata
- [[4.074 — Endpoint Metadata]] — endpoints carry metadata (auth requirements, CORS policies, OpenAPI tags) that middleware reads
```

**Key topics inside this note:** The two-phase split — `UseRouting()` matches the request to an endpoint, `UseEndpoints()` executes it (in .NET 6+ this is unified but the phases still exist), `EndpointRoutingMiddleware` and `EndpointMiddleware`, the `IEndpointRouteBuilder` interface, how middleware between `UseRouting` and `UseEndpoints` can read `HttpContext.GetEndpoint()` to make decisions before execution, route value dictionary and how endpoint parameters become `HttpContext.Request.RouteValues`, the order of route matching (more specific routes before less specific), the `MapGet`/`MapControllers`/`MapHub` family as all producing `IEndpointConventionBuilder`, convention-based vs attribute routing as two configuration styles for the same system, the `[Route]` attribute on controllers as endpoint registration.

---

### 4.078 — Minimal APIs: Why They Exist and When to Use Them

**TOPIC_ID:** `4.078`
**TOPIC_NAME:** `Minimal APIs: Why They Exist and When to Use Them`
**RELATED_TOPICS:**

```
- [[4.092 — Minimal API vs MVC Controller: The Decision Framework]] — the decision of which to use is the most important question before writing any endpoint
- [[4.064 — Endpoint Routing: The Modern Routing Architecture]] — Minimal APIs are built on endpoint routing; MapGet is registering an endpoint
- [[4.079 — Defining Endpoints: MapGet, MapPost, MapPut, MapDelete]] — the core API surface of Minimal APIs
- [[4.082 — IResult and TypedResults]] — Minimal APIs return IResult; understanding this is the first API surface to learn
- [[4.083 — Minimal API Filters: IEndpointFilter Pipeline]] — filters are the cross-cutting concern mechanism in Minimal APIs (replacing MVC action filters)
- [[4.094 — Minimal API Source Generators]] — the performance motivation for Minimal APIs vs MVC relates to source-gen and AOT
```

**Key topics inside this note:** Why Minimal APIs were introduced — reduce the ceremony of MVC for simple APIs, enable source generation and Native AOT, reduce startup time and memory for microservices, performance vs MVC controllers (fewer allocations, no action model construction), the three pillars: endpoint routing, parameter binding, IResult return types, when Minimal APIs are the right choice (microservices, simple CRUD APIs, Azure Functions–style endpoints), when MVC is still better (Razor views, ViewComponents, complex filter pipelines, large teams with action-filter conventions), the `WebApplication.CreateSlimBuilder` connection (designed for Minimal APIs without MVC overhead), misconception: Minimal APIs are not just for small projects.

---

### 4.082 — IResult and TypedResults: Shaping HTTP Responses

**TOPIC_ID:** `4.082`
**TOPIC_NAME:** `IResult and TypedResults: Shaping HTTP Responses in Minimal APIs`
**RELATED_TOPICS:**

```
- [[4.079 — Defining Endpoints: MapGet, MapPost, MapPut, MapDelete]] — endpoint handler return types must implement IResult or be a plain type
- [[4.085 — OpenAPI Integration in Minimal APIs]] — TypedResults enables automatic OpenAPI response type documentation without [ProducesResponseType]
- [[4.118 — Problem Details in MVC]] — Results.Problem() generates RFC 7807 ProblemDetails responses
- [[4.099 — Action Results in MVC]] — IResult is the Minimal API equivalent of IActionResult; same concept, different type hierarchy
```

**Key topics inside this note:** `IResult` as the unified response abstraction — execution writes to `HttpContext.Response`, `Results` static class (non-generic, returns `IResult` — no static type info for OpenAPI), `TypedResults` static class (.NET 7+, returns typed results like `Ok<T>`, `NotFound<T>` — carries generic type info for OpenAPI schema generation), the difference: `Results.Ok(user)` vs `TypedResults.Ok(user)` — identical HTTP output, different compile-time metadata, `Results<T1, T2>` union return type for OpenAPI — endpoint declares it can return Ok<Order> or NotFound<ProblemDetails>, common results: `Ok()`, `Ok<T>()`, `Created()`, `CreatedAtRoute()`, `Accepted()`, `NoContent()`, `BadRequest()`, `NotFound()`, `Unauthorized()`, `Forbid()`, `Conflict()`, `Problem()`, `ValidationProblem()`, `File()`, `Stream()`, `Redirect()`, `Text()`, `Json()`, custom `IResult` implementation, `Results.Extensions` for custom results.

---

### 4.098 — ControllerBase vs Controller: API vs MVC Controllers

**TOPIC_ID:** `4.098`
**TOPIC_NAME:** `ControllerBase vs Controller: API vs MVC Controllers`
**RELATED_TOPICS:**

```
- [[4.099 — Action Results: IActionResult, ActionResult<T>]] — both controller types return action results; the result types are the same
- [[4.101 — ApiController Attribute]] — [ApiController] is applied to ControllerBase subclasses; it changes binding and validation behavior
- [[4.104 — Razor Pages]] — MVC Controller with views, Razor Pages with PageModel, and Minimal APIs are the three endpoint programming models
- [[4.110 — MVC Filter Pipeline]] — filters apply to both ControllerBase and Controller subclasses identically
- [[4.092 — Minimal API vs MVC Controller: The Decision Framework]] — the broader decision of Minimal API vs any controller type
```

**Key topics inside this note:** `ControllerBase` — the base for API controllers (no view support), has HttpContext, Request, Response, User, ModelState, and all action result helpers; `Controller` — inherits ControllerBase and adds `View()`, `PartialView()`, `ViewBag`, `TempData`, `ViewData` — for MVC controllers that render Razor views; rule: always inherit `ControllerBase` for APIs, never `Controller` for JSON APIs (it pulls in unnecessary dependencies); the `[ApiController]` attribute is separate from the base class — it applies to ControllerBase subclasses; what `[ApiController]` adds: automatic 400 from ModelState, binding source inference ([FromBody] inferred for complex types), problem details for client errors; `[Route("api/[controller]")]` token replacement — `[controller]` resolves to class name minus "Controller".

---

### 4.134 — Authentication Architecture: Schemes, Handlers, and the Middleware

**TOPIC_ID:** `4.134`
**TOPIC_NAME:** `Authentication Architecture: Schemes, Handlers, and the Middleware`
**RELATED_TOPICS:**

```
- [[4.136 — JWT Bearer Authentication]] — JWT is one authentication scheme; understanding the architecture first makes JWT configuration understandable
- [[4.135 — Cookie Authentication]] — Cookie auth is another scheme; the same architecture underlies it
- [[4.148 — Multiple Authentication Schemes]] — the architecture enables multiple schemes; this topic explains the selection mechanism
- [[4.154 — Authorization Architecture]] — authentication produces ClaimsPrincipal; authorization reads it; the pipeline order matters
- [[4.052 — Middleware Ordering]] — UseAuthentication must be before UseAuthorization; they are separate middleware
```

**Key topics inside this note:** The three concepts: scheme (named configuration), handler (`IAuthenticationHandler` — the implementation), middleware (`UseAuthentication` — runs all configured schemes), how `IAuthenticationService.AuthenticateAsync(context, scheme)` works, the ClaimsPrincipal and its identities (`User.Identity`, `User.Identities`), the three operations: Authenticate (verify identity from request), Challenge (respond to unauthenticated request — redirect for cookies, 401 for JWT), Forbid (respond to authenticated but unauthorized — redirect for cookies, 403 for JWT), scheme selection — default scheme vs per-endpoint scheme via `[Authorize(AuthenticationSchemes = "...")]`, `HttpContext.User` is set by the authentication middleware before the endpoint executes.

---

### 4.136 — JWT Bearer Authentication: AddJwtBearer and Token Validation Pipeline

**TOPIC_ID:** `4.136`
**TOPIC_NAME:** `JWT Bearer Authentication: AddJwtBearer and Token Validation Pipeline`
**RELATED_TOPICS:**

```
- [[4.134 — Authentication Architecture]] — JWT Bearer is one scheme in the authentication system; the architecture note explains the container
- [[4.137 — Generating JWT Access Tokens]] — validation is the server side; generation is the client side; both must use the same signing key and claims
- [[4.138 — Refresh Token Pattern]] — access tokens expire; refresh tokens extend sessions without re-authentication
- [[4.148 — Multiple Authentication Schemes]] — JWT + Cookie parallel is the most common multi-scheme pattern
- [[4.150 — Token Storage Security]] — how the client stores and sends the JWT affects the security model
```

**Key topics inside this note:** `AddJwtBearer()` configuration — `TokenValidationParameters` (Issuer, Audience, IssuerSigningKey, ClockSkew, ValidateLifetime, ValidateIssuer, ValidateAudience), the validation pipeline steps (signature → issuer → audience → lifetime → custom), what happens when validation fails (401 with WWW-Authenticate header), extracting the token — `Authorization: Bearer {token}` header parsing, claims mapping — how JWT claims become `ClaimsPrincipal` claims (the NameClaimType mapping issue: JWT `sub` vs .NET `NameIdentifier`), `JwtBearerEvents.OnTokenValidated` for custom logic after validation, asymmetric (RS256) vs symmetric (HS256) signing — when each is appropriate, `UseAuthenticationSchemes` override per endpoint, the `[Authorize]` attribute with no arguments uses the default scheme.

---

### 4.154 — Authorization Architecture: Middleware, Policy Evaluation, Requirements

**TOPIC_ID:** `4.154`
**TOPIC_NAME:** `Authorization Architecture: Middleware, Policy Evaluation, and Requirements`
**RELATED_TOPICS:**

```
- [[4.134 — Authentication Architecture]] — authentication runs before authorization; authorization reads the principal set by authentication
- [[4.155 — Role-Based and Claims-Based Authorization]] — [Authorize] with roles and claims policies are the two simplest forms of authorization
- [[4.156 — Policy-Based Authorization]] — policies are the extension point for complex authorization logic
- [[4.157 — IAuthorizationHandler]] — handlers implement the evaluation logic for requirements
- [[4.052 — Middleware Ordering]] — UseAuthorization must be after UseRouting and UseAuthentication
```

**Key topics inside this note:** The authorization pipeline: request → routing resolves endpoint → endpoint has IAuthorizeData (policies, roles, schemes) → UseAuthorization runs IAuthorizationMiddlewareResultHandler → IAuthorizationService evaluates all policies → all must pass for the endpoint to execute; `IAuthorizationRequirement` — the data object describing what must be true; `IAuthorizationHandler` — the evaluator that inspects ClaimsPrincipal and the requirement; `AuthorizationHandlerContext` — contains user, requirement, and optional resource; `context.Succeed(requirement)` / `context.Fail()` / `context.Fail(reason)`; policies are named collections of requirements: `services.AddAuthorization(o => o.AddPolicy("Admin", p => p.RequireRole("Admin")))`, `[Authorize(Policy = "Admin")]`; the difference between Challenge (unauthenticated) and Forbid (authenticated but not authorized); global authorization filter with `RequireAuthenticatedUser()`.

---

### 4.167 — DataAnnotations Validation in ASP.NET Core

**TOPIC_ID:** `4.167`
**TOPIC_NAME:** `DataAnnotations Validation in ASP.NET Core`
**RELATED_TOPICS:**

```
- [[4.102 — Model Validation: DataAnnotations and ModelState]] — DataAnnotations run during model binding; ModelState holds the results
- [[4.168 — ModelState: Checking Validity and Custom Responses]] — after DataAnnotations run, ModelState.IsValid is the gate
- [[4.170 — FluentValidation Integration]] — FluentValidation replaces DataAnnotations for complex validation; understanding both enables the comparison
- [[4.174 — Global Validation: SuppressModelStateInvalidFilter]] — [ApiController] auto-returns 400 on ModelState failure; this note explains how to customize that
```

**Key topics inside this note:** Built-in attributes: `[Required]`, `[StringLength]`, `[MinLength]`, `[MaxLength]`, `[Range]`, `[EmailAddress]`, `[Phone]`, `[Url]`, `[RegularExpression]`, `[Compare]`, `[CreditCard]`, `[DataType]`; `[Required]` on value types (int, DateTime) — always valid unless `[Required]` is combined with nullable; `ErrorMessage`, `ErrorMessageResourceType`, `ErrorMessageResourceName` for localization; validation attributes on model properties vs method parameters; `[ApiController]` automatic 400 — when ModelState.IsValid is false, a 400 with ValidationProblemDetails is returned before the action executes; composing validation with `IValidatableObject` for cross-property rules; why DataAnnotations is insufficient for production: no async validation, no dependency injection in attributes, no complex conditional logic.

---

### 4.177 — Exception Handling Middleware: UseExceptionHandler and Error Pipelines

**TOPIC_ID:** `4.177`
**TOPIC_NAME:** `Exception Handling Middleware: UseExceptionHandler and Error Pipelines`
**RELATED_TOPICS:**

```
- [[4.052 — Middleware Ordering]] — UseExceptionHandler must be first in the pipeline; it wraps everything else
- [[4.179 — Problem Details (RFC 7807)]] — IProblemDetailsService formats the error response; UseExceptionHandler triggers it
- [[4.181 — Exception Filters]] — exception filters handle exceptions inside the MVC pipeline only; UseExceptionHandler handles everything
- [[4.182 — Global Exception Handler (.NET 8): IExceptionHandler]] — IExceptionHandler is the modern alternative to UseExceptionHandler error path lambda
- [[4.183 — Correlation IDs]] — the exception handler is where the correlation ID is included in the error response
```

**Key topics inside this note:** `app.UseExceptionHandler("/error")` — catches unhandled exceptions, re-executes the pipeline at `/error` with the exception in HttpContext.Features; `app.UseExceptionHandler(exceptionHandlerApp => ...)` — inline handler without re-execution; `IExceptionHandlerFeature` — reading the caught exception in the error handler; what happens to the response when an exception is caught mid-stream (response already started — cannot change status code, only log); `app.UseDeveloperExceptionPage()` as the development alternative (shows full stack trace); mapping domain exceptions to problem details in the exception handler; the danger of throwing in the exception handler (unhandled, process can crash); the correct pattern: catch → log → write problem details → return.

---

### 4.179 — Problem Details (RFC 7807): IProblemDetailsService in ASP.NET Core

**TOPIC_ID:** `4.179`
**TOPIC_NAME:** `Problem Details (RFC 7807): IProblemDetailsService in ASP.NET Core`
**RELATED_TOPICS:**

```
- [[4.177 — Exception Handling Middleware]] — UseExceptionHandler triggers problem details generation for unhandled exceptions
- [[4.118 — Problem Details in MVC: ValidationProblemDetails]] — MVC uses ProblemDetails for 400 (validation) and other client errors
- [[4.182 — Global Exception Handler (.NET 8)]] — IExceptionHandler produces problem details for structured exception handling
- [[4.168 — ModelState Errors and Custom Responses]] — ValidationProblemDetails is the problem details type for model validation failures
```

**Key topics inside this note:** RFC 7807 problem details format: `type`, `title`, `status`, `detail`, `instance`; `ProblemDetails` class and `ValidationProblemDetails` (adds `errors` dictionary); `builder.Services.AddProblemDetails()` — registers IProblemDetailsService; custom problem detail fields via `extensions` dictionary; `IProblemDetailsService.WriteAsync()` — programmatic problem details writing; `IExceptionHandler` vs the exception handler middleware approach; the content type: `application/problem+json`; `UseStatusCodePages` integration with problem details for 404/405; ensuring all error responses use problem details format — the consistency requirement for API clients; `ProblemDetailsOptions.CustomizeProblemDetails` for adding request ID and trace ID to every problem details response.

---

## GENERATION ORDER (Recommended)

Work through topics in this order for maximum knowledge compounding:

```
FOUNDATION (Start Here — Beginner)
[ ] 4.001 — ASP.NET Core Request Pipeline Mental Model
[ ] 4.002 — WebApplication and WebApplicationBuilder
[ ] 4.011 — IConfiguration: The Layered Configuration System
[ ] 4.012 — Configuration Providers
[ ] 4.023 — ILogger<T>: The .NET Logging Abstraction
[ ] 4.024 — Log Levels, Categories, Filtering
[ ] 4.034 — The Built-In DI Container
[ ] 4.035 — Service Lifetimes: Singleton, Scoped, Transient
[ ] 4.049 — The Middleware Pipeline
[ ] 4.050 — Writing Middleware: IMiddleware vs Convention-Based
[ ] 4.052 — Middleware Ordering: The Canonical Order
[ ] 4.064 — Endpoint Routing
[ ] 4.065 — Route Templates
[ ] 4.078 — Minimal APIs: Why They Exist
[ ] 4.079 — Defining Endpoints: MapGet/MapPost
[ ] 4.080 — Route Parameter Binding in Minimal APIs
[ ] 4.082 — IResult and TypedResults
[ ] 4.098 — ControllerBase vs Controller
[ ] 4.099 — Action Results: IActionResult and ActionResult<T>
[ ] 4.100 — Model Binding: Sources and Algorithm
[ ] 4.102 — Model Validation: DataAnnotations and ModelState
[ ] 4.134 — Authentication Architecture
[ ] 4.136 — JWT Bearer Authentication
[ ] 4.137 — Generating JWT Access Tokens
[ ] 4.154 — Authorization Architecture
[ ] 4.155 — Role-Based and Claims-Based Authorization
[ ] 4.167 — DataAnnotations Validation
[ ] 4.177 — Exception Handling Middleware
[ ] 4.179 — Problem Details (RFC 7807)
[ ] 4.003 — IWebHostEnvironment: Environments

PRODUCTION READINESS (Intermediate)
[ ] 4.016 — IOptions<T>: Type-Safe Configuration
[ ] 4.017 — IOptionsSnapshot vs IOptionsMonitor
[ ] 4.019 — Options Validation: Fail-Fast at Startup
[ ] 4.025 — Structured Logging
[ ] 4.026 — Log Scopes
[ ] 4.028 — Serilog Integration
[ ] 4.036 — IServiceProvider and IServiceScope
[ ] 4.037 — Factory-Based DI
[ ] 4.038 — Keyed Services (.NET 8)
[ ] 4.042 — The Captive Dependency Problem
[ ] 4.046 — DI Validation at Startup
[ ] 4.051 — Pipeline Branching: Map, MapWhen, UseWhen
[ ] 4.053 — Built-In Middleware Reference
[ ] 4.054 — HttpContext and IHttpContextAccessor
[ ] 4.055 — Custom Exception Middleware
[ ] 4.057 — Middleware and Scoped DI
[ ] 4.066 — Route Constraints
[ ] 4.067 — Attribute Routing on Controllers
[ ] 4.070 — Route Groups
[ ] 4.083 — Minimal API Filters: IEndpointFilter
[ ] 4.084 — Route Groups in Minimal APIs
[ ] 4.085 — OpenAPI Integration in Minimal APIs
[ ] 4.086 — Validation in Minimal APIs
[ ] 4.089 — Authorization on Minimal API Endpoints
[ ] 4.092 — Minimal API vs MVC: Decision Framework
[ ] 4.093 — Organizing Minimal APIs
[ ] 4.101 — ApiController Attribute
[ ] 4.103 — Content Type Negotiation
[ ] 4.107 — Output Formatters
[ ] 4.110 — MVC Filter Pipeline
[ ] 4.118 — Problem Details in MVC
[ ] 4.123 — HttpContext Deep Dive
[ ] 4.124 — HttpRequest: Reading Request Data
[ ] 4.125 — HttpResponse: Writing Response Data
[ ] 4.135 — Cookie Authentication
[ ] 4.138 — Refresh Token Pattern
[ ] 4.139 — OAuth 2.0 Flow
[ ] 4.140 — OpenID Connect
[ ] 4.142 — ASP.NET Core Identity
[ ] 4.143 — Identity: Password Hashing and Two-Factor
[ ] 4.148 — Multiple Authentication Schemes
[ ] 4.149 — Claims Transformation
[ ] 4.156 — Policy-Based Authorization
[ ] 4.157 — IAuthorizationHandler
[ ] 4.158 — Resource-Based Authorization
[ ] 4.159 — IAuthorizationService: Programmatic Authorization
[ ] 4.163 — Authorization in Minimal APIs
[ ] 4.168 — ModelState: Reading and Customizing Errors
[ ] 4.170 — FluentValidation Integration
[ ] 4.174 — Global Validation Response Factory
[ ] 4.180 — Status Code Pages and Custom Error Responses
[ ] 4.181 — Exception Filters
[ ] 4.182 — Global Exception Handler (.NET 8)
[ ] 4.183 — Correlation IDs
[ ] 4.186 — IMemoryCache
[ ] 4.187 — IDistributedCache
[ ] 4.188 — Redis as IDistributedCache
[ ] 4.189 — Cache-Aside Pattern
[ ] 4.190 — Response Caching
[ ] 4.191 — Output Caching (.NET 7+)
[ ] 4.192 — Output Caching Policies: VaryBy and Tags
[ ] 4.202 — Rate Limiting (.NET 7+)
[ ] 4.203 — Rate Limiting Partitioning
[ ] 4.208 — HTTPS Enforcement and HSTS
[ ] 4.209 — CORS
[ ] 4.210 — CSRF / Antiforgery
[ ] 4.231 — IHostedService
[ ] 4.232 — BackgroundService
[ ] 4.233 — Timed Background Service
[ ] 4.234 — Queued Background Tasks
[ ] 4.249 — IHttpClientFactory
[ ] 4.250 — Named and Typed HTTP Clients
[ ] 4.251 — DelegatingHandler
[ ] 4.252 — Polly Integration with HttpClient
[ ] 4.257 — WebApplicationFactory Integration Testing
[ ] 4.258 — Customizing WebApplicationFactory
[ ] 4.259 — Authentication in Integration Tests
[ ] 4.260 — Database in Integration Tests
[ ] 4.268 — System.Text.Json Global Configuration
[ ] 4.269 — JsonSerializerOptions
[ ] 4.277 — API Versioning
[ ] 4.279 — OpenAPI / Swagger Integration
[ ] 4.288 — Filter Pipeline: Six Types and Order
[ ] 4.289 — Action Filters
[ ] 4.297 — Activity API and Distributed Tracing
[ ] 4.299 — OpenTelemetry .NET SDK
[ ] 4.323 — Health Check Middleware
[ ] 4.330 — Docker: Containerizing ASP.NET Core
[ ] 4.331 — Docker: Multi-Stage Builds
[ ] 4.336 — GitHub Actions CI/CD

ADVANCED (Senior Engineer Patterns)
[ ] 4.004 — Generic Host Internals
[ ] 4.007 — Kestrel Advanced Configuration
[ ] 4.031 — High-Performance Logging: LoggerMessage
[ ] 4.040 — Multiple DI Implementations: IEnumerable<T>
[ ] 4.044 — Decorators in DI: Scrutor
[ ] 4.060 — Zero-Allocation Middleware
[ ] 4.086 — FluentValidation in Minimal APIs
[ ] 4.108 — Custom Model Binders
[ ] 4.127 — HTTP/2 in Kestrel
[ ] 4.145 — API Key Authentication Handler
[ ] 4.164 — Authorization Caching
[ ] 4.171 — Async FluentValidation
[ ] 4.175 — Validation Across Layers
[ ] 4.193 — Cache Stampede Prevention
[ ] 4.196 — HybridCache (.NET 9)
[ ] 4.199 — Request Timeouts (.NET 8)
[ ] 4.205 — Distributed Rate Limiting with Redis
[ ] 4.211 — Data Protection API
[ ] 4.213 — Security Headers Middleware
[ ] 4.215 — IDOR Prevention
[ ] 4.218 — OWASP Top 10 in ASP.NET Core
[ ] 4.219 — SignalR Architecture
[ ] 4.220 — SignalR Hubs
[ ] 4.222 — SignalR Scale-Out
[ ] 4.223 — SignalR Authentication (JWT + WS)
[ ] 4.235 — Scoped Services in BackgroundService
[ ] 4.240 — gRPC Service Implementation
[ ] 4.241 — gRPC Streaming
[ ] 4.248 — gRPC vs REST vs GraphQL Decision
[ ] 4.255 — HttpClient Lifetime and Socket Exhaustion
[ ] 4.261 — Middleware Isolation Testing
[ ] 4.267 — Load Testing ASP.NET Core
[ ] 4.271 — JSON Source Generation
[ ] 4.278 — Asp.Versioning: AddApiVersioning
[ ] 4.284 — Idempotency Keys
[ ] 4.290 — Result Filters
[ ] 4.291 — Exception Filters: Scoped Exception Handling
[ ] 4.295 — Filter Ordering: IOrderedFilter
[ ] 4.296 — DI in Filters: ServiceFilter vs TypeFilter
[ ] 4.300 — OpenTelemetry Exporters
[ ] 4.301 — Metrics in .NET 8+
[ ] 4.302 — Prometheus Metrics
[ ] 4.325 — Readiness vs Liveness Probes (Kubernetes)
[ ] 4.329 — Reverse Proxy and ForwardedHeaders
[ ] 4.333 — Kubernetes Deployments and ConfigMaps
[ ] 4.334 — Kubernetes Secrets and Pod Identity
[ ] 4.339 — Native AOT with ASP.NET Core

EXPERT (Internals, Custom Infrastructure, Specialist)
[ ] 4.043 — Replacing the DI Container: Autofac
[ ] 4.094 — Minimal API Source Generators
[ ] 4.097 — Minimal API AOT Compatibility
[ ] 4.129 — HTTP/3 and QUIC
[ ] 4.200 — Minimal Allocation: PipeReader and IBufferWriter
[ ] 4.212 — Data Protection Key Management
[ ] 4.247 — gRPC JSON Transcoding
[ ] 4.304 — EventSource and EventCounter
[ ] 4.306 — Log Sampling in Production
[ ] 4.340 — Request Delegate Compilation Internals
[ ] 4.341 — Minimal API Source Generation Internals
[ ] 4.342 — Blazor Server
[ ] 4.343 — Blazor WebAssembly
[ ] 4.344 — Blazor United (.NET 8)
[ ] 4.345 — YARP: Yet Another Reverse Proxy
[ ] 4.346 — Custom Kestrel Protocols
[ ] 4.347 — ASP.NET Core with Orleans
[ ] 4.348 — Request Coalescing
[ ] 4.349 — Multipart Streaming Without Buffering
[ ] 4.350 — IEndpointMetadataProvider
[ ] 4.351 — ASP.NET Core Request Lifecycle Anatomy
[ ] 4.352 — Source-Generated Route Dispatcher Internals
```

---

_Last updated: 2026-06 · Domain: ASP.NET Core Mastery · File: Topic Index_
_Tags: #index #aspnetcore #dotnet #engineering #study-system_

