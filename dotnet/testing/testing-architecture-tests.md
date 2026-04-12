# Architecture Testing in .NET

> Architecture tests verify that your code's structure follows the rules you've defined — no layer dependencies in the wrong direction, no forbidden namespace references, naming conventions enforced automatically.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Tests that enforce architectural rules via reflection and static analysis |
| **Use when** | Clean Architecture, DDD, or any layered structure where dependency rules matter |
| **Avoid when** | Small projects with one layer; the rules are obvious from code review alone |
| **Key library** | `NetArchTest.Rules` — most popular .NET architecture testing library |
| **Key package** | `NetArchTest.Rules` |
| **Alternative** | `ArchUnitNET` — more powerful, steeper learning curve |

---

## When To Use It
Use architecture tests when your project has explicit layering rules that are easy to violate accidentally — Clean Architecture (Domain → Application → Infrastructure), DDD bounded contexts, or a rule like "no EF Core references in the Application layer." These rules are usually documented in a README that nobody reads. Architecture tests make them executable: a developer who accidentally references `DbContext` in a command handler gets a failing test immediately, not a code review comment two days later.

Don't use them on small projects where the dependency rules are obvious from the file structure, or on teams where code review catches these issues reliably. The value is proportional to team size and project age.

---

## Core Concept
`NetArchTest.Rules` uses reflection to inspect the compiled assembly. You write predicates that select types by namespace, name, or attribute, then assert that those types satisfy conditions — no dependencies on certain namespaces, implement certain interfaces, follow naming conventions. The assertions run as regular xUnit tests — they fail with a list of violating types when a rule is broken.

The key insight is that architecture rules are assertions about the *type graph*, not about runtime behavior. You're asking questions like "does any class in `MyApp.Application` have a field or method parameter whose type comes from `MyApp.Infrastructure`?" These are statically answerable by inspecting IL metadata.

---

## Version History

| Package | Version | What changed |
|---|---|---|
| `NetArchTest.Rules` | 1.0 | Core predicates and conditions API |
| `NetArchTest.Rules` | 1.3 | `HaveNameEndingWith`, `BeSealed` conditions |
| `NetArchTest.Rules` | 1.4+ | `ResideInNamespace` with wildcards; `ImplementInterface` |
| `ArchUnitNET` | 0.x+ | Alternative with more complex dependency graph analysis |

---

## The Code

```csharp
// Setup
// dotnet add package NetArchTest.Rules
// (in a dedicated architecture test project, or alongside integration tests)
```

```csharp
// 1. Domain layer has no dependencies on Infrastructure or Application
[Fact]
public void Domain_ShouldNot_DependOnInfrastructure()
{
    var result = Types
        .InAssembly(typeof(Order).Assembly)          // Domain assembly
        .That()
        .ResideInNamespace("MyApp.Domain")
        .ShouldNot()
        .HaveDependencyOn("MyApp.Infrastructure")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(
        because: $"Domain must not reference Infrastructure. Violations: " +
                 string.Join(", ", result.FailingTypes?.Select(t => t.Name) ?? Array.Empty<string>()));
}

[Fact]
public void Domain_ShouldNot_DependOnApplication()
{
    var result = Types
        .InAssembly(typeof(Order).Assembly)
        .That()
        .ResideInNamespace("MyApp.Domain")
        .ShouldNot()
        .HaveDependencyOn("MyApp.Application")
        .GetResult();

    result.IsSuccessful.Should().BeTrue();
}
```

```csharp
// 2. Application layer has no direct EF Core dependency
[Fact]
public void Application_ShouldNot_ReferenceEntityFramework()
{
    var result = Types
        .InAssembly(typeof(CreateOrderCommand).Assembly)   // Application assembly
        .That()
        .ResideInNamespace("MyApp.Application")
        .ShouldNot()
        .HaveDependencyOn("Microsoft.EntityFrameworkCore")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(
        because: "Application layer should depend on repository interfaces, not EF Core directly");
}
```

```csharp
// 3. Naming convention enforcement
[Fact]
public void Controllers_ShouldBeNamed_WithControllerSuffix()
{
    var result = Types
        .InAssembly(typeof(Program).Assembly)
        .That()
        .Inherit(typeof(ControllerBase))
        .Should()
        .HaveNameEndingWith("Controller")
        .GetResult();

    result.IsSuccessful.Should().BeTrue();
}

[Fact]
public void Repositories_ShouldImplement_IRepository()
{
    var result = Types
        .InAssembly(typeof(OrderRepository).Assembly)
        .That()
        .HaveNameEndingWith("Repository")
        .Should()
        .ImplementInterface(typeof(IRepository<>))
        .GetResult();

    result.IsSuccessful.Should().BeTrue();
}

[Fact]
public void DomainEvents_ShouldResideIn_DomainEventsNamespace()
{
    var result = Types
        .InAssembly(typeof(Order).Assembly)
        .That()
        .ImplementInterface(typeof(IDomainEvent))
        .Should()
        .ResideInNamespace("MyApp.Domain.Events")
        .GetResult();

    result.IsSuccessful.Should().BeTrue();
}
```

