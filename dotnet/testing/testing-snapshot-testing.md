# Snapshot Testing in .NET

> Snapshot testing asserts that a complex output — a JSON response, a rendered string, a serialised object — matches a previously approved stored copy, instead of manually asserting every field.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Assert complex output matches a stored approved snapshot file |
| **Use when** | Asserting on large JSON responses, serialised objects, generated text |
| **Avoid when** | Simple outputs with 1–3 fields — write explicit assertions instead |
| **Key library** | `Verify` (by Simon Cropp) — most popular .NET snapshot library |
| **Key package** | `Verify.Xunit` |
| **Workflow** | First run creates snapshot → review → approve → subsequent runs compare |

---

## When To Use It
Use snapshot testing when asserting on the full shape of a complex output: an API response with 20+ fields, a serialised event payload, a rendered email template, or a generated report. Snapshot tests catch unintended changes — you approve the first output, and any future deviation fails the test. Avoid it for simple outputs where explicit `BeEquivalentTo` assertions are more precise and readable. The cost is a review step every time the output legitimately changes — snapshots need to be re-approved deliberately, which is a feature, not a bug.

---

## Core Concept
On the first run, `Verify` calls the `Verifier.Verify()` method, which serialises the object to a `.verified.txt` or `.verified.json` file and throws — the test fails. You inspect the file, decide it looks correct, rename it from `.received` to `.verified` (or run `dotnet verify accept`), and commit it. On subsequent runs, `Verify` serialises the object again and diffs it against the committed `.verified` file. If they match, the test passes. If they differ, the test fails with a diff showing exactly what changed.

This inverts the normal assertion flow: instead of writing "I expect field X to be Y," you say "I approve this entire output." The power is in catching *unexpected* changes — a new field added to a response, a renamed property, a format change in a date — that `BeEquivalentTo` wouldn't catch because it doesn't know what fields the output shouldn't have.

---

## Version History

| Package | Version | What changed |
|---|---|---|
| `Verify` | 1.x | Core library, text-based snapshot files |
| `Verify.Xunit` | 2.x | xUnit integration; `[UsesVerify]` attribute |
| `Verify` | 12.x+ | `VerifyJson`, `VerifyHttp` for typed HTTP response assertions |
| `Verify` | 19.x+ | Auto-accept on first run option; scrubbers API stabilised |
| `Verify.Http` | — | Extension for `HttpResponseMessage` snapshots in integration tests |

---

## Performance

| Scenario | Cost | Notes |
|---|---|---|
| First run (no snapshot) | Fails immediately | Creates `.received` file; must be approved |
| Subsequent run (match) | < 5ms | File read + string diff |
| Subsequent run (mismatch) | Fails with diff | Shows received vs verified side by side |
| Scrubbing (dates, GUIDs) | < 1ms | Regex replacements before comparison |

---

## The Code

```csharp
// Setup
// dotnet add package Verify.Xunit
// dotnet add package Verify.Http    ← for HttpResponseMessage snapshots
```

```csharp
// 1. Basic snapshot — assert on a complex object
[UsesVerify]
public class OrderSnapshotTests
{
    [Fact]
    public async Task GetOrder_ReturnsExpectedShape()
    {
        var order = new OrderDto
        {
            Id         = 1,
            CustomerId = "cust-001",
            Total      = 150m,
            Status     = "Pending",
            Items      = new[]
            {
                new OrderItemDto { ProductId = "prod-1", Quantity = 2, UnitPrice = 75m }
            },
            CreatedAt  = new DateTime(2026, 1, 15, 12, 0, 0, DateTimeKind.Utc)
        };

        // First run: creates OrderSnapshotTests.GetOrder_ReturnsExpectedShape.received.txt
        // After approval: compares against .verified.txt on every subsequent run
        await Verify(order);
    }
}
```

```csharp
// 2. Scrubbing non-deterministic values — GUIDs, timestamps, generated IDs
[Fact]
public async Task PlaceOrder_ResponseContainsExpectedFields()
{
    var order = await _sut.PlaceOrderAsync(new CreateOrderDto { Total = 100m });

    await Verify(order)
        .ScrubMember(o => o.Id)           // generated ID — replace with placeholder
        .ScrubMember(o => o.CreatedAt);   // timestamp — replace with placeholder
}

// Snapshot file will contain:
// {
//   Id: "Id_1",         ← scrubbed
//   Total: 100.0,
//   Status: "Pending",
//   CreatedAt: "DateTime_1"  ← scrubbed
// }
```

