# Domain 6 — Design Principles & Patterns

## Phonebook

**43 topics across 7 groups.** Priority 1 = Critical → Priority 4 = Reference `[ ]` = not yet generated | `[x]` = generated

---

## How to Use This File

1. Pick a topic by priority tier — generate Tier 1 topics before Tier 2, and so on.
2. Open `_main_design_patterns.md` to retrieve the generation spec.
3. Call: "Generate note 6.XXX — [Topic Name]"
4. Mark `[x]` when the note is saved to the vault.

---

## Group A — SOLID Principles

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.001|Single Responsibility Principle|1|[ ]|
|6.002|Open/Closed Principle|1|[ ]|
|6.003|Liskov Substitution Principle|1|[ ]|
|6.004|Interface Segregation Principle|2|[ ]|
|6.005|Dependency Inversion Principle|1|[ ]|

### Cross-References — Group A

- `[[6.001]]` → `[[6.002]]` → `[[6.003]]` — the SRP/OCP/LSP triad: SRP defines the boundary, OCP protects it, LSP enforces it in hierarchies
- `[[6.004]]` ↔ `[[6.001]]` — ISP is SRP applied at the interface level
- `[[6.005]]` ↔ `[[6.002]]` — DIP is what makes OCP achievable; you cannot have OCP without DIP
- `[[6.005]]` → `[[2.XXX — Generics and Interfaces]]` — DIP is expressed through C# interfaces and generic constraints
- `[[6.001]]` → `[[4.XXX — Dependency Injection]]` — ASP.NET Core's DI container enforces SRP by making single-purpose services easy to compose
- `[[6.003]]` → `[[6.029 — Strategy Pattern]]` — LSP is the correctness guarantee that makes Strategy substitution safe

---

## Group B — General Design Principles

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.006|DRY — Don't Repeat Yourself|2|[ ]|
|6.007|KISS — Keep It Simple|2|[ ]|
|6.008|YAGNI — You Aren't Gonna Need It|2|[ ]|
|6.009|Composition Over Inheritance|1|[ ]|
|6.010|Principle of Least Surprise|3|[ ]|
|6.011|Fail Fast|2|[ ]|

### Cross-References — Group B

- `[[6.006]]` ↔ `[[6.008]]` — DRY and YAGNI are in tension: DRY says don't repeat; YAGNI says don't abstract speculatively
- `[[6.007]]` ↔ `[[6.008]]` — KISS and YAGNI reinforce each other; both argue against accidental complexity
- `[[6.009]]` → `[[6.024 — Decorator Pattern]]` — Decorator is composition in pattern form
- `[[6.009]]` → `[[6.029 — Strategy Pattern]]` — Strategy composes behaviour; inheritance bakes it in
- `[[6.009]]` → `[[2.XXX — Interfaces and Polymorphism]]` — C# interfaces are the mechanism; composition is the principle
- `[[6.011]]` → `[[6.015 — Error Handling and the Result Pattern]]` — Fail Fast is implemented via guard clauses, exceptions at boundaries, and the Result pattern
- `[[6.011]]` → `[[4.XXX — Middleware Pipeline]]` — ASP.NET Core validation middleware is Fail Fast at the HTTP boundary

---

## Group C — Clean Code

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.012|Naming — Intention-Revealing Names|2|[ ]|
|6.013|Functions — Single Level of Abstraction|2|[ ]|
|6.014|Comments — Why Not What|3|[ ]|
|6.015|Error Handling — Exceptions vs Return Values and the Result Pattern|2|[ ]|
|6.016|Code Formatting and Consistency|3|[ ]|
|6.017|Boundaries — Wrapping Third-Party Code|2|[ ]|

### Cross-References — Group C

