# WebAPI Authorization

> The ASP.NET Core system for deciding what an authenticated user is allowed to do — enforced through roles, claims-based policies, or resource-level checks after identity is already confirmed.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Policy evaluation system that controls access based on user claims and resource state |
| **Use when** | Different users should have access to different resources or operations |
| **Avoid when** | Never avoid — but don't scatter manual `if (user.Role != "Admin")` checks in controllers |
| **Introduced** | ASP.NET Core 1.0; policy-based auth added ASP.NET Core 1.0; `IAuthorizationHandler` since 1.0 |
| **Namespace** | `Microsoft.AspNetCore.Authorization` |
| **Key types** | `IAuthorizationHandler`, `IAuthorizationRequirement`, `AuthorizationPolicy`, `IAuthorizationService` |

---

## When To Use It

Use it any time different users should have access to different things — admin vs regular user, owner vs viewer, premium vs free tier. Role-based checks are fine for coarse-grained access ("only Admins can delete"). Policy-based authorization is the right tool when the rule is more complex than a single role — checking a claim value, a combination of conditions, or whether the user owns the specific resource being requested. Don't put access logic inside your service layer or controllers manually with `if (user.Role != "Admin") return Forbid()` scattered everywhere — that's what policies are for.

---

## Core Concept

Authorization in ASP.NET Core is a layer on top of authentication. By the time the authorization middleware runs, `HttpContext.User` is already populated with claims. You define named policies in `Program.cs` — each policy is a set of requirements — and decorate endpoints with `[Authorize(Policy = "PolicyName")]`. The framework evaluates the requirements against the current user's claims and either allows the request through or returns a 403. For resource-based checks (does this user own *this specific order*?) you inject `IAuthorizationService` and call it manually inside your handler, because the decorator can't know the resource until after the endpoint loads it from the database.

---

## Version History

| .NET Version | What changed |
|---|---|
| ASP.NET Core 1.0 | `[Authorize]`, `[AllowAnonymous]`, role-based auth, `IAuthorizationHandler` |
| ASP.NET Core 1.0 | Policy-based auth — `AddPolicy`, `IAuthorizationRequirement` |
| ASP.NET Core 2.0 | `IAuthorizationPolicyProvider` — generate policies dynamically at runtime |
| .NET 6 | `.RequireAuthorization()` on minimal API endpoints |
| .NET 7 | `AuthorizationBuilder` simplification in `AddAuthorizationBuilder()` |
| .NET 8 | `[Authorize]` can stack multiple policies (all must pass) |

*Before policy-based auth, role checks were the only built-in tool. Policies made authorization composable and testable — a `MinimumAgeRequirement` can be tested in isolation without an HTTP context.*

---

## Performance

| Operation | Cost | Notes |
|---|---|---|
| Role check (`[Authorize(Roles = "Admin")]`) | O(1) | Simple claim lookup in the principal |
| Policy evaluation | O(k) | k = number of requirements in the policy |
| Custom `IAuthorizationHandler` | Varies | Depends on implementation; avoid DB calls in handlers |
| `IAuthorizationService.AuthorizeAsync` | O(k) + handler cost | Called per resource access check |

**Allocation behaviour:** Policy evaluation allocates `AuthorizationResult` and `AuthorizationHandlerContext` per evaluation — lightweight. The main allocation concern is in custom handlers that construct objects or query databases. Avoid `IAuthorizationHandler` implementations that call the database — cache permission lookups in the current request's `HttpContext.Items` or use a short-lived `IMemoryCache` keyed on user ID.

**Benchmark notes:** Authorization overhead is negligible for role and claim checks. Custom handlers that hit the database add their database latency to every request. Cache aggressively and keep handlers free of I/O wherever possible.

---

## The Code

**Define policies in Program.cs**
```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("Admin"));

    options.AddPolicy("PremiumUser", policy =>
        policy.RequireClaim("subscription", "premium"));

    options.AddPolicy("SeniorEditor", policy =>
    {
        policy.RequireRole("Editor");
        policy.RequireClaim("experience_years", "5", "6", "7", "8", "9", "10");
    });

    // Fallback policy: all authenticated users must pass this for any [Authorize] endpoint
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});
```

**Apply policies to controllers and actions**
```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]                                     // all actions require authentication
public class ArticlesController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok();      // any authenticated user

    [HttpPost]
    [Authorize(Policy = "SeniorEditor")]
    public IActionResult Create() => Ok();

    [HttpDelete("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public IActionResult Delete(int id) => NoContent();

    [AllowAnonymous]
    [HttpGet("featured")]
    public IActionResult GetFeatured() => Ok();  // public
}
```