```csharp
// 3. Integration test — snapshot on full HTTP response
[UsesVerify]
public class OrdersApiSnapshotTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;

    public OrdersApiSnapshotTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetOrders_ReturnsExpectedResponseShape()
    {
        var response = await _client.GetAsync("/api/orders");

        await Verify(response)
            .ScrubMember("date")          // scrub Date header
            .ScrubMember("x-request-id"); // scrub request ID header
    }
}
```

```csharp
// 4. Global scrubber settings — apply across all tests in the project
// In a test project's AssemblyInitializer or static constructor:

[UsesVerify]
public static class VerifyConfig
{
    [ModuleInitializer]
    public static void Init()
    {
        // Scrub all GUIDs globally — replaced with "Guid_1", "Guid_2" etc.
        VerifierSettings.ScrubInlineGuids();

        // Scrub all DateTimes globally
        VerifierSettings.ScrubMembersWithType<DateTime>();
        VerifierSettings.ScrubMembersWithType<DateTimeOffset>();

        // Custom scrubber — replace all email addresses
        VerifierSettings.AddScrubber(s =>
            Regex.Replace(s, @"[\w.]+@[\w.]+\.\w+", "email@example.com"));
    }
}
```

```csharp
// 5. Parametrised snapshot tests — each InlineData gets its own snapshot file
[UsesVerify]
public class DiscountSnapshotTests
{
    [Theory]
    [InlineData("standard", 100)]
    [InlineData("gold",     200)]
    [InlineData("platinum", 300)]
    public async Task CalculateDiscount_ByTier_MatchesSnapshot(string tier, decimal total)
    {
        var result = new DiscountCalculator().Calculate(tier, total);

        // Creates separate snapshot files per parameter combination:
        // DiscountSnapshotTests.CalculateDiscount_ByTier_MatchesSnapshot_tier=standard_total=100.verified.txt
        await Verify(result)
            .UseParameters(tier, total);
    }
}
```

```csharp
// 6. What NOT to do

// BAD: snapshot testing trivial outputs — use explicit assertions instead
[Fact]
public async Task BAD_GetStatus_SnapshotsTrivialValue()
{
    var result = _sut.GetStatus();
    await Verify(result);   // ← if result is just "Active", BeEquivalentTo is cleaner
}

// GOOD: use snapshots for genuinely complex outputs
[Fact]
public async Task GOOD_GetOrderHistory_SnapshotsComplexReport()
{
    var history = await _sut.GetOrderHistoryAsync("cust-001");
    // 15+ fields, nested objects, collection of line items — snapshot is appropriate
    await Verify(history).ScrubMembersWithType<DateTime>();
}
```

---

## Real World Example

A reporting service generates monthly invoice summaries — a complex nested structure with invoice lines, tax breakdowns, applied discounts, and totals. The shape is stable but a junior developer occasionally changes field names or adds unintentional properties when refactoring. Snapshot tests catch these breaks immediately without maintaining 40+ explicit assertions per test.

```csharp
[UsesVerify]
public class InvoiceSummarySnapshotTests : IClassFixture<ApiFactory>
{
    private readonly InvoiceSummaryService _sut;

    public InvoiceSummarySnapshotTests(ApiFactory factory)
    {
        var scope = factory.Services.CreateScope();
        _sut = scope.ServiceProvider.GetRequiredService<InvoiceSummaryService>();
    }

    [Fact]
    public async Task GenerateSummary_StandardInvoice_MatchesSnapshot()
    {
        var invoice = new InvoiceBuilder()
            .WithCustomer("cust-001", "Acme Corp")
            .WithLine("Software License", quantity: 1, unitPrice: 500m)
            .WithLine("Support Package", quantity: 12, unitPrice: 50m)
            .WithTaxRate(0.20m)
            .Build();

        var summary = await _sut.GenerateAsync(invoice);

        await Verify(summary)
            .ScrubMember(s => s.GeneratedAt)     // timestamp — non-deterministic
            .ScrubMember(s => s.InvoiceId);      // GUID — non-deterministic
    }
}

// Approved snapshot file (committed to source control):
// InvoiceSummarySnapshotTests.GenerateSummary_StandardInvoice_MatchesSnapshot.verified.json
// {
//   InvoiceId: "Guid_1",
//   Customer: { Id: "cust-001", Name: "Acme Corp" },
//   Lines: [
//     { Description: "Software License", Quantity: 1, UnitPrice: 500.0, LineTotal: 500.0 },
//     { Description: "Support Package", Quantity: 12, UnitPrice: 50.0, LineTotal: 600.0 }
//   ],
//   Subtotal: 1100.0,
//   TaxAmount: 220.0,
//   Total: 1320.0,
//   GeneratedAt: "DateTime_1"
// }
```