- `[[6.012]]` → `[[6.013]]` — good names and single-level functions are complementary; one without the other degrades quickly
- `[[6.013]]` ↔ `[[6.001 — Single Responsibility Principle]]` — SRP at the class level; SLAP at the function level
- `[[6.015]]` → `[[2.XXX — Exceptions and Error Handling]]` — C# exception mechanics underpin this topic
- `[[6.015]]` → `[[6.011 — Fail Fast]]` — Fail Fast determines where to place the error; Result pattern determines how to communicate it
- `[[6.017]]` → `[[6.023 — Adapter Pattern]]` — wrapping third-party code is the Adapter pattern in practice
- `[[6.017]]` → `[[6.025 — Facade Pattern]]` — Facade is the structural pattern for simplifying a complex third-party boundary
- `[[6.017]]` → `[[4.XXX — IHttpClientFactory]]` — wrapping HttpClient is the canonical .NET boundary example

---

## Group D — Creational Patterns

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.018|Singleton Pattern|1|[ ]|
|6.019|Factory Method Pattern|1|[ ]|
|6.020|Abstract Factory Pattern|2|[ ]|
|6.021|Builder Pattern|2|[ ]|
|6.022|Prototype Pattern|3|[ ]|

### Cross-References — Group D

- `[[6.018]]` → `[[4.XXX — Dependency Injection — Service Lifetimes]]` — Singleton in DI is the container-managed version of this pattern; the note must contrast the two
- `[[6.018]]` → `[[2.XXX — Thread Safety and Lazy<T>]]` — `Lazy<T>` is the idiomatic .NET Singleton implementation
- `[[6.019]]` ↔ `[[6.020]]` — Factory Method creates one product; Abstract Factory creates families; the comparison is mandatory in Section 7
- `[[6.019]]` → `[[6.005 — Dependency Inversion Principle]]` — Factory Method is how you defer construction while depending on abstractions
- `[[6.020]]` → `[[6.029 — Strategy Pattern]]` — Abstract Factory selects families of objects; Strategy selects algorithms; often confused
- `[[6.021]]` → `[[2.XXX — Fluent Interfaces and Method Chaining]]` — Fluent Builder is idiomatic in C# (StringBuilder, EF Core model builder)
- `[[6.021]]` → `[[4.XXX — WebApplication Builder and IHostBuilder]]` — ASP.NET Core's host builder is the Builder pattern
- `[[6.022]]` → `[[2.XXX — Records and Value Semantics]]` — C# records with `with` expressions are modern Prototype; the note must address `ICloneable` and its limitations

---

## Group E — Structural Patterns

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.023|Adapter Pattern|2|[ ]|
|6.024|Decorator Pattern|1|[ ]|
|6.025|Facade Pattern|2|[ ]|
|6.026|Proxy Pattern|2|[ ]|
|6.027|Composite Pattern|3|[ ]|
|6.028|Flyweight Pattern|3|[ ]|

### Cross-References — Group E

- `[[6.023]]` ↔ `[[6.025]]` — Adapter makes an incompatible interface fit; Facade simplifies a complex one — frequently confused; comparison is mandatory
- `[[6.023]]` → `[[6.017 — Boundaries — Wrapping Third-Party Code]]` — the Adapter is how you implement the boundary rule in code
- `[[6.024]]` ↔ `[[6.026]]` — Decorator adds behaviour; Proxy controls access — same structural shape, different intent; comparison is mandatory
- `[[6.024]]` → `[[4.XXX — Middleware Pipeline]]` — ASP.NET Core middleware is a linear decorator chain; this connection must appear in Section 4
- `[[6.024]]` → `[[6.002 — Open/Closed Principle]]` — Decorator is the primary mechanism for extension without modification
- `[[6.026]]` → `[[4.XXX — Lazy Loading in EF Core]]` — EF Core's lazy-loading proxies are the Proxy pattern
- `[[6.026]]` → `[[2.XXX — DispatchProxy and Source Generators]]` — .NET reflection-based and compile-time proxy generation
- `[[6.027]]` → `[[6.034 — Iterator Pattern]]` — Composite structures require traversal; Iterator is how that traversal is abstracted
- `[[6.028]]` → `[[2.XXX — String Interning and Memory Management]]` — string interning is the CLR's built-in Flyweight

---

