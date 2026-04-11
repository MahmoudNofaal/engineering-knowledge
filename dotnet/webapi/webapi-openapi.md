# ASP.NET Core Web API OpenAPI / Swagger

> OpenAPI is the industry-standard machine-readable description of your API's endpoints, parameters, request bodies, and response shapes — Swagger UI uses it to generate interactive documentation automatically.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Auto-generated JSON/YAML contract describing every endpoint, type, and response |
| **Use when** | Any API consumed by external clients, frontend teams, or third-party integrations |
| **Avoid when** | Purely internal service-to-service APIs on trusted networks where SDK generation isn't needed |
| **Primary packages** | `Swashbuckle.AspNetCore` (NuGet); built-in `Microsoft.AspNetCore.OpenApi` (.NET 9) |
| **Namespace** | `Microsoft.OpenApi.Models`, `Swashbuckle.AspNetCore.SwaggerGen` |
| **Key types** | `SwaggerGenOptions`, `OpenApiOperation`, `IOperationFilter`, `ISchemaFilter`, `IDocumentFilter` |

---

## When To Use It

Use OpenAPI for any API consumed by clients you don't fully control — frontend developers, mobile teams, third-party integrators, or anyone who needs to understand the contract without reading your source code. The generated document drives SDK generation (NSwag, AutoRest, Kiota), client validation, and contract testing. Skip it for purely internal infrastructure APIs where all consumers are internal services with shared type packages and no documentation requirement.

---

## Core Concept

Swashbuckle inspects your controller actions and minimal API endpoints at startup — reading route templates, HTTP method attributes, `[FromBody]`/`[FromQuery]` attributes, return types, and data annotations — and builds an `OpenApiDocument` from them. That document is served at `/swagger/v1/swagger.json`. Swagger UI reads the JSON and renders an interactive HTML page where anyone can browse endpoints and make real HTTP calls. The key to accurate documentation is giving Swashbuckle enough type information: `ActionResult<T>` (or `TypedResults` for minimal APIs) tells it the success schema; `[ProducesResponseType]` tells it about error responses; XML doc comments populate `summary` and `description` fields. Operation filters and schema filters let you customise the output programmatically — adding auth headers, stripping internal fields, or annotating enums.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `Swashbuckle.AspNetCore` third-party package — de facto standard |
| ASP.NET Core 2.1 | `ActionResult<T>` enables schema inference without `[ProducesResponseType]` on every action |
| .NET 6 | Swagger UI included in the default Web API template |
| .NET 7 | `TypedResults` for minimal APIs — OpenAPI response schema inference without attributes |
| .NET 9 | `Microsoft.AspNetCore.OpenApi` built-in package — Microsoft's own implementation |

*Until .NET 9, Swashbuckle was the only maintained option. .NET 9 ships `Microsoft.AspNetCore.OpenApi` as a first-party package. For existing projects using Swashbuckle, migration is straightforward — the concepts are identical.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Swagger document generation | ~50–500 ms at startup | Reflection-heavy; done once, cached |
| `/swagger/v1/swagger.json` serve | ~1 ms | Cached serialised JSON; trivial |
| Swagger UI HTML load | ~200 ms client-side | Browser rendering; irrelevant for production |

**Allocation behaviour:** Swagger document generation is reflection-heavy and allocates significantly — but only once at startup. The generated `OpenApiDocument` is cached in memory. For APIs with hundreds of endpoints, startup time increases measurably (500+ ms) but runtime overhead is zero.