*When the tax rounding logic is changed, this test fails with a diff showing the old and new `TaxAmount` side by side. The developer reviews the diff, decides whether the change is intentional, and either fixes the bug or re-approves the snapshot. This makes the test a safety net for the output contract, not just for individual field values.*

---

## Common Misconceptions

**"Snapshot tests are fragile — any change breaks them."**
That's the point. Changes to complex outputs should be reviewed deliberately. The workflow is: change fails the snapshot → diff is reviewed → if intentional, re-approve and commit the new snapshot → if accidental, fix the code. The review step is the value, not the friction.

**"I need to write the snapshot manually before running the test."**
Verify creates the snapshot automatically on the first run. The first run fails (by design) and creates a `.received` file. You review it, approve it (rename to `.verified`), and commit. Subsequent runs compare against the committed version.

**"Scrubbing means the snapshot doesn't test those fields."**
Scrubbed fields are replaced with stable placeholders (`Guid_1`, `DateTime_1`) in the snapshot. The snapshot still asserts that those fields *exist* and have the correct *type* — it just doesn't assert on their specific value, because that value is non-deterministic.

---

## Gotchas

- **`.received` files must not be committed to source control.** Add `*.received.*` to `.gitignore`. Only `.verified.*` files are committed. Committing `.received` files confuses the diff on the next run.

- **Snapshot files are per-test-method.** If you rename a test, the old `.verified` file becomes orphaned and the test creates a new `.received` file on next run. Always rename both the test and the snapshot file together.

- **Parametrised tests need `UseParameters()`** to generate distinct snapshot file names. Without it, all `[InlineData]` runs write to the same file and the last one wins — most of them appear to pass while only the last data set is actually verified.

- **Global scrubbers apply to everything — including field names.** If you `ScrubInlineGuids()` globally and a field's *name* contains a GUID pattern, the field name gets scrubbed too. Be specific about what you scrub.

- **The first CI run will always fail if snapshots aren't committed.** Ensure `.verified` snapshot files are committed to source control as part of the PR that introduces the test. Running `dotnet verify accept` locally creates them; commit them before pushing.

---

## Interview Angle

**What they're really testing:** Whether you know tools beyond FluentAssertions for complex output validation, and whether you understand when a snapshot is appropriate vs when explicit assertions are cleaner.

**Common question forms:**
- *"How do you test a complex API response with 20+ fields?"*
- *"Have you used snapshot testing? When would you reach for it?"*

**The depth signal:** A junior says "use `BeEquivalentTo` for everything." A senior knows snapshot testing exists, can articulate when it's appropriate (complex outputs where the whole shape matters), knows the approve/re-approve workflow, understands scrubbing for non-deterministic values, and can explain the tradeoff: snapshots catch unexpected shape changes but require a deliberate review step every time output legitimately changes.

---

## Related Topics

- [[dotnet/testing/testing-fluentassertions.md]] — `BeEquivalentTo` is the right tool for explicit field-level assertions; snapshots are the right tool for whole-output contract testing.
- [[dotnet/testing/testing-integration-tests.md]] — Snapshots are most valuable in integration tests where the response body is complex.
- [[dotnet/testing/testing-unit-tests.md]] — For unit tests with simple outputs, explicit assertions beat snapshots every time.

---

## Source

https://github.com/VerifyTests/Verify

---
*Last updated: 2026-04-12*