## Group F — Behavioral Patterns

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.029|Strategy Pattern|1|[ ]|
|6.030|Observer Pattern|1|[ ]|
|6.031|Command Pattern|2|[ ]|
|6.032|Chain of Responsibility Pattern|2|[ ]|
|6.033|Template Method Pattern|2|[ ]|
|6.034|Iterator Pattern|3|[ ]|
|6.035|Mediator Pattern|1|[ ]|
|6.036|State Pattern|2|[ ]|
|6.037|Visitor Pattern|3|[ ]|

### Cross-References — Group F

- `[[6.029]]` ↔ `[[6.036]]` — Strategy changes algorithm from outside; State changes behaviour from inside — the most common confusion in interviews; mandatory comparison
- `[[6.029]]` ↔ `[[6.033]]` — Strategy delegates the whole algorithm; Template Method delegates steps — structural difference must be explicit
- `[[6.029]]` → `[[6.002 — Open/Closed Principle]]` — Strategy is the idiomatic OCP implementation for algorithm variation
- `[[6.030]]` → `[[2.XXX — Events, Delegates, and IObservable]]` — C# `event`, `IObservable<T>`, and `IObserver<T>` are the native Observer mechanisms
- `[[6.030]]` ↔ `[[6.035]]` — Observer is peer-to-peer pub/sub; Mediator centralises it — the architectural tradeoff must be explicit
- `[[6.031]]` → `[[4.XXX — MediatR Commands and Handlers]]` — MediatR's `IRequest` / `IRequestHandler` is the Command pattern in the .NET ecosystem
- `[[6.031]]` → `[[6.036 — State Pattern]]` — Command + State enables undoable state machines
- `[[6.032]]` → `[[4.XXX — Middleware Pipeline]]` — ASP.NET Core middleware is Chain of Responsibility; this is the primary production .NET example
- `[[6.032]]` → `[[4.XXX — Action Filters and Result Filters]]` — ASP.NET Core filter pipeline is a second CoR example in the same framework
- `[[6.033]]` → `[[6.001 — Single Responsibility Principle]]` — Template Method partitions responsibility between the skeleton and the steps
- `[[6.034]]` → `[[2.XXX — IEnumerable<T> and yield return]]` — C# `IEnumerable<T>` + `yield return` is the language-level Iterator
- `[[6.035]]` → `[[4.XXX — MediatR Pipeline Behaviors]]` — MediatR is the standard .NET Mediator implementation; pipeline behaviors are its cross-cutting mechanism
- `[[6.035]]` ↔ `[[6.030]]` — see Observer cross-reference above
- `[[6.036]]` → `[[6.031 — Command Pattern]]` — see Command cross-reference above
- `[[6.037]]` → `[[6.027 — Composite Pattern]]` — Visitor is most useful when traversing Composite structures
- `[[6.037]]` → `[[2.XXX — Pattern Matching and Switch Expressions]]` — C# pattern matching is a language-native alternative to Visitor for closed type hierarchies

---

## Group G — Refactoring

|ID|Topic|Priority|Generated|
|---|---|---|---|
|6.038|Code Smell Catalog — Bloaters|2|[ ]|
|6.039|Code Smell Catalog — Couplers and OO Abusers|2|[ ]|
|6.040|Code Smell Catalog — Change Preventers and Dispensables|3|[ ]|
|6.041|Refactoring Techniques — Composing Methods|2|[ ]|
|6.042|Refactoring Techniques — Moving Features Between Objects|3|[ ]|
|6.043|Refactoring Techniques — Simplifying Conditionals|2|[ ]|

**Smell coverage per note:**

- `6.038` — Long Method, Large Class, Long Parameter List, Data Clumps, Primitive Obsession
- `6.039` — Feature Envy, Inappropriate Intimacy, Message Chains, Middle Man, Switch Statements, Temporary Field, Refused Bequest, Alternative Classes with Different Interfaces
- `6.040` — Divergent Change, Shotgun Surgery, Parallel Inheritance Hierarchies, Lazy Class, Speculative Generality, Dead Code, Data Class