```csharp
// 4. Handlers should be sealed (common DDD convention)
[Fact]
public void CommandHandlers_Should_BeSealed()
{
    var result = Types
        .InAssembly(typeof(CreateOrderCommandHandler).Assembly)
        .That()
        .HaveNameEndingWith("Handler")
        .Should()
        .BeSealed()
        .GetResult();

    result.IsSuccessful.Should().BeTrue(
        because: "Handlers are not designed for inheritance; seal them to signal intent");
}
```

```csharp
// 5. Infrastructure types must not leak into API layer
[Fact]
public void Api_ShouldNot_DirectlyReference_Infrastructure()
{
    var result = Types
        .InAssembly(typeof(Program).Assembly)        // API/presentation assembly
        .That()
        .ResideInNamespace("MyApp.Api")
        .ShouldNot()
        .HaveDependencyOn("MyApp.Infrastructure")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(
        because: "API controllers should use Application layer; never Infrastructure directly");
}
```

```csharp
// 6. Failure message helper — shows which types are violating
// NetArchTest's default failure message lists type names but not namespaces.
// This helper makes failures actionable immediately.

private static void AssertArchRule(TestResult result, string because)
{
    var violators = result.FailingTypes?
        .Select(t => t.FullName)
        .OrderBy(n => n)
        .ToList() ?? new List<string>();

    result.IsSuccessful.Should().BeTrue(
        because: $"{because}. Violating types:\n{string.Join("\n", violators)}");
}

// Usage
[Fact]
public void Domain_ShouldNot_DependOnApplication()
{
    var result = Types
        .InAssembly(typeof(Order).Assembly)
        .That().ResideInNamespace("MyApp.Domain")
        .ShouldNot().HaveDependencyOn("MyApp.Application")
        .GetResult();

    AssertArchRule(result, "Domain layer must be independent of Application");
}
```

---

## Real World Example

A team implementing Clean Architecture has four assemblies: `MyApp.Domain`, `MyApp.Application`, `MyApp.Infrastructure`, and `MyApp.Api`. The dependency rule is strict: Domain knows nothing, Application knows only Domain, Infrastructure knows Domain and Application, Api knows only Application. A junior developer inadvertently added an EF Core `DbContext` reference in a CQRS handler to "make something work quickly." The architecture tests caught it in CI before code review.

```csharp
public class CleanArchitectureTests
{
    private static readonly Assembly DomainAssembly          = typeof(Order).Assembly;
    private static readonly Assembly ApplicationAssembly     = typeof(CreateOrderCommand).Assembly;
    private static readonly Assembly InfrastructureAssembly  = typeof(AppDbContext).Assembly;
    private static readonly Assembly ApiAssembly             = typeof(Program).Assembly;

    [Fact]
    public void Domain_HasNoDependencies_OnOuterLayers()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(
                "MyApp.Application",
                "MyApp.Infrastructure",
                "MyApp.Api",
                "Microsoft.EntityFrameworkCore")
            .GetResult();

        AssertArchRule(result, "Domain is the innermost layer — it knows nothing");
    }

    [Fact]
    public void Application_DependsOnly_OnDomain()
    {
        var result = Types.InAssembly(ApplicationAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(
                "MyApp.Infrastructure",
                "MyApp.Api",
                "Microsoft.EntityFrameworkCore")
            .GetResult();

        AssertArchRule(result, "Application must not reference Infrastructure or EF Core");
    }

    [Fact]
    public void Api_DependsOnly_OnApplication()
    {
        var result = Types.InAssembly(ApiAssembly)
            .ShouldNot()
            .HaveDependencyOn("MyApp.Infrastructure")
            .GetResult();

        AssertArchRule(result, "API layer must go through Application, not Infrastructure directly");
    }

    [Fact]
    public void AllPublicInterfaces_InApplication_HaveIPrefix()
    {
        var result = Types.InAssembly(ApplicationAssembly)
            .That()
            .ArePublic()
            .And()
            .AreInterfaces()
            .Should()
            .HaveNameStartingWith("I")
            .GetResult();

        AssertArchRule(result, "All public interfaces must follow the I-prefix convention");
    }

    [Fact]
    public void DomainEvents_AreImmutableRecords()
    {
        // All types implementing IDomainEvent should be records (immutable by default)
        var domainEventTypes = DomainAssembly
            .GetTypes()
            .Where(t => typeof(IDomainEvent).IsAssignableFrom(t) && !t.IsInterface)
            .ToList();

        domainEventTypes.Should().NotBeEmpty();

        foreach (var type in domainEventTypes)
        {
            // Records generate a Clone method — use as a proxy for "is record"
            type.GetMethod("<Clone>$").Should().NotBeNull(
                because: $"{type.Name} implements IDomainEvent and must be a record");
        }
    }

    private static void AssertArchRule(TestResult result, string because)
    {
        var violators = result.FailingTypes?
            .Select(t => t.FullName).OrderBy(n => n).ToList()
            ?? new List<string>();

        result.IsSuccessful.Should().BeTrue(
            because: $"{because}. Violating types:\n{string.Join("\n", violators)}");
    }
}
```