**Custom requirement and handler**
```csharp
public class MinimumAgeRequirement(int minimumAge) : IAuthorizationRequirement
{
    public int MinimumAge { get; } = minimumAge;
}

public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var dobClaim = context.User.FindFirst("date_of_birth");
        if (dobClaim is null) return Task.CompletedTask;  // absence = fail

        var dob = DateOnly.Parse(dobClaim.Value);
        var age = DateOnly.FromDateTime(DateTime.UtcNow).Year - dob.Year;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement);  // only call Succeed when the requirement is met

        return Task.CompletedTask;
    }
}

builder.Services.AddSingleton<IAuthorizationHandler, MinimumAgeHandler>();
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Over18", policy =>
        policy.AddRequirements(new MinimumAgeRequirement(18)));
});
```

**Resource-based authorization**
```csharp
public class OrdersController(
    IAuthorizationService authorizationService,
    IOrderRepository repo) : ControllerBase
{
    [HttpGet("{id}")]
    [Authorize]
    public async Task<IActionResult> GetOrder(int id)
    {
        var order = await repo.FindAsync(id);
        if (order is null) return NotFound();

        // Check ownership AFTER loading the resource
        var result = await authorizationService.AuthorizeAsync(User, order, "OrderOwner");
        if (!result.Succeeded)
            return Forbid();  // 403, not 404 — choose based on your threat model

        return Ok(order);
    }
}

public class OrderOwnerHandler
    : AuthorizationHandler<OperationAuthorizationRequirement, Order>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        OperationAuthorizationRequirement requirement,
        Order resource)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (resource.OwnerId.ToString() == userId)
            context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
```

**Minimal API policy enforcement**
```csharp
app.MapDelete("/api/orders/{id}", async (int id, IOrderRepository repo) =>
{
    await repo.DeleteAsync(id);
    return Results.NoContent();
})
.RequireAuthorization("AdminOnly");
```

---

## Real World Example

A project management SaaS has three roles (Owner, Editor, Viewer) and a permission model where Editors can edit only projects they're members of. Owners can edit anything in their organisation. A custom requirement checks both role and project membership.

```csharp
// The requirement carries what we need to check
public class ProjectAccessRequirement(ProjectOperation operation) : IAuthorizationRequirement
{
    public ProjectOperation Operation { get; } = operation;
}

public enum ProjectOperation { View, Edit, Delete }

// The handler checks role + membership
public class ProjectAccessHandler(IProjectMemberRepository members)
    : AuthorizationHandler<ProjectAccessRequirement, Project>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ProjectAccessRequirement requirement,
        Project project)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null) return;

        // Org owners can do anything
        if (context.User.HasClaim("org_role", "Owner"))
        {
            context.Succeed(requirement);
            return;
        }

        // Editors need membership AND edit permission
        var membership = await members.FindAsync(project.Id, userId);
        if (membership is null) return;   // not a member — fail

        var allowed = requirement.Operation switch
        {
            ProjectOperation.View   => true,              // all members can view
            ProjectOperation.Edit   => membership.CanEdit,
            ProjectOperation.Delete => false,             // only owners can delete
            _                       => false
        };

        if (allowed) context.Succeed(requirement);
    }
}

// Registration
builder.Services.AddScoped<IAuthorizationHandler, ProjectAccessHandler>();

// Controller usage
[HttpPut("{id:guid}")]
[Authorize]
public async Task<IActionResult> Update(Guid id, [FromBody] UpdateProjectRequest req)
{
    var project = await _projects.GetAsync(id);
    if (project is null) return NotFound();

    var authResult = await _authorizationService.AuthorizeAsync(
        User, project, new ProjectAccessRequirement(ProjectOperation.Edit));

    if (!authResult.Succeeded) return Forbid();

    return Ok(await _projects.UpdateAsync(id, req));
}
```

*The key insight: the authorization logic for "can this user edit this project" lives in one testable class (`ProjectAccessHandler`) that knows nothing about HTTP. You can unit-test it by constructing a `ClaimsPrincipal`, a `Project`, and a mock `IProjectMemberRepository` — no web server needed.*

---

## Common Misconceptions