**Technique coverage per note:**

- `6.041` — Extract Method, Extract Variable, Inline Method, Inline Temp, Replace Temp with Query, Decompose Conditional, Rename Method/Variable/Field, Replace Magic Number with Symbolic Constant
- `6.042` — Move Method, Move Field, Extract Class, Inline Class, Hide Delegate, Remove Middle Man, Introduce Parameter Object
- `6.043` — Replace Conditional with Polymorphism, Replace Type Code with Strategy/State, Introduce Null Object, Guard Clauses, Consolidate Conditional Expression

### Cross-References — Group G

- `[[6.038]]` → `[[6.001 — Single Responsibility Principle]]` — Large Class is SRP violated; the note must make this explicit
- `[[6.038]]` → `[[6.013 — Functions — Single Level of Abstraction]]` — Long Method is SLAP violated
- `[[6.039]]` → `[[6.001 — Single Responsibility Principle]]` — Feature Envy and Inappropriate Intimacy are SRP violations at the dependency level
- `[[6.039]]` → `[[6.029 — Strategy Pattern]]` — Switch Statements smell → Replace Conditional with Polymorphism → Strategy is the structural result
- `[[6.040]]` → `[[6.002 — Open/Closed Principle]]` — Shotgun Surgery and Divergent Change are OCP violations in symptom form
- `[[6.041]]` → `[[6.013 — Functions — Single Level of Abstraction]]` — Extract Method is how SLAP is achieved mechanically
- `[[6.042]]` → `[[6.004 — Interface Segregation Principle]]` — Extract Class and Move Method often result in smaller, more focused interfaces
- `[[6.043]]` → `[[6.029 — Strategy Pattern]]` — Replace Conditional with Polymorphism ends at Strategy; this is the refactoring path to the pattern
- `[[6.043]]` → `[[6.036 — State Pattern]]` — Replace Type Code with State ends at the State pattern
- `[[6.043]]` → `[[6.011 — Fail Fast]]` — Guard Clauses are Fail Fast applied inside a function body

---

## Generation Order by Priority

### Tier 1 — Critical (8 topics) — Generate First

| #   | ID    | Topic                           |
| --- | ----- | ------------------------------- |
| 1   | 6.001 | Single Responsibility Principle |
| 2   | 6.002 | Open/Closed Principle           |
| 3   | 6.003 | Liskov Substitution Principle   |
| 4   | 6.005 | Dependency Inversion Principle  |
| 5   | 6.009 | Composition Over Inheritance    |
| 6   | 6.018 | Singleton Pattern               |
| 7   | 6.019 | Factory Method Pattern          |
| 8   | 6.024 | Decorator Pattern               |
| 9   | 6.029 | Strategy Pattern                |
| 10  | 6.030 | Observer Pattern                |
| 11  | 6.035 | Mediator Pattern                |

### Tier 2 — High (19 topics) — Generate Second

|#|ID|Topic|
|---|---|---|
|1|6.004|Interface Segregation Principle|
|2|6.006|DRY — Don't Repeat Yourself|
|3|6.007|KISS — Keep It Simple|
|4|6.008|YAGNI — You Aren't Gonna Need It|
|5|6.011|Fail Fast|
|6|6.012|Naming — Intention-Revealing Names|
|7|6.013|Functions — Single Level of Abstraction|
|8|6.015|Error Handling — Exceptions vs Return Values and the Result Pattern|
|9|6.017|Boundaries — Wrapping Third-Party Code|
|10|6.020|Abstract Factory Pattern|
|11|6.021|Builder Pattern|
|12|6.023|Adapter Pattern|
|13|6.025|Facade Pattern|
|14|6.026|Proxy Pattern|
|15|6.031|Command Pattern|
|16|6.032|Chain of Responsibility Pattern|
|17|6.033|Template Method Pattern|
|18|6.036|State Pattern|
|19|6.038|Code Smell Catalog — Bloaters|
|20|6.039|Code Smell Catalog — Couplers and OO Abusers|
|21|6.041|Refactoring Techniques — Composing Methods|
|22|6.043|Refactoring Techniques — Simplifying Conditionals|