**Benchmark notes:** Disable Swagger in production — not for performance reasons (it's cached) but for security: the document exposes your entire API surface to anyone who can reach the endpoint. Gate it behind an environment check or an auth policy.

---

## The Code

**Basic setup in Program.cs**
```csharp
// dotnet add package Swashbuckle.AspNetCore
builder.Services.AddEndpointsApiExplorer();     // required for minimal APIs
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title       = "Orders API",
        Version     = "v1",
        Description = "Manages customer orders.",
        Contact     = new OpenApiContact
        {
            Name  = "Platform Team",
            Email = "platform@example.com"
        }
    });
});

var app = builder.Build();

// Only expose Swagger in non-production environments
if (!app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "Orders API v1");
        options.RoutePrefix = string.Empty;     // Swagger UI at root "/"
    });
}
```

**Adding JWT auth to Swagger UI**
```csharp
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Orders API", Version = "v1" });

    // Adds the "Authorize" button to Swagger UI
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name         = "Authorization",
        Type         = SecuritySchemeType.Http,
        Scheme       = "Bearer",
        BearerFormat = "JWT",
        In           = ParameterLocation.Header,
        Description  = "Enter your JWT token. Example: eyJhbGci..."
    });

    // Applies the security requirement to all operations
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                    { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});
```

**`[ProducesResponseType]` — document all possible responses**
```csharp
[HttpGet("{id:guid}")]
[ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
public async Task<IActionResult> GetById(Guid id)
{
    var order = await _orders.GetAsync(id);
    return order is null ? NotFound() : Ok(order);
}

// OR use ActionResult<T> to infer the 200 schema automatically (no attribute needed)
[HttpGet("{id:guid}")]
[ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
public async Task<ActionResult<OrderDto>> GetById(Guid id)
{
    var order = await _orders.GetAsync(id);
    return order is null ? NotFound() : Ok(order);
}
```

**XML doc comments — populate `summary` and `description`**
```xml
<!-- .csproj -->
<PropertyGroup>
  <GenerateDocumentationFile>true</GenerateDocumentationFile>
  <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```
```csharp
builder.Services.AddSwaggerGen(options =>
{
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    options.IncludeXmlComments(xmlPath);
});

/// <summary>Gets an order by its unique identifier.</summary>
/// <param name="id">The order GUID.</param>
/// <returns>The order details.</returns>
/// <response code="200">Order found and returned.</response>
/// <response code="404">No order exists with the specified ID.</response>
[HttpGet("{id:guid}")]
[ProducesResponseType(typeof(OrderDto), 200)]
[ProducesResponseType(typeof(ProblemDetails), 404)]
public async Task<IActionResult> GetById(Guid id) { ... }
```

**Operation filter — add a custom header to every operation**
```csharp
public class CorrelationIdOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        operation.Parameters ??= new List<OpenApiParameter>();
        operation.Parameters.Add(new OpenApiParameter
        {
            Name     = "X-Correlation-Id",
            In       = ParameterLocation.Header,
            Required = false,
            Schema   = new OpenApiSchema { Type = "string", Format = "uuid" },
            Description = "Optional client-provided correlation ID for request tracing."
        });
    }
}

// Register:
builder.Services.AddSwaggerGen(options =>
    options.OperationFilter<CorrelationIdOperationFilter>());
```

**Schema filter — annotate enum values with descriptions**
```csharp
public class EnumSchemaFilter : ISchemaFilter
{
    public void Apply(OpenApiSchema schema, SchemaFilterContext context)
    {
        if (!context.Type.IsEnum) return;

        schema.Enum.Clear();
        schema.Description = string.Join(", ",
            Enum.GetNames(context.Type)
                .Select(name => $"{name} = {(int)Enum.Parse(context.Type, name)}"));
    }
}

builder.Services.AddSwaggerGen(options =>
    options.SchemaFilter<EnumSchemaFilter>());
```

**Versioned Swagger documents (integrates with `Asp.Versioning`)**
```csharp
// ConfigureSwaggerOptions.cs
public class ConfigureSwaggerOptions(IApiVersionDescriptionProvider provider)
    : IConfigureOptions<SwaggerGenOptions>
{
    public void Configure(SwaggerGenOptions options)
    {
        foreach (var description in provider.ApiVersionDescriptions)
        {
            options.SwaggerDoc(description.GroupName, new OpenApiInfo
            {
                Title      = $"Orders API {description.GroupName}",
                Version    = description.ApiVersion.ToString(),
                Description = description.IsDeprecated
                    ? "This version is deprecated. Please migrate to a newer version."
                    : string.Empty
            });
        }
    }
}

// Program.cs
builder.Services.AddTransient<IConfigureOptions<SwaggerGenOptions>, ConfigureSwaggerOptions>();

app.UseSwaggerUI(options =>
{
    foreach (var desc in app.DescribeApiVersions())
        options.SwaggerEndpoint(
            $"/swagger/{desc.GroupName}/swagger.json",
            $"Orders API {desc.GroupName.ToUpper()}");
});
```

---

## Real World Example

A payment API needs accurate OpenAPI docs consumed by three client teams: a React frontend (uses Swagger UI for exploration), a mobile team (generates a TypeScript SDK via NSwag), and a QA team (runs contract tests against the spec). Accurate schema is non-negotiable — wrong docs cause SDK bugs.

```csharp
// Program.cs — production-grade Swagger setup
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title       = "Payments API",
        Version     = "v1",
        Description = """
            Handles payment processing, refunds, and dispute management.
            All amounts are in the smallest currency unit (e.g., pence for GBP).
            """,
        License  = new OpenApiLicense { Name = "Proprietary" }
    });

    // JWT auth
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization", Type = SecuritySchemeType.Http,
        Scheme = "Bearer", BearerFormat = "JWT", In = ParameterLocation.Header
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { new OpenApiSecurityScheme { Reference = new OpenApiReference
            { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
          Array.Empty<string>() }
    });

    // XML comments
    options.IncludeXmlComments(
        Path.Combine(AppContext.BaseDirectory, "PaymentsApi.xml"),
        includeControllerXmlComments: true);

    // Custom filters
    options.OperationFilter<CorrelationIdOperationFilter>();
    options.OperationFilter<IdempotencyKeyOperationFilter>();
    options.SchemaFilter<EnumSchemaFilter>();

    // Use fully qualified type names to avoid schema name collisions
    options.CustomSchemaIds(type => type.FullName?.Replace("+", "."));
});

// Controller with complete documentation
/// <summary>Manages payment operations.</summary>
[ApiController]
[Route("api/v1/payments")]
[Produces("application/json")]
public class PaymentsController : ControllerBase
{
    /// <summary>Initiates a payment charge.</summary>
    /// <param name="req">The charge details.</param>
    /// <param name="idempotencyKey">Unique key to prevent duplicate charges.</param>
    /// <returns>The created charge.</returns>
    /// <response code="201">Charge created successfully.</response>
    /// <response code="402">Payment declined by the card issuer.</response>
    /// <response code="409">A charge with this idempotency key already exists.</response>
    /// <response code="422">Business rule violation (e.g., amount below minimum).</response>
    [HttpPost]
    [Authorize]
    [ProducesResponseType(typeof(ChargeDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status402PaymentRequired)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<ChargeDto>> Charge(
        [FromBody] CreateChargeRequest req,
        [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
    {
        // ... implementation
        return CreatedAtAction(nameof(GetCharge), new { id = charge.Id }, charge);
    }
}
```

*The key insight: the combination of `ActionResult<ChargeDto>` (200 schema inference), `[ProducesResponseType]` for non-200 responses, and XML doc comments gives NSwag everything it needs to generate a fully typed TypeScript SDK where `paymentsClient.charge(req)` returns `Promise<ChargeDto>` with correct types for every error case.*

---

## Common Misconceptions

**"Swagger UI is the same as OpenAPI."**
OpenAPI is the specification — a JSON or YAML document describing your API. Swagger UI is one tool that reads that document and renders it as an interactive HTML page. NSwag, Redoc, Scalar, and Kiota are other tools that consume the same OpenAPI document for different purposes (client generation, alternative UI, SDK generation). The document is the asset; Swagger UI is just a viewer.

**"`ActionResult<T>` documents all my responses automatically."**
`ActionResult<T>` tells Swashbuckle the 200 OK response schema. It does not document 400, 401, 404, 422, or 500 responses. You must add `[ProducesResponseType(typeof(ProblemDetails), 404)]` for each non-success response you want in the spec. Without them, client SDK generators generate methods with no error types, which means SDK consumers have no idea what errors to handle.

**"Swagger should be disabled in production."**
The interactive UI should be restricted in production (auth-gate it or disable it). The OpenAPI JSON document itself can be exposed in production — client SDK generators, monitoring tools, and contract testing systems may need it. The distinction is: disable the interactive UI for security; keeping the spec endpoint available for tooling is fine if it's behind authentication.

---

## Gotchas

- **`AddEndpointsApiExplorer()` is required for minimal APIs.** Without it, minimal API endpoints don't appear in the Swagger document. Controllers work without it — the call is only needed for minimal APIs.

- **Two DTOs with the same class name in different namespaces cause schema conflicts.** Swashbuckle uses the simple class name as the schema ID by default. `Orders.CreateRequest` and `Products.CreateRequest` both become `CreateRequest` in the schema — one silently overwrites the other. Fix with `options.CustomSchemaIds(t => t.FullName?.Replace("+", "."))`.

- **`[ProducesResponseType]` on a base controller applies to all derived controllers.** If you put `[ProducesResponseType(401)]` on a `BaseApiController`, every endpoint inheriting from it gets that response documented. This is often correct — but be aware it happens automatically.

- **Swagger document generation fails silently on circular references.** If your DTOs have circular references (`Order` has `List<OrderLine>`, `OrderLine` has `Order`), Swashbuckle may generate an infinite schema loop or throw at startup. Break cycles by using projection DTOs without back-references.

- **`[Obsolete]` on an action marks it as deprecated in the OpenAPI spec.** This is intentional and useful — mark deprecated endpoints with `[Obsolete]` and they'll appear in the Swagger document with a ~~strikethrough~~ style in most UIs.

- **Operation-level security requirements override document-level ones.** If you add a global security requirement and then add a per-operation one, the per-operation one replaces the global — it doesn't merge. For endpoints with different auth schemes, set the security requirement explicitly on each operation.

---

## Interview Angle

**What they're really testing:** Whether you understand that OpenAPI is a contract — not just documentation — and that it drives client SDK generation, contract testing, and API governance.

**Common question forms:**
- "How do you document your API?"
- "How do you ensure Swagger shows all possible response codes for an endpoint?"
- "How would you add authentication to the Swagger UI?"
- "How does OpenAPI integrate with API versioning?"

**The depth signal:** A junior knows Swagger UI shows endpoints and you add `AddSwaggerGen()`. A senior explains that `ActionResult<T>` infers the 200 schema while `[ProducesResponseType]` documents error responses, that the OpenAPI document drives NSwag/Kiota SDK generation making documentation a developer productivity tool (not just docs), that `IOperationFilter` and `ISchemaFilter` allow programmatic customisation without attribute clutter, and that the document should be auth-gated or environment-restricted — not publicly exposed as an attack surface in production.

**Follow-up questions to expect:**
- "How would you generate a TypeScript SDK from your OpenAPI spec?"
- "How do you handle DTOs with the same name in different namespaces?"
- "How do you document an endpoint that accepts a file upload?"

---

## Related Topics

- [[dotnet/webapi/webapi-versioning.md]] — versioned APIs need one Swagger document per version; `IApiVersionDescriptionProvider` + `ConfigureSwaggerOptions` produces separate docs automatically
- [[dotnet/webapi/webapi-controllers.md]] — `ActionResult<T>` is the primary mechanism for response schema inference; `[ProducesResponseType]` supplements it for error responses
- [[dotnet/webapi/webapi-minimal-apis.md]] — `TypedResults` and `Results<T1, T2>` provide schema inference for minimal API endpoints; `AddEndpointsApiExplorer()` is required for them to appear
- [[dotnet/webapi/webapi-authentication.md]] — JWT bearer auth must be declared as a security scheme in `AddSwaggerGen` and the Swagger UI "Authorize" button configured to send it

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/tutorials/getting-started-with-swashbuckle

---
*Last updated: 2026-04-10*