*The `DomainEvents_AreImmutableRecords` test uses reflection directly because `NetArchTest.Rules` doesn't have a built-in "is a record" predicate. When the library doesn't have a predicate for what you need, dropping into reflection with a LINQ query and a FluentAssertions assertion is the right fallback.*

---

## Common Misconceptions

**"Architecture tests replace code review."**
They catch structural rule violations — wrong dependencies, naming convention breaks — automatically. They don't catch logic errors, design problems, missing abstractions, or unclear naming. They're a complement to code review that handles the mechanical, rules-based checks so reviewers can focus on higher-order concerns.

**"These tests are too strict — they'll block valid exceptions to the rule."**
`NetArchTest` supports `.That().DoNotResideInNamespace("MyApp.Domain.Exceptions")` to exclude specific namespaces from a rule. Most "valid exceptions" indicate the rule is poorly defined, not that exceptions should be carved out. If Infrastructure needs to be referenced in one place in Application, that one place probably belongs in a different layer.

**"Architecture tests only work for Clean Architecture."**
Any layering convention with explicit dependency rules benefits from them: vertical slice architecture (no slice touches another slice's internals), CQRS (commands don't return data, queries don't modify state), plugin architecture (core has no plugin dependencies). The library checks any rule that can be expressed as "types matching predicate X must/must not have dependency on namespace Y."

---

## Gotchas

- **`HaveDependencyOn` checks transitive dependencies.** If `Application` depends on `SharedKernel` and `SharedKernel` depends on `Infrastructure`, the test `Application.ShouldNot.HaveDependencyOn("Infrastructure")` will fail due to the transitive reference. You need to clean up the full dependency chain, not just the direct one.

- **Tests reflect the *compiled* assembly — they don't catch unreferenced code.** If you have a reference in a namespace that's never compiled into the release build (e.g. `#if DEBUG` wrapped code), the architecture test won't see it.

- **NetArchTest uses full namespace matching by default** — `HaveDependencyOn("MyApp.Infrastructure")` matches `MyApp.Infrastructure.Data`, `MyApp.Infrastructure.Messaging`, etc. Be deliberate about namespace prefix matching vs exact matching.

- **Architecture tests should run fast — they're reflection-based, not I/O-based.** A full suite of 20 architecture rules typically completes in under 2 seconds. If they're slow, you're doing something expensive in the predicate expressions.

- **The error message from `result.IsSuccessful.Should().BeTrue()` without the violators list is useless.** Always extract `result.FailingTypes` and include them in the assertion message, otherwise CI failures require a local repro to understand.

---

## Interview Angle

**What they're really testing:** Whether you think about enforcing architectural rules systematically rather than relying on code review and documentation.

**Common question forms:**
- *"How do you enforce Clean Architecture rules in a large team?"*
- *"What happens when a developer accidentally adds an EF Core reference in the Application layer?"*

**The depth signal:** A junior says "we rely on code review." A senior knows `NetArchTest.Rules` exists, can write a `HaveDependencyOn` rule, knows that transitive dependencies are checked (not just direct ones), and has a story about a real violation that an architecture test caught before it reached production.

---

## Related Topics

- [[dotnet/pattern/solid-principles.md]] — Architecture tests enforce the D in SOLID at a structural level — the dependency rule is the Dependency Inversion Principle made executable.
- [[dotnet/pattern/pattern-cqrs.md]] — CQRS conventions (no commands return data, no queries modify state) are enforceable via naming convention tests.
- [[dotnet/testing/testing-unit-tests.md]] — Architecture tests are a form of structural test; they run with the unit test suite but verify structure, not behavior.
- [[dotnet/webapi/dependency-injection.md]] — Correct DI registration is part of the architecture; architecture tests verify the types; integration tests verify the DI wiring.

---

## Source

https://github.com/BenMorris/NetArchTest

---
*Last updated: 2026-04-12*