**"Not calling `context.Succeed()` is the same as calling `context.Fail()`."**
It is not. If your handler does nothing (the claim is missing, the condition isn't met), the requirement stays unevaluated. Other handlers for the same requirement can still succeed it. Only call `context.Fail()` when you want to hard-block regardless of other handlers — for example, an account-suspended check that should override any other handler's `Succeed`. Silently returning without calling either is the correct way to "abstain."

**"CORS is the same as authorization."**
CORS controls which browser origins can make requests. Authorization controls which identities can access resources. They're completely separate. A CORS-blocked request is rejected by the browser before the server processes it. An unauthorized request is rejected by the server's authorization middleware. A determined attacker using curl or Postman bypasses CORS entirely — authorization is the actual security control.

**"I can use `[Authorize]` to check resource ownership."**
`[Authorize]` runs before the action — before the resource is loaded from the database. You cannot check ownership at the attribute level because you don't have the resource yet. Resource-based authorization must be done manually inside the action with `IAuthorizationService.AuthorizeAsync(user, resource, requirement)` after fetching the resource.

---

## Gotchas

- **Not calling `context.Succeed()` is not the same as calling `context.Fail()`.** If your handler does nothing, the requirement stays unevaluated. Other handlers for the same requirement can still succeed it. Call `context.Fail()` only to hard-block. This is the most misunderstood part of the handler model.

- **Resource-based authorization can't run at the `[Authorize]` attribute stage.** The resource hasn't been loaded yet. Putting a resource ownership check in a policy without a resource context will always silently pass or fail in unexpected ways. It must be called via `IAuthorizationService.AuthorizeAsync` after fetching the resource.

- **Returning `NotFound()` vs `Forbid()` on ownership failures leaks data.** If user B requests `/orders/42` which belongs to user A, returning 404 hides the order's existence. Returning 403 confirms it exists but is inaccessible. Choose based on your threat model — for sensitive resources, 404 is often correct even for authenticated non-owners.

- **Roles from JWT are read from the `role` claim by default, but the exact claim name depends on how your token is issued.** Auth0 puts roles in a custom namespace claim; Azure AD uses a different key. If `User.IsInRole("Admin")` always returns false, inspect the raw claims with `User.Claims` to find the actual key, then map it in `TokenValidationParameters.RoleClaimType`.

- **Policy evaluation short-circuits on the first `Fail()` but NOT on missing `Succeed()`.** A policy with three requirements must have all three `Succeed()` called to pass. If one handler does nothing, the policy fails — correct, but surprises people who expect a "not explicitly failed = passed" model.

- **`IAuthorizationHandler` registered as Singleton with a Scoped dependency causes a captive dependency bug.** If your handler depends on `IProjectMemberRepository` (Scoped), register the handler as `AddScoped`, not `AddSingleton`. The framework creates a DI scope for each authorization evaluation when the handler is Scoped.

---

## Interview Angle

**What they're really testing:** Whether you understand the separation between role-based and policy-based authorization, and whether you can handle real-world ownership checks that go beyond decorator-level access control.

**Common question forms:**
- "How do you implement role-based vs policy-based authorization in ASP.NET Core?"
- "How do you check if a user owns a specific resource before allowing access?"
- "What's the difference between returning 401 and 403?"
- "How would you test an authorization handler?"

**The depth signal:** A junior describes `[Authorize(Roles = "Admin")]` and maybe `AddPolicy` with `RequireRole`. A senior explains why `RequireRole` is just a built-in policy shorthand, when to write a custom `IAuthorizationHandler`, why resource-based checks must use `IAuthorizationService.AuthorizeAsync` inside the action rather than at the attribute level, the difference between not calling `Succeed` vs calling `Fail`, and the security trade-off between returning 403 vs 404 on ownership failures. They also know how to unit test an `AuthorizationHandler` by constructing a `ClaimsPrincipal` and `AuthorizationHandlerContext` directly.

**Follow-up questions to expect:**
- "How would you implement a dynamic authorization policy?"
- "What's the lifetime of IAuthorizationHandler and why does it matter?"
- "How do you apply authorization to minimal API endpoints?"

---

## Related Topics

- [[dotnet/webapi/webapi-authentication.md]] — authorization depends entirely on claims populated during authentication; the two middleware must be registered in the correct order
- [[dotnet/webapi/middleware-pipeline.md]] — `UseAuthentication()` → `UseAuthorization()` ordering is a pipeline constraint; understanding middleware order makes this non-negotiable rule obvious
- [[dotnet/webapi/dependency-injection.md]] — `IAuthorizationHandler` implementations are registered as DI services; their lifetime (singleton vs scoped) matters if they inject other dependencies
- [[dotnet/webapi/webapi-exception-handling.md]] — 401 and 403 responses from auth middleware bypass the global exception handler; knowing this prevents gaps in error response handling

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/authorization/introduction

---
*Last updated: 2026-04-10*