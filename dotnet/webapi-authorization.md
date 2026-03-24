# WebAPI Authorization

> The ASP.NET Core system for deciding what an authenticated user is allowed to do — enforced through roles, claims-based policies, or resource-level checks after identity is already confirmed.

---

## When To Use It

Use it any time different users should have access to different things — admin vs regular user, owner vs viewer, premium vs free tier. Role-based checks are fine for coarse-grained access ("only Admins can delete"). Policy-based authorization is the right tool when the rule is more complex than a single role — checking a claim value, a combination of conditions, or whether the user owns the specific resource being requested. Don't put access logic inside your service layer or controllers manually with `if (user.Role != "Admin") return Forbid()` scattered everywhere — that's what policies are for.

---

## Core Concept

Authorization in ASP.NET Core is a layer on top of authentication. By the time the authorization middleware runs, `HttpContext.User` is already populated with claims. You define named policies in `Program.cs` — each policy is a set of requirements — and then decorate endpoints with `[Authorize(Policy = "PolicyName")]`. The framework evaluates the requirements against the current user's claims and either allows the request through or returns a 403. For resource-based checks (does this user own *this specific order*?) you inject `IAuthorizationService` and call it manually inside your handler, because the decorator can't know the resource until after the endpoint runs and loads it from the database.

---

## The Code

**1. Define policies in Program.cs**
```csharp
// Program.cs
builder.Services.AddAuthorization(options =>
{
    // Role-based policy
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("Admin"));

    // Claim-based policy
    options.AddPolicy("PremiumUser", policy =>
        policy.RequireClaim("subscription", "premium"));

    // Combined requirements
    options.AddPolicy("SeniorEditor", policy =>
    {
        policy.RequireRole("Editor");
        policy.RequireClaim("experience_years", "5", "6", "7", "8", "9", "10");
    });
});
```

**2. Apply policies to controllers and actions**
```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize] // all actions require authentication
public class ArticlesController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(); // any authenticated user

    [HttpPost]
    [Authorize(Policy = "SeniorEditor")]
    public IActionResult Create() => Ok(); // only senior editors

    [HttpDelete("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public IActionResult Delete(int id) => NoContent(); // only admins

    [AllowAnonymous]
    [HttpGet("featured")]
    public IActionResult GetFeatured() => Ok(); // public
}
```

**3. Custom requirement + handler (when built-ins aren't enough)**
```csharp
// Authorization/MinimumAgeRequirement.cs
public class MinimumAgeRequirement(int minimumAge) : IAuthorizationRequirement
{
    public int MinimumAge { get; } = minimumAge;
}

// Authorization/MinimumAgeHandler.cs
public class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var dobClaim = context.User.FindFirst("date_of_birth");

        if (dobClaim is null)
            return Task.CompletedTask; // do NOT call Succeed — absence means fail

        var dob = DateOnly.Parse(dobClaim.Value);
        var age = DateOnly.FromDateTime(DateTime.UtcNow).Year - dob.Year;

        if (age >= requirement.MinimumAge)
            context.Succeed(requirement); // explicitly mark as passed

        return Task.CompletedTask;
    }
}

// Register in Program.cs
builder.Services.AddSingleton<IAuthorizationHandler, MinimumAgeHandler>();
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Over18", policy =>
        policy.AddRequirements(new MinimumAgeRequirement(18)));
});
```

**4. Resource-based authorization (does this user own this record?)**
```csharp
// Controllers/OrdersController.cs
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
        var result = await authorizationService.AuthorizeAsync(
            User, order, "OrderOwner");

        if (!result.Succeeded)
            return Forbid(); // 403, not 404 — don't leak existence

        return Ok(order);
    }
}

// Authorization/OrderOwnerHandler.cs
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

**5. Minimal API policy enforcement**
```csharp
app.MapDelete("/api/orders/{id}", async (int id, IOrderRepository repo) =>
{
    await repo.DeleteAsync(id);
    return Results.NoContent();
})
.RequireAuthorization("AdminOnly"); // equivalent to [Authorize(Policy = "AdminOnly")]
```

---

## Gotchas

- **Not calling `context.Succeed()` is not the same as calling `context.Fail()`.** If your handler does nothing (e.g. the claim is missing), the requirement stays unevaluated. Other handlers for the same requirement can still succeed it. Only call `context.Fail()` when you want to hard-block regardless of other handlers — like an account-suspended check.
- **Resource-based authorization can't run at the `[Authorize]` attribute stage** because the resource hasn't been loaded yet. Putting a resource ownership check in a policy registered via `AddPolicy` with no resource context will always silently pass or fail in unexpected ways. It must be called manually via `IAuthorizationService.AuthorizeAsync` after the resource is fetched.
- **Returning `NotFound()` vs `Forbid()` on ownership failures leaks data.** If user B requests `/orders/42` which belongs to user A, returning 404 hides the existence of the order. Returning 403 confirms it exists but is inaccessible. Choose based on your threat model — for sensitive resources, 404 is often correct even for authenticated users.
- **Roles from JWT are read from the `role` claim by default, but the exact claim name depends on how your token is issued.** Auth0 puts roles in a custom namespace claim; Azure AD uses a different key. If `User.IsInRole("Admin")` always returns false, inspect the raw claims with `User.Claims` to find the actual key, then map it in `TokenValidationParameters.RoleClaimType`.
- **Policy evaluation short-circuits on the first `Fail()` but NOT on missing `Succeed()`.** A policy with three requirements must have all three `Succeed()` called to pass. If one handler simply does nothing, the policy still fails — which is correct, but surprises people who expect a "not explicitly failed = passed" model.

---

## Interview Angle

**What they're really testing:** Whether you understand the separation between role-based and policy-based authorization, and whether you can handle real-world ownership checks that go beyond decorator-level access control.

**Common question form:** *"How do you implement role-based vs policy-based authorization in ASP.NET Core?"* or *"How do you check if a user owns a specific resource before allowing access?"*

**The depth signal:** A junior answer describes `[Authorize(Roles = "Admin")]` and maybe `AddPolicy` with `RequireRole`. A senior answer explains why `RequireRole` is just a built-in policy shorthand, when to write a custom `IAuthorizationHandler`, why resource-based checks must use `IAuthorizationService.AuthorizeAsync` inside the action rather than at the attribute level, the difference between not calling `Succeed` vs calling `Fail`, and the security tradeoff between returning 403 vs 404 on ownership failures.

---

## Related Topics

- [[dotnet/webapi-authentication.md]] — Authorization depends entirely on the claims populated during authentication; the two middleware must be registered in the correct order.
- [[dotnet/webapi-exception-handling.md]] — 401 and 403 responses bypass the global exception handler; knowing this prevents gaps where auth failures return unexpected response shapes.
- [[dotnet/dependency-injection.md]] — `IAuthorizationHandler` implementations are registered as services; their lifetime (singleton vs scoped) matters if they inject other dependencies like `DbContext`.
- [[dotnet/middleware-pipeline.md]] — `UseAuthentication()` → `UseAuthorization()` ordering is a pipeline constraint; understanding middleware order makes this non-negotiable rule obvious.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/security/authorization/introduction

---
*Last updated: 2026-03-24*