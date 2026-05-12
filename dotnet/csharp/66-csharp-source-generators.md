# C# Source Generators

> A Roslyn compiler extension that runs during compilation and adds new C# source files to your project — enabling zero-overhead, AOT-safe code generation based on your types, attributes, and syntax, without runtime reflection.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Compiler plugin that generates C# source code at build time |
| **Runs** | During compilation, before IL emission |
| **Output** | Additional `.cs` files added to the compilation |
| **Use when** | Eliminating reflection, generating boilerplate, AOT-compatible serialisation |
| **Two types** | `ISourceGenerator` (v1, deprecated) → `IIncrementalGenerator` (v2, current) |
| **C# version** | C# 9 / .NET 5 (v1), .NET 6+ (incremental, preferred) |
| **Namespace** | `Microsoft.CodeAnalysis` |

---

## When To Use It

Source generators are the right tool when:
- You're generating boilerplate that would otherwise require **runtime reflection** — and you want AOT compatibility or zero allocation at runtime
- You have a **repetitive pattern** across many types that can be driven by attributes or naming conventions
- You want **compile-time validation** of something that would otherwise fail at runtime

Common real-world uses: `System.Text.Json` serialisation (AOT-safe via `[JsonSerializable]`), `LoggerMessage.Define` patterns, EF Core compiled models, `INotifyPropertyChanged` boilerplate, mapping generators (Mapperly), DI registration, and gRPC client generation.

Don't use source generators for:
- Logic that needs runtime information (user config, database schema at runtime)
- Simple one-off code generation — a T4 template or a build script may be simpler
- Anything that doesn't need to run at every build (use a code-generation script instead)

---

## Core Concept

A source generator is a class that implements `IIncrementalGenerator`. The compiler calls it during every build. The generator receives a `IncrementalGeneratorInitializationContext` and registers **pipelines** — declarative descriptions of what to look at (syntax nodes, attributes, compilation symbols) and what to emit based on them.

The "incremental" in `IIncrementalGenerator` is critical: the generator only re-runs the pipeline steps whose inputs actually changed. If you add a file unrelated to the generator's concerns, only the changed parts rerun. This makes builds fast enough for real-time IDE use.

**The output is just C# source.** Generators emit strings — valid C# code — that the compiler then compiles alongside your hand-written code. There's no runtime magic. The generated code is visible in `obj/Generated/` and can be debugged normally.

**AOT safety:** Because generated code is compiled C# with no reflection at runtime, it's fully compatible with Native AOT, trimming, and Blazor WebAssembly. This is why `System.Text.Json`'s source generator exists — it replaces the reflection-based serialiser with generated serialisation code.

---

## Version History

| C# Version | .NET Version | What changed |
|---|---|---|
| C# 9.0 | .NET 5 | `ISourceGenerator` (v1) — runs on every keystroke, slow |
| .NET 6 | — | `IIncrementalGenerator` (v2) — incremental, caching, fast |
| .NET 7 | — | `IIncrementalGenerator` mature; v1 officially deprecated |
| .NET 8 | — | `InterceptorsPreviewNamespaces` (experimental interceptors) |

*Always use `IIncrementalGenerator`. The v1 `ISourceGenerator` interface is deprecated and causes IDE performance problems because it reruns on every keystroke.*

---

## The Code

**Minimal incremental source generator structure**
```csharp
// NuGet: Microsoft.CodeAnalysis.CSharp (in the generator project, not the main project)

using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

[Generator]
public class ToStringGenerator : IIncrementalGenerator
{
    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        // Step 1: Find all classes marked with [GenerateToString]
        IncrementalValuesProvider<ClassDeclarationSyntax> classDeclarations =
            context.SyntaxProvider
                .CreateSyntaxProvider(
                    predicate: static (node, _) =>
                        node is ClassDeclarationSyntax c &&
                        c.AttributeLists.Count > 0,
                    transform: static (ctx, _) =>
                        GetClassWithAttribute(ctx))
                .Where(static c => c is not null)!;

        // Step 2: Combine with the compilation for semantic info
        IncrementalValueProvider<(Compilation, ImmutableArray<ClassDeclarationSyntax>)> combined =
            context.CompilationProvider.Combine(classDeclarations.Collect());

        // Step 3: Register source output
        context.RegisterSourceOutput(combined, static (spc, source) =>
            Execute(source.Item1, source.Item2, spc));
    }

    private static ClassDeclarationSyntax? GetClassWithAttribute(GeneratorSyntaxContext ctx)
    {
        var classDecl = (ClassDeclarationSyntax)ctx.Node;
        foreach (var attrList in classDecl.AttributeLists)
            foreach (var attr in attrList.Attributes)
            {
                var symbol = ctx.SemanticModel.GetSymbolInfo(attr).Symbol;
                if (symbol?.ContainingType?.ToDisplayString() == "GenerateToStringAttribute")
                    return classDecl;
            }
        return null;
    }

    private static void Execute(
        Compilation compilation,
        ImmutableArray<ClassDeclarationSyntax> classes,
        SourceProductionContext context)
    {
        foreach (var classDecl in classes)
        {
            var semanticModel = compilation.GetSemanticModel(classDecl.SyntaxTree);
            var classSymbol   = semanticModel.GetDeclaredSymbol(classDecl)!;

            var source = GenerateToString(classSymbol);
            context.AddSource($"{classSymbol.Name}_ToString.g.cs", source);
        }
    }

    private static string GenerateToString(INamedTypeSymbol symbol)
    {
        var properties = symbol.GetMembers()
            .OfType<IPropertySymbol>()
            .Where(p => p.DeclaredAccessibility == Accessibility.Public);

        var propString = string.Join(", ",
            properties.Select(p => $"{p.Name} = {{{p.Name}}}"));

        return $"""
            namespace {symbol.ContainingNamespace};

            partial class {symbol.Name}
            {{
                public override string ToString() => $"{symbol.Name} {{ {propString} }}";
            }}
            """;
    }
}
```