### Tier 3 — Medium (10 topics) — Generate Third

|#|ID|Topic|
|---|---|---|
|1|6.010|Principle of Least Surprise|
|2|6.014|Comments — Why Not What|
|3|6.016|Code Formatting and Consistency|
|4|6.022|Prototype Pattern|
|5|6.027|Composite Pattern|
|6|6.028|Flyweight Pattern|
|7|6.034|Iterator Pattern|
|8|6.037|Visitor Pattern|
|9|6.040|Code Smell Catalog — Change Preventers and Dispensables|
|10|6.042|Refactoring Techniques — Moving Features Between Objects|

---

## Full Topic Index (Alphabetical)

|ID|Topic|Group|Priority|
|---|---|---|---|
|6.023|Adapter Pattern|Structural Patterns|2|
|6.020|Abstract Factory Pattern|Creational Patterns|2|
|6.021|Builder Pattern|Creational Patterns|2|
|6.032|Chain of Responsibility Pattern|Behavioral Patterns|2|
|6.014|Comments — Why Not What|Clean Code|3|
|6.016|Code Formatting and Consistency|Clean Code|3|
|6.038|Code Smell Catalog — Bloaters|Refactoring|2|
|6.039|Code Smell Catalog — Couplers and OO Abusers|Refactoring|2|
|6.040|Code Smell Catalog — Change Preventers and Dispensables|Refactoring|3|
|6.031|Command Pattern|Behavioral Patterns|2|
|6.027|Composite Pattern|Structural Patterns|3|
|6.009|Composition Over Inheritance|General Principles|1|
|6.024|Decorator Pattern|Structural Patterns|1|
|6.005|Dependency Inversion Principle|SOLID Principles|1|
|6.006|DRY — Don't Repeat Yourself|General Principles|2|
|6.015|Error Handling — Exceptions vs Return Values and the Result Pattern|Clean Code|2|
|6.025|Facade Pattern|Structural Patterns|2|
|6.019|Factory Method Pattern|Creational Patterns|1|
|6.011|Fail Fast|General Principles|2|
|6.028|Flyweight Pattern|Structural Patterns|3|
|6.013|Functions — Single Level of Abstraction|Clean Code|2|
|6.004|Interface Segregation Principle|SOLID Principles|2|
|6.034|Iterator Pattern|Behavioral Patterns|3|
|6.007|KISS — Keep It Simple|General Principles|2|
|6.003|Liskov Substitution Principle|SOLID Principles|1|
|6.035|Mediator Pattern|Behavioral Patterns|1|
|6.012|Naming — Intention-Revealing Names|Clean Code|2|
|6.030|Observer Pattern|Behavioral Patterns|1|
|6.002|Open/Closed Principle|SOLID Principles|1|
|6.010|Principle of Least Surprise|General Principles|3|
|6.022|Prototype Pattern|Creational Patterns|3|
|6.026|Proxy Pattern|Structural Patterns|2|
|6.041|Refactoring Techniques — Composing Methods|Refactoring|2|
|6.042|Refactoring Techniques — Moving Features Between Objects|Refactoring|3|
|6.043|Refactoring Techniques — Simplifying Conditionals|Refactoring|2|
|6.017|Boundaries — Wrapping Third-Party Code|Clean Code|2|
|6.018|Singleton Pattern|Creational Patterns|1|
|6.001|Single Responsibility Principle|SOLID Principles|1|
|6.036|State Pattern|Behavioral Patterns|2|
|6.029|Strategy Pattern|Behavioral Patterns|1|
|6.033|Template Method Pattern|Behavioral Patterns|2|
|6.037|Visitor Pattern|Behavioral Patterns|3|
|6.008|YAGNI — You Aren't Gonna Need It|General Principles|2|

---

_Domain 6 — Design Principles & Patterns | 43 topics | 7 groups | Last updated: June 2026_ _Tags: #engineering #knowledge-base #design-principles #patterns #csharp #dotnet_