**The attribute that triggers the generator**
```csharp
// This lives in the main project, not the generator project
[AttributeUsage(AttributeTargets.Class)]
public class GenerateToStringAttribute : Attribute { }

// The class must be partial — generators add to it
[GenerateToString]
public partial class Order
{
    public int    Id           { get; init; }
    public string CustomerName { get; init; } = "";
    public decimal Total       { get; init; }
}

// At runtime, no reflection — the generated ToString() is compiled C#:
var order = new Order { Id = 1, CustomerName = "Alice", Total = 99.99m };
Console.WriteLine(order); // "Order { Id = 1, CustomerName = Alice, Total = 99.99 }"
```

**Project setup — generator lives in a separate project**
```xml
<!-- Generator project: MyApp.Generators.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>  <!-- Must target netstandard2.0 -->
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <IsRoslynComponent>true</IsRoslynComponent>        <!-- Marks as a generator -->
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp" Version="4.9.2" PrivateAssets="all" />
  </ItemGroup>
</Project>

<!-- Main project: MyApp.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <!-- Reference the generator project as an Analyzer, not a regular reference -->
    <ProjectReference Include="..\MyApp.Generators\MyApp.Generators.csproj"
                      OutputItemType="Analyzer"
                      ReferenceOutputAssembly="false" />
  </ItemGroup>
</Project>
```

**`System.Text.Json` AOT-safe serialisation — generator you use, not write**
```csharp
// Declare a serialiser context — this triggers the built-in JSON source generator
[JsonSerializable(typeof(Order))]
[JsonSerializable(typeof(List<Order>))]
[JsonSerializable(typeof(CreateOrderRequest))]
public partial class AppJsonContext : JsonSerializerContext { }

// Use the generated context instead of reflection-based serialisation
string json    = JsonSerializer.Serialize(order, AppJsonContext.Default.Order);
Order? decoded = JsonSerializer.Deserialize(json, AppJsonContext.Default.Order);

// This compiles to: no reflection, no dynamic IL — fully AOT compatible
// Generated code lives in: obj/Debug/net8.0/generated/System.Text.Json.SourceGeneration/
```

**Logging source generator — `LoggerMessage.Define` without the boilerplate**
```csharp
// Using Microsoft.Extensions.Logging source generator
public partial class OrderService
{
    private readonly ILogger<OrderService> _logger;

    public OrderService(ILogger<OrderService> logger) => _logger = logger;

    // Generator creates a high-performance log method — no string allocation unless logged
    [LoggerMessage(Level = LogLevel.Information, Message = "Order {OrderId} created for {Customer}")]
    private partial void LogOrderCreated(int orderId, string customer);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Payment failed for order {OrderId}: {Reason}")]
    private partial void LogPaymentFailed(int orderId, string reason);

    public async Task<Order> CreateAsync(CreateOrderRequest req, CancellationToken ct)
    {
        var order = await _repository.SaveAsync(Order.From(req), ct);
        LogOrderCreated(order.Id, req.CustomerEmail); // zero alloc if INFO not enabled
        return order;
    }
}
```

---

## Real World Example

A mapping generator eliminates hand-written mapper classes. Annotating a partial class with `[GenerateMapper]` causes the generator to emit a complete `Map` method for each registered mapping, with compile-time validation that all target properties are covered.

```csharp
// Attribute in main project
[AttributeUsage(AttributeTargets.Class, AllowMultiple = true)]
public class MapFromAttribute<TSource> : Attribute { }

// Partial class — generator fills in the Map method
[MapFrom<OrderEntity>]
[MapFrom<CreateOrderRequest>]
public partial class OrderDto
{
    public int    Id           { get; init; }
    public string CustomerName { get; init; } = "";
    public decimal Total       { get; init; }
    public string StatusLabel  { get; init; } = "";
}

// -------- Generator produces (in obj/Generated/): --------

// OrderDto_MapFromOrderEntity.g.cs
public partial class OrderDto
{
    public static OrderDto From(OrderEntity source) => new()
    {
        Id           = source.Id,
        CustomerName = source.CustomerName,
        Total        = source.Total,
        StatusLabel  = source.Status.ToString()
    };
}

// OrderDto_MapFromCreateOrderRequest.g.cs
public partial class OrderDto
{
    public static OrderDto From(CreateOrderRequest source) => new()
    {
        Id           = 0,
        CustomerName = source.CustomerEmail,
        Total        = source.Items.Sum(i => i.Price * i.Quantity),
        StatusLabel  = "Pending"
    };
}

// Application code — no reflection, no dynamic dispatch, full AOT safety
var dto = OrderDto.From(entity);         // calls generated static method
var dto2 = OrderDto.From(createRequest); // calls other generated static method
```

*The key insight: the generated `From` methods are just compiled C# with property assignments. The IDE provides full IntelliSense on the generated code. A compile error appears immediately if `OrderEntity` gains a new property that `OrderDto` doesn't handle — missing mapping is caught at build time, not runtime.*

---

## Common Misconceptions

**"Source generators are like T4 templates"**
T4 templates run once and produce a static output file that you commit to source control. Source generators run on every build, have access to the full compilation (semantic model, type information, attributes), produce output in `obj/` not your source tree, and integrate with incremental compilation. They're fundamentally different tools.

**"Source generators replace reflection entirely"**
They replace reflection in the scenarios where the code to generate can be determined from the type system at compile time. Dynamic scenarios — plugin discovery, runtime-loaded assemblies, user-provided types — still need reflection. The right way to think about it: if you can describe what code to generate using types and attributes visible at compile time, a generator can do it. If you need runtime information, you still need reflection.

**"Generated code is slow to compile"**
Incremental generators cache their output and only rerun when relevant inputs change. In a well-written incremental generator, most keystrokes cause zero generator work. The design of the incremental pipeline (using `Where`, `Collect`, `Combine` to filter early) directly controls how much work reruns.

---

## Gotchas

- **Generator projects must target `netstandard2.0`.** They run inside the Roslyn compiler process, which hosts a `netstandard2.0` environment. Targeting `net8.0` causes the generator to silently not load in some build environments.

- **Generated classes must use `partial` on the user-defined side.** Generators add to existing types by generating additional `partial` class declarations. The user-written class must be `partial`. A non-partial class cannot be extended by a generator — the generator emits a new file that won't compile.

- **Diagnostics from generators appear as build errors.** Use `context.ReportDiagnostic(Diagnostic.Create(...))` to surface user-visible errors (e.g., "this attribute requires a partial class"). Don't throw exceptions from generators — they cause cryptic build failures.

- **Don't read files or make network calls in generators.** Generators run inside the IDE process on every keystroke. Any I/O causes IDE hangs and build slowdowns. Only use the Roslyn APIs (`SemanticModel`, `SyntaxTree`, `Compilation`) — they're all in-memory.

- **The generated code lives in `obj/` and should not be committed.** Add `obj/` to `.gitignore`. Some teams inspect the generated output during code review by looking at the `obj/Debug/net8.0/generated/` folder.

---

## Interview Angle

**What they're really testing:** Whether you understand what problem source generators solve (reflection replacement, AOT safety, compile-time correctness) and when they're appropriate vs overkill.

**Common question forms:**
- "What are source generators in .NET?"
- "How does `System.Text.Json`'s AOT-safe mode work?"
- "What's the difference between a source generator and reflection?"
- "When would you write a source generator vs use reflection?"

**The depth signal:** A junior says "source generators generate code at compile time." A senior explains the AOT angle — reflection is incompatible with Native AOT and trimming because the linker can't know what types will be accessed at runtime, so it can't trim them. Source generators produce concrete compiled code that the linker can analyse. They know `IIncrementalGenerator` is the correct interface (not the deprecated v1), explain why the incremental design matters for IDE performance, and can articulate the partial class requirement and why generator output goes in `obj/` not the source tree.

---

## Related Topics

- [csharp-reflection.md](csharp-reflection.md) — The runtime alternative; source generators replace reflection for scenarios knowable at compile time
- [csharp-attributes.md](csharp-attributes.md) — The primary mechanism generators use to identify which types to process
- [csharp-partial-classes.md](csharp-partial-classes.md) — Generated code extends user types via `partial`; understanding partial is a prerequisite

---

## Source

[Source Generators — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/source-generators-overview)

---
*Last updated: 2026-05-13*
