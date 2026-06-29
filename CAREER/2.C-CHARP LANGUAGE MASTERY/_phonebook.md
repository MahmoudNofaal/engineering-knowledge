# C# LANGUAGE MASTERY — COMPLETE TOPIC INDEX (v2)

> **Purpose:** Master list of every topic in the C# Language Mastery domain — from absolute beginner foundations through expert internals. Use to track progress, pick the next topic, and copy `RELATED_TOPICS` directly into the generation prompt.

---

## ⚠️ RESTRUCTURE NOTICE — v2 Full Redesign

> The original 30-topic phonebook has been replaced with a complete 54-topic curriculum. Topics are now numbered in **learning order** from beginner to advanced:
> 
> |Range|Level|Audience|
> |---|---|---|
> |2.01–2.15|Level 1 — Foundations|Beginner|
> |2.16–2.32|Level 2 — Core Language|Intermediate|
> |2.33–2.46|Level 3 — Language Depth|Intermediate-to-Advanced|
> |2.47–2.54|Level 4 — Advanced & Specialist|Advanced|
> 
> **Migration for the already-generated note:** The old `2.01 — Value Types vs Reference Types` maps to **new `2.16`**. Rename the file to `2.16.Value Types vs Reference Types.md` and change `topic_id: "2.01"` → `topic_id: "2.16"` in its YAML frontmatter. Update any `[[2.01 ...]]` wiki links in other notes to `[[2.16 ...]]`.

studied_well: false
---

## PROGRESS TRACKER

```
Total Topics:  54
Generated:      1  (old 2.01 → new 2.16 ✅)
Remaining:     53
```

**Status Legend**

- ✅ Complete — note generated and reviewed
- 🔄 In Progress — currently being written
- ⬜ Not Started — queued

---

## LEVEL GUIDE

```
LEVEL 1 — FOUNDATIONS     (2.01–2.15)   Beginner
  The absolute building blocks every C# developer must know cold.
  Every Level 2+ note assumes these without explanation.
  Skip individual topics you already know with complete confidence.

LEVEL 2 — CORE LANGUAGE   (2.16–2.32)   Intermediate
  The daily vocabulary of production C# and the primary interview target
  for engineers with 1–3 years of experience preparing for senior roles.

LEVEL 3 — LANGUAGE DEPTH  (2.33–2.46)   Intermediate-to-Advanced
  Runtime internals, memory behavior, and the mechanics that separate
  engineers who write correct code from those who also write fast code.

LEVEL 4 — ADVANCED        (2.47–2.54)   Advanced / Specialist
  Senior and principal-level topics. High-performance systems, tooling,
  AOT deployment, and deep JIT/GC knowledge.
```

---

## FULL TOPIC TABLE

| ID   | Topic Name                                                               | Status | Interview   | Production  | Level |
| ---- | ------------------------------------------------------------------------ | ------ | ----------- | ----------- | ----- |
| 2.01 | The .NET Platform: CLR, SDK, Runtimes, and the Compilation Pipeline      | ⬜      | 🟡 Medium   | 🟠 High     | 1     |
| 2.02 | C# Program Structure: Syntax, Namespaces, and Project Files              | ⬜      | 🟡 Low      | 🟡 Medium   | 1     |
| 2.03 | Data Types, Literals, and Type Conversions                               | ⬜      | 🟠 High     | 🔴 Critical | 1     |
| 2.04 | Variables, Constants, and Scope                                          | ⬜      | 🟡 Low      | 🟡 Medium   | 1     |
| 2.05 | Operators: Complete Reference                                            | ⬜      | 🟡 Medium   | 🟠 High     | 1     |
| 2.06 | Control Flow: Conditionals, Loops, and Branching                         | ⬜      | 🟡 Low      | 🔴 Critical | 1     |
| 2.07 | Methods: Signatures, Parameters, Overloading, and Local Functions        | ⬜      | 🟡 Medium   | 🔴 Critical | 1     |
| 2.08 | Classes: Fields, Constructors, Static Members, and Object Initialization | ⬜      | 🟡 Medium   | 🔴 Critical | 1     |
| 2.09 | Properties, Indexers, and Access Modifiers                               | ⬜      | 🟡 Medium   | 🔴 Critical | 1     |
| 2.10 | Inheritance, Polymorphism, Casting, and the Object Hierarchy             | ⬜      | 🟠 High     | 🔴 Critical | 1     |
| 2.11 | Interfaces and Abstract Classes                                          | ⬜      | 🟠 High     | 🔴 Critical | 1     |
| 2.12 | Enums and Structs: Fundamentals                                          | ⬜      | 🟡 Medium   | 🟠 High     | 1     |
| 2.13 | Arrays and Collection Basics                                             | ⬜      | 🟡 Medium   | 🔴 Critical | 1     |
| 2.14 | String Fundamentals: Methods, Formatting, and StringBuilder              | ⬜      | 🟡 Medium   | 🔴 Critical | 1     |
| 2.15 | Exception Handling: Fundamentals                                         | ⬜      | 🟠 High     | 🔴 Critical | 1     |
| 2.16 | Value Types vs Reference Types: Deep Mechanics                           | ✅      | 🔴 Critical | 🔴 Critical | 2     |
| 2.17 | Generics: Constraints, Reification, and the Type System                  | ⬜      | 🔴 Critical | 🔴 Critical | 2     |
| 2.18 | Nullable Types: Nullable<T> and Nullable Reference Types                 | ⬜      | 🟠 High     | 🔴 Critical | 2     |
| 2.19 | Records: Positional Syntax, Compiler-Generated Members, and Inheritance  | ⬜      | 🟠 High     | 🟠 High     | 2     |
| 2.20 | Pattern Matching: Type, Property, Relational, and Switch Expressions     | ⬜      | 🟠 High     | 🟠 High     | 2     |
| 2.21 | Delegates, Func, Action, and Closures                                    | ⬜      | 🟠 High     | 🔴 Critical | 2     |
| 2.22 | Events and the Event Pattern                                             | ⬜      | 🟠 High     | 🟠 High     | 2     |
| 2.23 | LINQ: Every Operator Reference                                           | ⬜      | 🔴 Critical | 🔴 Critical | 2     |
| 2.24 | LINQ: Execution Model, Deferred Evaluation, and IQueryable               | ⬜      | 🔴 Critical | 🔴 Critical | 2     |
| 2.25 | Iterators and yield return                                               | ⬜      | 🟡 Medium   | 🟠 High     | 2     |
| 2.26 | Extension Methods and Fluent APIs                                        | ⬜      | 🟡 Medium   | 🟠 High     | 2     |
| 2.27 | Tuples, ValueTuple, and Deconstruction                                   | ⬜      | 🟠 High     | 🔴 Critical | 2     |
| 2.28 | Equality and Comparison: IEquatable, IComparable, and GetHashCode        | ⬜      | 🟠 High     | 🔴 Critical | 2     |
| 2.29 | async/await: The State Machine                                           | ⬜      | 🔴 Critical | 🔴 Critical | 2     |
| 2.30 | IDisposable, IAsyncDisposable, and Resource Management                   | ⬜      | 🟠 High     | 🔴 Critical | 2     |
| 2.31 | Operator Overloading and Conversions                                     | ⬜      | 🟡 Medium   | 🟡 Medium   | 2     |
| 2.32 | Attributes and Metadata                                                  | ⬜      | 🟡 Medium   | 🟠 High     | 2     |
| 2.33 | Generics: Variance, Generic Math, and Advanced Patterns                  | ⬜      | 🟠 High     | 🟠 High     | 3     |
| 2.34 | Collections: Internals and Selection Guide                               | ⬜      | 🔴 Critical | 🔴 Critical | 3     |
| 2.35 | Strings: Internals and High-Performance Operations                       | ⬜      | 🟡 Medium   | 🟠 High     | 3     |
| 2.36 | Exception Handling: Production Patterns                                  | ⬜      | 🟠 High     | 🔴 Critical | 3     |
| 2.37 | Virtual Dispatch, Polymorphism, and the CLR Object Model                 | ⬜      | 🔴 Critical | 🔴 Critical | 3     |
| 2.38 | Spans, Memory, and Zero-Copy Patterns                                    | ⬜      | 🟠 High     | 🟠 High     | 3     |
| 2.39 | Threading Primitives                                                     | ⬜      | 🔴 Critical | 🔴 Critical | 3     |
| 2.40 | GC Interaction, Finalizers, and WeakReference                            | ⬜      | 🟠 High     | 🟠 High     | 3     |
| 2.41 | Performance: Zero-Allocation Patterns                                    | ⬜      | 🟠 High     | 🔴 Critical | 3     |
| 2.42 | Reflection                                                               | ⬜      | 🟡 Medium   | 🟡 Medium   | 3     |
| 2.43 | Expression Trees                                                         | ⬜      | 🟡 Medium   | 🟠 High     | 3     |
| 2.44 | Dynamic, the DLR, and Late Binding                                       | ⬜      | 🟡 Medium   | 🟡 Medium   | 3     |
| 2.45 | Channels and Concurrent Pipelines                                        | ⬜      | 🟡 Medium   | 🟠 High     | 3     |
| 2.46 | Task Parallel Library (TPL) and PLINQ                                    | ⬜      | 🟠 High     | 🟠 High     | 3     |
| 2.47 | Dependency Injection Internals                                           | ⬜      | 🟠 High     | 🔴 Critical | 4     |
| 2.48 | Benchmarking with BenchmarkDotNet                                        | ⬜      | 🟡 Medium   | 🟠 High     | 4     |
| 2.49 | Tiered Compilation, JIT Internals, and PGO                               | ⬜      | 🟠 High     | 🟠 High     | 4     |
| 2.50 | Advanced Async Patterns: ValueTask, Custom Awaitables, and Async Streams | ⬜      | 🟠 High     | 🟠 High     | 4     |
| 2.51 | Unsafe Code and Interop                                                  | ⬜      | 🟡 Medium   | 🟡 Medium   | 4     |
| 2.52 | Source Generators                                                        | ⬜      | 🟡 Medium   | 🟠 High     | 4     |
| 2.53 | Native AOT, Trimming, and Publish-Time Constraints                       | ⬜      | 🟡 Medium   | 🟠 High     | 4     |
| 2.54 | C# Language Features Cheatsheet (C# 9–13)                                | ⬜      | 🟠 High     | 🟠 High     | 4     |

---

## STUDY PRIORITY GUIDE

```
TIER 1 — Start Here (interview + production critical, senior role target)
  2.16 ✅  Value Types vs Reference Types
  2.17     Generics: Constraints and Reification
  2.23     LINQ: Every Operator Reference
  2.24     LINQ: Execution Model
  2.29     async/await: The State Machine
  2.37     Virtual Dispatch and the CLR Object Model
  2.34     Collections: Internals and Selection Guide
  2.39     Threading Primitives

TIER 2 — Daily Production + High Interview Value
  2.18     Nullable Types
  2.21     Delegates, Func, Action, Closures
  2.27     Tuples and Deconstruction
  2.28     Equality and Comparison
  2.30     IDisposable and Resource Management
  2.36     Exception Handling: Production Patterns
  2.38     Spans, Memory, Zero-Copy
  2.40     GC Interaction and WeakReference
  2.41     Performance: Zero-Allocation Patterns

TIER 3 — Core Language Completion
  2.19     Records
  2.20     Pattern Matching
  2.22     Events and the Event Pattern
  2.25     Iterators and yield return
  2.26     Extension Methods and Fluent APIs
  2.31     Operator Overloading and Conversions
  2.32     Attributes and Metadata
  2.33     Generics: Variance and Generic Math
  2.35     String Internals
  2.42     Reflection
  2.43     Expression Trees
  2.44     Dynamic and the DLR
  2.45     Channels and Concurrent Pipelines
  2.46     TPL and PLINQ

TIER 4 — Advanced and Specialist
  2.47     Dependency Injection Internals
  2.48     BenchmarkDotNet
  2.49     JIT Internals and Tiered Compilation
  2.50     Advanced Async Patterns
  2.51     Unsafe Code and Interop
  2.52     Source Generators
  2.53     Native AOT and Trimming
  2.54     C# 9–13 Language Features Cheatsheet

LEVEL 1 — Foundations (generate if new to C# or want complete coverage)
  2.01 → 2.15 in order — skip any topic you know with complete confidence
```

---

## TOPIC DETAILS — PROMPT VALUES

---

### 2.01 — The .NET Platform: CLR, SDK, Runtimes, and the Compilation Pipeline

**TOPIC_ID:** `2.01` **TOPIC_NAME:** `The .NET Platform: CLR, SDK, Runtimes, and the Compilation Pipeline` **RELATED_TOPICS:**

```
- [[2.02 — C# Program Structure]] — program structure only makes sense with a model of what executes it
- [[2.16 — Value Types vs Reference Types]] — the managed memory model and GC are CLR features
- [[2.37 — Virtual Dispatch and the CLR Object Model]] — vtables and method tables are CLR runtime structures
- [[2.49 — Tiered Compilation, JIT Internals, and PGO]] — JIT compilation is the execution layer of the CLR; 2.49 goes deep on it
```

**Key topics inside this note:** CLR execution model, MSIL/CIL and what "managed code" means, JIT compilation pipeline (source → IL → machine code), .NET 5+ vs .NET Framework vs .NET Standard (and why the distinction matters), BCL, Assembly structure (.dll/.exe), AppDomain removal, garbage collection overview (managed heap, generations), runtime vs SDK vs framework, cross-platform execution model.

---

### 2.02 — C# Program Structure: Syntax, Namespaces, and Project Files

**TOPIC_ID:** `2.02` **TOPIC_NAME:** `C# Program Structure: Syntax, Namespaces, and Project Files` **RELATED_TOPICS:**

```
- [[2.01 — The .NET Platform]] — runtimes provide the execution context for C# programs
- [[2.08 — Classes]] — namespaces organize classes; understanding one requires the other
- [[2.32 — Attributes and Metadata]] — [assembly:] level attributes are file-level constructs
- [[2.53 — Native AOT, Trimming, and Publish-Time Constraints]] — .csproj publish settings for AOT live here
```

**Key topics inside this note:** top-level statements vs explicit Main method, namespace declaration, nested namespaces, using directives, global using (C# 10), file-scoped namespace declaration (C# 10), .csproj SDK-style format, TargetFramework, implicit usings, nullable project settings, preprocessor directives (#if, #define, #region, #pragma), partial classes and partial methods.

---

### 2.03 — Data Types, Literals, and Type Conversions

**TOPIC_ID:** `2.03` **TOPIC_NAME:** `Data Types, Literals, and Type Conversions` **RELATED_TOPICS:**

```
- [[2.05 — Operators]] — operators work on typed values; promotion rules and result types depend on this
- [[2.12 — Enums and Structs: Fundamentals]] — enums and structs are value types built on this type system
- [[2.16 — Value Types vs Reference Types]] — this topic provides the deep mechanics behind the type split
- [[2.27 — Tuples, ValueTuple, and Deconstruction]] — tuple element types are primitives composed together
```

**Key topics inside this note:** all integral types (sbyte/byte/short/ushort/int/uint/long/ulong) with sizes and ranges, floating-point precision trap (float vs double vs decimal — use decimal for money), bool, char (UTF-16 code unit), object, dynamic. Literal syntax (L/u/ul/0x/0b/digit separator _). Implicit widening conversion. Explicit cast and truncation. Convert class. Parse vs TryParse. checked/unchecked arithmetic overflow. var keyword and type inference.

---

### 2.04 — Variables, Constants, and Scope

**TOPIC_ID:** `2.04` **TOPIC_NAME:** `Variables, Constants, and Scope` **RELATED_TOPICS:**

```
- [[2.03 — Data Types]] — variable declarations require type knowledge
- [[2.08 — Classes]] — fields, their initialization order, and class-level scope
- [[2.06 — Control Flow]] — loop variables and block scope interactions
- [[2.16 — Value Types vs Reference Types]] — copy semantics directly affect how assignment behaves
```

**Key topics inside this note:** declaration and initialization, definite assignment rule (must assign before use), multiple declarations. const (compile-time, inlined by compiler) vs readonly (runtime, set once). Static readonly fields. Block scope, method scope, class scope, nested scope shadowing. Declaration expressions (out var pattern). Discard (_) for intentionally ignored values. Unused variable warnings and why they matter.

---

### 2.05 — Operators: Complete Reference

**TOPIC_ID:** `2.05` **TOPIC_NAME:** `Operators: Complete Reference` **RELATED_TOPICS:**

```
- [[2.03 — Data Types]] — operator result types and numeric promotion rules depend on operand types
- [[2.06 — Control Flow]] — logical and comparison operators directly drive all conditional branching
- [[2.28 — Equality and Comparison]] — == and != operators and their contract with Equals/GetHashCode
- [[2.31 — Operator Overloading and Conversions]] — custom types can redefine every operator covered here
```

**Key topics inside this note:** arithmetic (+,-,_,/,% with integer vs float behavior), increment/decrement (pre vs post), comparison (==,!=,<,>,<=,>=), logical (&&,||,! with short-circuit evaluation), bitwise (&,|,^,~,<<,>>,>>> unsigned right shift), compound assignment (+=,-=,_=,/=,%=,&=,|=,^=,<<=,>>=,??=), conditional ternary (?:), null-coalescing (??), null-conditional (?.,?[]), range and index (.. ,^), is/as, typeof, sizeof, nameof. Operator precedence table.

---

### 2.06 — Control Flow: Conditionals, Loops, and Branching

**TOPIC_ID:** `2.06` **TOPIC_NAME:** `Control Flow: Conditionals, Loops, and Branching` **RELATED_TOPICS:**

```
- [[2.05 — Operators]] — conditions in if/while/for use logical and comparison operators
- [[2.07 — Methods]] — return statement terminates method execution and is the primary branching tool
- [[2.20 — Pattern Matching]] — switch expressions and type-based patterns supersede switch statements
- [[2.25 — Iterators and yield return]] — yield break and yield return are specialized control flow in iterators
```

**Key topics inside this note:** if/else and else-if chains, switch statement (with fall-through rules and goto case), for loop (all three clauses optional), foreach (relies on GetEnumerator/MoveNext/Current contract), while, do-while (guarantees at least one execution). break (exit loop/switch), continue (skip to next iteration), return (exit method with value), goto (and why to never use it except in switch). Early return pattern. Nested loop labeled break (not available in C#, pattern workaround). Unreachable code warnings.

---

### 2.07 — Methods: Signatures, Parameters, Overloading, and Local Functions

**TOPIC_ID:** `2.07` **TOPIC_NAME:** `Methods: Signatures, Parameters, Overloading, and Local Functions` **RELATED_TOPICS:**

```
- [[2.08 — Classes]] — methods are class members; instance vs static method distinction lives here
- [[2.16 — Value Types vs Reference Types]] — parameter passing semantics differ fundamentally by type
- [[2.21 — Delegates, Func, Action, and Closures]] — local functions and lambdas share syntax; closures capture locals
- [[2.09 — Properties, Indexers, and Access Modifiers]] — properties are syntactic sugar over get/set methods
```

**Key topics inside this note:** method signature, return type, void, static vs instance. Overloading resolution (by parameter types only, NOT by return type). Value parameters (copy), ref parameters (alias), out parameters (must assign), in parameters (readonly alias). params keyword (variable argument list). Optional parameters and default values. Named arguments. Expression-bodied methods (=>). Local functions (can be static). Recursion. Method hiding vs overriding.

---

### 2.08 — Classes: Fields, Constructors, Static Members, and Object Initialization

**TOPIC_ID:** `2.08` **TOPIC_NAME:** `Classes: Fields, Constructors, Static Members, and Object Initialization` **RELATED_TOPICS:**

```
- [[2.09 — Properties, Indexers, and Access Modifiers]] — properties are the public face of class data fields
- [[2.10 — Inheritance]] — constructor chaining in inheritance and the base() call
- [[2.16 — Value Types vs Reference Types]] — class instances are reference types; heap allocation on new
- [[2.30 — IDisposable and Resource Management]] — class lifecycle includes cleanup; Dispose pattern is class-based
```

**Key topics inside this note:** class syntax, instance fields with default values, constructor syntax, overloaded constructors, constructor chaining (this()), primary constructors (C# 12). Object initializers ({ Property = value }). Static fields, static methods, static constructors (run once, thread-safe, no parameters), static classes. readonly fields (set in constructor only). new keyword, object allocation lifecycle. Partial classes. Sealed classes.

---

### 2.09 — Properties, Indexers, and Access Modifiers

**TOPIC_ID:** `2.09` **TOPIC_NAME:** `Properties, Indexers, and Access Modifiers` **RELATED_TOPICS:**

```
- [[2.08 — Classes]] — properties belong to classes and are the preferred alternative to public fields
- [[2.10 — Inheritance]] — virtual/override applies to properties; abstract properties create contracts
- [[2.19 — Records]] — records auto-generate init-only properties for all positional parameters
- [[2.11 — Interfaces]] — interface properties define contracts without implementation
```

**Key topics inside this note:** auto-properties (get; set;), backing fields, read-only auto-property (get; only), expression-bodied get/set, computed properties (get only), init accessor (C# 9, set-once after construction). Property with asymmetric access modifier (public get; private set;). Indexer syntax (this[int i] with get/set). All six access modifiers: public, private, protected, internal, protected internal, private protected. Access modifier on individual accessors.

---

### 2.10 — Inheritance, Polymorphism, Casting, and the Object Hierarchy

**TOPIC_ID:** `2.10` **TOPIC_NAME:** `Inheritance, Polymorphism, Casting, and the Object Hierarchy` **RELATED_TOPICS:**

```
- [[2.11 — Interfaces and Abstract Classes]] — interface implementation is the complement to class inheritance
- [[2.37 — Virtual Dispatch and the CLR Object Model]] — virtual dispatch is the runtime mechanism behind polymorphism
- [[2.28 — Equality and Comparison]] — object.Equals and GetHashCode are inherited by every type from object
- [[2.20 — Pattern Matching]] — type patterns (x is MyType t) use the same type hierarchy described here
```

**Key topics inside this note:** base keyword (calling base constructor, accessing base members), virtual/override (runtime polymorphism via vtable), sealed class and sealed method (prevent further extension), new keyword as hiding (not polymorphic — caller type determines which runs). Constructor execution order in inheritance chains. object as root: ToString, Equals, GetHashCode, GetType. Upcasting (implicit, always safe), downcasting with (T) (throws on failure), is operator (safe type check), as operator (returns null on failure), InvalidCastException.

---

### 2.11 — Interfaces and Abstract Classes

**TOPIC_ID:** `2.11` **TOPIC_NAME:** `Interfaces and Abstract Classes` **RELATED_TOPICS:**

```
- [[2.10 — Inheritance]] — abstract classes participate in the inheritance hierarchy; interfaces do not
- [[2.37 — Virtual Dispatch and the CLR Object Model]] — interface dispatch uses a separate mechanism (IMT) from class virtual dispatch
- [[2.26 — Extension Methods and Fluent APIs]] — extension methods on interfaces are the most powerful combination of both features
- [[2.33 — Generics: Variance]] — interface variance (IEnumerable<out T>, IComparer<in T>) is an interface-only feature
```

**Key topics inside this note:** interface declaration (methods, properties, events, indexers), implementing single and multiple interfaces, explicit interface implementation (when two interfaces have the same member name), abstract class (abstract methods/properties defining a contract, partial implementation possible, has constructors). Interface vs abstract class decision framework. Default interface methods (C# 8+) and their tradeoffs. Marker interfaces. Interface segregation principle in practice.

---

### 2.12 — Enums and Structs: Fundamentals

**TOPIC_ID:** `2.12` **TOPIC_NAME:** `Enums and Structs: Fundamentals` **RELATED_TOPICS:**

```
- [[2.03 — Data Types]] — enums are backed by integral types; structs are value types
- [[2.16 — Value Types vs Reference Types]] — structs ARE value types; this topic provides the deep mechanics
- [[2.28 — Equality and Comparison]] — struct equality uses slow ValueType.Equals by default; always override
- [[2.31 — Operator Overloading and Conversions]] — structs frequently define operators (Money, Point, Vector)
```

**Key topics inside this note:** enum declaration, underlying type (default int, can be byte/short/long), explicit values, casting to/from int. [Flags] attribute and bitwise combining (bitmask pattern), HasFlag method, [Flags] gotchas (zero value, combined values). Enum.Parse, Enum.TryParse, Enum.GetNames, Enum.GetValues, Enum.IsDefined. Struct declaration, default(T) all-zeros value (cannot be prevented), constructor limitations before C# 10. Mutable struct copy-on-write trap (preview). readonly struct preview. When to choose struct over class.

---

### 2.13 — Arrays and Collection Basics

**TOPIC_ID:** `2.13` **TOPIC_NAME:** `Arrays and Collection Basics` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — int[] is a reference type; its elements are value types embedded inline
- [[2.17 — Generics]] — List<T> and Dictionary<K,V> are generic; the type parameter shapes behavior
- [[2.34 — Collections: Internals and Selection Guide]] — this topic teaches correct usage; 2.34 teaches internal mechanics
- [[2.23 — LINQ: Every Operator Reference]] — all LINQ operators work on IEnumerable<T>, which arrays and lists implement
```

**Key topics inside this note:** single-dimensional arrays, multi-dimensional arrays ([,]), jagged arrays ([][]). Array class: Sort, Copy, IndexOf, Resize, Clear, Reverse. Array initialization shorthand. Array covariance problem (string[] to object[] is unsafe). List<T>: Add, Remove, RemoveAt, Count, Capacity, IndexOf, Contains, Sort, ForEach. Dictionary<K,V>: Add, TryGetValue, ContainsKey, Remove, Keys/Values, KeyValuePair iteration. HashSet<T>: Add, Contains, UnionWith, IntersectWith, ExceptWith. Queue<T> (FIFO), Stack<T> (LIFO). When to use which — decision table.

---

### 2.14 — String Fundamentals: Methods, Formatting, and StringBuilder

**TOPIC_ID:** `2.14` **TOPIC_NAME:** `String Fundamentals: Methods, Formatting, and StringBuilder` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — string is an immutable reference type with value equality semantics
- [[2.35 — Strings: Internals and High-Performance Operations]] — interning, layout, and Span-based operations live there
- [[2.28 — Equality and Comparison]] — string == uses value equality; StringComparison enum controls culture
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — string.AsSpan() and ReadOnlySpan<char> build on this
```

**Key topics inside this note:** string immutability (why every method returns a new string, no in-place mutation). Common methods: Contains, StartsWith, EndsWith, IndexOf, LastIndexOf, Substring/Slice, Remove, Replace, Insert, Split, Join, Trim/TrimStart/TrimEnd, ToUpper/ToLower, PadLeft/PadRight, IsNullOrEmpty, IsNullOrWhiteSpace. String comparison: == semantics, StringComparison enum (Ordinal vs InvariantCulture vs CurrentCulture), StringComparer. Formatting: composite ({0:format}), interpolation ($""), format specifiers (D, F, N, X, :yyyy-MM-dd). Verbatim strings (@), raw string literals (C# 11, """), u8 suffix. StringBuilder: Append, AppendLine, Insert, Remove, Replace, ToString — when to use vs string concatenation.

---

### 2.15 — Exception Handling: Fundamentals

**TOPIC_ID:** `2.15` **TOPIC_NAME:** `Exception Handling: Fundamentals` **RELATED_TOPICS:**

```
- [[2.08 — Classes]] — custom exceptions are classes; they inherit from Exception
- [[2.36 — Exception Handling: Production Patterns]] — this topic is the foundation; 2.36 covers production-grade patterns
- [[2.30 — IDisposable and Resource Management]] — finally block guarantees cleanup; IDisposable formalizes this
- [[2.29 — async/await: The State Machine]] — async exception propagation has non-obvious behavior built on these fundamentals
```

**Key topics inside this note:** try/catch/finally, multiple catch blocks (order matters: most specific first), exception hierarchy (Exception → SystemException → IOException etc.; why ApplicationException is deprecated). throw vs throw ex (stack trace preservation — this is a classic interview question). Creating custom exceptions: constructor conventions (message + innerException), when to add properties. when filter (C# 6). Exception properties: Message, StackTrace, InnerException, HResult. Common built-in exceptions and when they're thrown. The finally guarantee (runs even on return, not on Environment.FailFast).

---

### 2.16 — Value Types vs Reference Types: Deep Mechanics ✅

Already generated. See the existing note.

**Migration:** Rename `2_01_Value_Types_vs__Reference_Types.md` → `2_16_Value_Types_vs__Reference_Types.md`. Update `topic_id: "2.01"` → `topic_id: "2.16"` in YAML frontmatter.

---

### 2.17 — Generics: Constraints, Reification, and the Type System

**TOPIC_ID:** `2.17` **TOPIC_NAME:** `Generics: Constraints, Reification, and the Type System` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — generics avoid boxing by being reified per value-type instantiation at JIT time
- [[2.18 — Nullable Types]] — generic constraints interact with nullable annotations; T? means different things for struct vs class T
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — the unmanaged constraint enables Span-based generic algorithms
- [[2.41 — Performance: Zero-Allocation Patterns]] — reified generics are the primary tool for zero-boxing hot paths
- [[2.34 — Collections: Internals and Selection Guide]] — all collections are generic; internal layout depends on T
```

**Key topics inside this note:** JIT reification model (one native code version per value-type T, shared for all reference-type T), all generic constraints: where T : struct, class, notnull, unmanaged, new(), base class, interface, INumber<T>. Open vs closed generic types. Generic type inference. Generic methods vs generic classes. Generic caching with typeof(T) as dictionary key (static generic field pattern). Generic math with INumber<T>/IAdditionOperators<T,T,T> (.NET 7+). MakeGenericType via reflection. Constraints combined.

---

### 2.18 — Nullable Types: Nullable<T> and Nullable Reference Types

**TOPIC_ID:** `2.18` **TOPIC_NAME:** `Nullable Types: Nullable<T> and Nullable Reference Types` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — Nullable<T> is a value-type struct; NRT is a compile-time annotation — completely different mechanisms
- [[2.17 — Generics]] — generic constraints interact with nullable annotations; T? has different meaning for struct vs class type parameters
- [[2.28 — Equality and Comparison]] — null equality semantics and null propagation through comparisons
- [[2.36 — Exception Handling: Production Patterns]] — NullReferenceException is what NRT prevents; ArgumentNullException.ThrowIfNull is the boundary guard
```

**Key topics inside this note:** Nullable<T> struct internals (HasValue + Value fields, ~zero overhead), T? for value types (Nullable<T>) vs T? for reference types (compiler annotation only — no runtime change). #nullable enable context and its project-level setting. Flow analysis (when the compiler knows something is non-null after a check). Null-forgiving operator (!) and when it is and is not appropriate. Nullable attributes: [NotNull], [MaybeNull], [NotNullWhen(bool)], [MemberNotNull]. ArgumentNullException.ThrowIfNull (C# 10). required members (C# 11). Nullable in API design.

---

### 2.19 — Records: Positional Syntax, Compiler-Generated Members, and Inheritance

**TOPIC_ID:** `2.19` **TOPIC_NAME:** `Records: Positional Syntax, Compiler-Generated Members, and Inheritance` **RELATED_TOPICS:**

```
- [[2.08 — Classes]] — record class is a class with compiler-generated members; same heap allocation behavior
- [[2.16 — Value Types vs Reference Types]] — record class (reference type) vs record struct (value type)
- [[2.20 — Pattern Matching]] — records enable exhaustive pattern matching over sealed hierarchies
- [[2.28 — Equality and Comparison]] — records generate value equality; understanding the generated code requires this topic
```

**Key topics inside this note:** what the compiler generates for a positional record (primary constructor, init-only properties, Equals, GetHashCode, Deconstruct, ToString, clone operator), with expression lowering (creates a copy with changed properties), record inheritance rules (derived record must call base, sealed stops the chain), record struct vs record class (value vs reference semantics), non-positional records with manual validation, primary constructors (C# 12) vs record positional parameters. When NOT to use records (mutable state, identity-based equality needed, large frequently-copied data).

---

### 2.20 — Pattern Matching: Type, Property, Relational, and Switch Expressions

**TOPIC_ID:** `2.20` **TOPIC_NAME:** `Pattern Matching: Type, Property, Relational, and Switch Expressions` **RELATED_TOPICS:**

```
- [[2.19 — Records]] — records + sealed hierarchies + pattern matching = discriminated unions in C#
- [[2.16 — Value Types vs Reference Types]] — type patterns generate isinst + unbox_any IL under the hood
- [[2.18 — Nullable Types]] — null pattern and nullable flow analysis are part of the pattern system
- [[2.10 — Inheritance]] — type patterns check against the same class hierarchy described in 2.10
```

**Key topics inside this note:** declaration patterns (type pattern + variable binding), type patterns (compiler lowers to isinst), constant patterns, property patterns (nested { Prop: value }), relational patterns (<, >, <=, >=), logical patterns (and/or/not), tuple patterns (multiple values in one switch arm), list patterns (C# 11, [first, .., last]), var pattern. Switch expressions with exhaustiveness checking and default arm. Pattern evaluation order. Sealed hierarchy design for exhaustive matching. Discriminated union patterns in C#.

---

### 2.21 — Delegates, Func, Action, and Closures

**TOPIC_ID:** `2.21` **TOPIC_NAME:** `Delegates, Func, Action, and Closures` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — delegates are reference types; the closure display class is a heap allocation
- [[2.24 — LINQ: Execution Model]] — all LINQ operators accept Func<T,bool> delegates; closures in predicates
- [[2.29 — async/await: The State Machine]] — async lambdas generate a state machine class; related mechanism
- [[2.43 — Expression Trees]] — Expression<Func<T,R>> vs Func<T,R>: same lambda syntax, different compilation
```

**Key topics inside this note:** delegate internals (_target field + _methodPtr field), custom delegate declaration vs Func/Action. Closure compiler transformation: the display class (compiler-generated heap object that holds captured variables). When lambdas allocate vs when the JIT caches them (static lambdas, no capture = zero allocation). The loop variable capture bug (classic gotcha) and fix. Multicast delegates and GetInvocationList(). static lambda keyword (C# 9, prevents captures). Events vs raw delegates. Async delegates and their state machine. Memory leak from capturing large objects.

---

### 2.22 — Events and the Event Pattern

**TOPIC_ID:** `2.22` **TOPIC_NAME:** `Events and the Event Pattern` **RELATED_TOPICS:**

```
- [[2.21 — Delegates, Func, Action, and Closures]] — events ARE delegates with restricted outside access (only += and -=)
- [[2.30 — IDisposable and Resource Management]] — failing to unsubscribe from events is the most common managed memory leak
- [[2.40 — GC Interaction, Finalizers, and WeakReference]] — event subscriptions create strong references from publisher to subscriber
- [[2.39 — Threading Primitives]] — thread-safe event invocation requires the volatile copy pattern
```

**Key topics inside this note:** event keyword vs public delegate field (the access restriction event provides: outside code cannot invoke or reassign, only subscribe/unsubscribe), EventHandler<TEventArgs> convention, custom EventArgs with meaningful properties. Thread-safe invocation: the volatile copy pattern (var h = MyEvent; h?.Invoke(...)). Custom add/remove accessors for locking or weak reference storage. Memory leak from not unsubscribing (publisher holds reference to subscriber, subscriber never collected). Weak event pattern. When to use events vs Func callbacks vs reactive streams (IObservable).

---

### 2.23 — LINQ: Every Operator Reference

**TOPIC_ID:** `2.23` **TOPIC_NAME:** `LINQ: Every Operator Reference` **RELATED_TOPICS:**

```
- [[2.24 — LINQ: Execution Model]] — this note is the operator reference; 2.24 explains WHY operators behave as they do
- [[2.21 — Delegates, Func, Action, and Closures]] — every LINQ operator takes a Func<T,...> as predicate or selector
- [[2.17 — Generics]] — LINQ operators are generic extension methods; type inference drives usage
- [[2.13 — Arrays and Collection Basics]] — arrays and List<T> implement IEnumerable<T>, the foundation of all LINQ
```

**Key topics inside this note:** every LINQ operator with method signature, execution type (deferred vs immediate), and one concrete example in a named business domain. Filtering: Where, OfType, Cast. Projection: Select, SelectMany. Ordering: OrderBy, OrderByDescending, ThenBy, ThenByDescending, Reverse. Grouping: GroupBy, ToLookup. Joining: Join, GroupJoin, Zip. Set: Distinct, DistinctBy, Union, UnionBy, Intersect, IntersectBy, Except, ExceptBy. Aggregation: Count, LongCount, Sum, Min, Max, Average, MinBy, MaxBy, Aggregate. Quantifiers: Any, All, Contains. Element: First, FirstOrDefault, Last, LastOrDefault, Single, SingleOrDefault, ElementAt, ElementAtOrDefault, DefaultIfEmpty. Partitioning: Take, TakeLast, TakeWhile, Skip, SkipLast, SkipWhile, Chunk. Materializing: ToList, ToArray, ToDictionary, ToHashSet, ToLookup, AsEnumerable. Method syntax vs query syntax equivalence table.

---

### 2.24 — LINQ: Execution Model, Deferred Evaluation, and IQueryable

**TOPIC_ID:** `2.24` **TOPIC_NAME:** `LINQ: Execution Model, Deferred Evaluation, and IQueryable` **RELATED_TOPICS:**

```
- [[2.23 — LINQ: Every Operator Reference]] — this note explains the mechanics behind the operators listed there
- [[2.25 — Iterators and yield return]] — LINQ operators are iterators; deferred execution IS iterator state machine semantics
- [[2.21 — Delegates, Func, Action, and Closures]] — closure variable capture in LINQ predicates causes subtle bugs
- [[2.43 — Expression Trees]] — IQueryable<T> captures LINQ as expression trees to translate to SQL
```

**Key topics inside this note:** deferred execution pipeline (iterator chain, nothing runs until MoveNext), IEnumerable<T> vs IQueryable<T> — the critical distinction (in-memory vs database translation). Iterator chain wrapping (WhereEnumerableIterator wrapping SelectEnumerableIterator). Multiple enumeration problem (calling a method twice = two database queries or two file reads). Streaming vs materializing operators. Performance traps: Count() vs Any(), OrderBy().First() vs MinBy(), Count() on IQueryable. Closure variable capture in predicates. IAsyncEnumerable<T> and await foreach. N+1 query problem with IQueryable.

---

### 2.25 — Iterators and yield return

**TOPIC_ID:** `2.25` **TOPIC_NAME:** `Iterators and yield return` **RELATED_TOPICS:**

```
- [[2.24 — LINQ: Execution Model]] — LINQ operators are implemented as iterators; deferred execution is iterator semantics
- [[2.29 — async/await: The State Machine]] — IAsyncEnumerable<T> combines yield return + await; both are state machines
- [[2.21 — Delegates, Func, Action, and Closures]] — iterator state classes and closure display classes use the same compiler pattern
- [[2.30 — IDisposable and Resource Management]] — iterators implement IDisposable; finally blocks run on early dispose
```

**Key topics inside this note:** compiler state machine transformation for iterator methods (_state field, MoveNext() dispatch, generated class), yield return vs yield break semantics. IEnumerable<T> vs IEnumerator<T>: why calling the method twice gives two independent enumerators. Lazy infinite sequences. File line streaming with StreamReader and yield (vs ReadAllLines). Composable pipeline with chained iterators. Recursive tree traversal stack overflow risk vs iterative DFS. IAsyncEnumerable<T> with [EnumeratorCancellation], ConfigureAwait on await foreach.

---

### 2.26 — Extension Methods and Fluent APIs

**TOPIC_ID:** `2.26` **TOPIC_NAME:** `Extension Methods and Fluent APIs` **RELATED_TOPICS:**

```
- [[2.23 — LINQ: Every Operator Reference]] — all of LINQ is built on extension methods on IEnumerable<T>
- [[2.21 — Delegates]] — extension methods frequently accept Func<T,R> parameters as callbacks or predicates
- [[2.17 — Generics]] — generic extension methods and their type inference rules
- [[2.11 — Interfaces]] — extension methods on interfaces are the most powerful pattern; LINQ is proof
```

**Key topics inside this note:** extension method declaration (static class, static method, this parameter), compiler resolution priority (instance methods win, then current namespace, then imported namespaces). Extension methods cannot override instance methods (they are syntax sugar for static calls). Extension methods on interfaces (the LINQ design pattern — add behavior to any implementer). Fluent builder pattern with method chaining returning this. Domain-enriching extension methods on string and IEnumerable<T>. Extension methods vs default interface methods (C# 8+): when each is correct. Pitfalls: namespace ambiguity, pollution, overuse killing discoverability.

---

### 2.27 — Tuples, ValueTuple, and Deconstruction

**TOPIC_ID:** `2.27` **TOPIC_NAME:** `Tuples, ValueTuple, and Deconstruction` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — ValueTuple is a struct (zero heap allocation); old Tuple<T1,T2> is a class
- [[2.20 — Pattern Matching]] — tuple patterns in switch expressions directly deconstruct ValueTuples
- [[2.24 — LINQ: Execution Model]] — LINQ Zip and GroupBy produce tuples; understanding them requires this topic
- [[2.17 — Generics]] — ValueTuple<T1,...> is a generic struct; named elements are compiler syntactic sugar
```

**Key topics inside this note:** ValueTuple<T1,T2,...> as struct vs old Tuple<T1,T2,...> as class (allocation difference and why the old API is avoided). Named element syntax (syntactic sugar: .Name compiles to .Item1). Tuple return types for multiple returns without out parameters. Deconstruct() instance method protocol (how var (x, y) = point works). Deconstruct() extension method for types you don't own. Tuple pattern matching. Variable swap without temp (var (a, b) = (b, a)). Discard with _. Tuple equality (structural for ValueTuple). When tuples are appropriate vs creating a named type.

---

### 2.28 — Equality and Comparison: IEquatable, IComparable, and GetHashCode

**TOPIC_ID:** `2.28` **TOPIC_NAME:** `Equality and Comparison: IEquatable, IComparable, and GetHashCode` **RELATED_TOPICS:**

```
- [[2.05 — Operators]] — == and != operator overloads must be consistent with Equals
- [[2.16 — Value Types vs Reference Types]] — struct equality is value-based by default; class equality is reference-based
- [[2.19 — Records]] — records auto-generate value equality; understanding the generated code requires this topic
- [[2.34 — Collections: Internals and Selection Guide]] — Dictionary/HashSet correctness entirely depends on the GetHashCode contract
```

**Key topics inside this note:** equality contract (reflexive, symmetric, transitive, null-safe, consistent). Critical rule: if Equals(x,y) is true then GetHashCode(x) == GetHashCode(y) must also be true. What a GetHashCode violation causes in a Dictionary (TryGetValue silently returns false — data not lost but unretrievable). IEquatable<T> vs object.Equals (boxing avoidance, ~3× faster in generic collections). IEqualityComparer<T> for external equality strategy (inject into Dictionary, HashSet, LINQ Distinct). IComparable<T> for natural ordering (SortedSet, Array.Sort). IComparer<T> for external ordering strategy. HashCode.Combine vs manual XOR. Record vs struct vs class equality behavior.

---

### 2.29 — async/await: The State Machine

**TOPIC_ID:** `2.29` **TOPIC_NAME:** `async/await: The State Machine` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — Task<T> allocates; ValueTask<T> avoids allocation on the synchronous path
- [[2.21 — Delegates, Func, Action, and Closures]] — async lambdas and their state machine + closure capture interaction
- [[2.45 — Channels and Concurrent Pipelines]] — channels depend on async/await for backpressure handling
- [[2.39 — Threading Primitives]] — SynchronizationContext, thread pool scheduling, ConfigureAwait behavior
- [[2.50 — Advanced Async Patterns]] — ValueTask internals, custom awaitables, and pooled awaitables go beyond this topic
```

**Key topics inside this note:** state machine struct generated by compiler (full struct layout, _state field, MoveNext), MoveNext() suspension (registering continuation) and resumption (callback fires), AsyncTaskMethodBuilder<T>. Task<T> vs ValueTask<T> allocation model. CancellationToken propagation patterns (pass-through, register cleanup). ConfigureAwait(false) and when it matters (library vs application code). async void hazards (exceptions unhandled, not awaitable). Task.WhenAll with exception aggregation (AggregateException). Hedged requests with Task.WhenAny. SemaphoreSlim for bounded parallelism. IAsyncEnumerable<T>.

---

### 2.30 — IDisposable, IAsyncDisposable, and Resource Management

**TOPIC_ID:** `2.30` **TOPIC_NAME:** `IDisposable, IAsyncDisposable, and Resource Management` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — structs cannot have finalizers; unmanaged resources require class wrappers
- [[2.29 — async/await: The State Machine]] — await using calls DisposeAsync(); understanding async state machines explains why
- [[2.40 — GC Interaction, Finalizers, and WeakReference]] — finalizers and GC.SuppressFinalize() are the cleanup mechanism of last resort
- [[2.51 — Unsafe Code and Interop]] — SafeHandle is the correct way to manage OS handles; avoids raw IntPtr
```

**Key topics inside this note:** using statement compiler lowering (try/finally equivalent). using declaration (C# 8, scope-based). Full Dispose pattern (managed path + unmanaged path + bool disposing parameter). Finalizer timing (non-deterministic, expensive, runs on finalizer thread) and cost. GC.SuppressFinalize() why it matters (prevents double cleanup). IAsyncDisposable for async cleanup (WebSocket graceful close, Channel drain). await using. SafeHandle vs raw IntPtr. IMemoryOwner<T> and why it implements IDisposable. Anti-patterns: suppressing exceptions in Dispose, double-dispose without guard.

---

### 2.31 — Operator Overloading and Conversions

**TOPIC_ID:** `2.31` **TOPIC_NAME:** `Operator Overloading and Conversions` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — operator overloading is most appropriate on value types (structs)
- [[2.28 — Equality and Comparison]] — == and != must be consistent with Equals and GetHashCode
- [[2.19 — Records]] — records generate == and != automatically using value equality
- [[2.33 — Generics: Variance and Generic Math]] — INumber<T> operators (.NET 7+) build on overloaded operators
```

**Key topics inside this note:** operator overloading syntax, binary operator resolution rules, implicit vs explicit conversion operators (when each is appropriate — implicit for safe widening only), checked operator variants (C# 11). Constraint: == and != must be defined together; comparison operators must all be defined together. Result<T> with implicit T conversion. Money type enforcing business rules through operators. When NOT to overload operators (clarity over cleverness rule). INumber<T>/IAdditionOperators<T,T,T> generic math (.NET 7+). User-defined conversion chains.

---

### 2.32 — Attributes and Metadata

**TOPIC_ID:** `2.32` **TOPIC_NAME:** `Attributes and Metadata` **RELATED_TOPICS:**

```
- [[2.42 — Reflection]] — attributes are read at runtime via reflection when not source-generated
- [[2.52 — Source Generators]] — source generators read attributes at compile time; zero runtime cost
- [[2.29 — async/await: The State Machine]] — [AsyncStateMachine] is placed by the compiler itself
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — [CallerArgumentExpression] is a compiler-filled attribute
```

**Key topics inside this note:** how attributes are stored in PE metadata (no allocation until GetCustomAttribute() is called), [AttributeUsage] parameters (AllowMultiple, Inherited, AttributeTargets). Caller info attributes: [CallerMemberName], [CallerFilePath], [CallerLineNumber], [CallerArgumentExpression] (C# 10). Performance attributes: [MethodImpl(AggressiveInlining/NoInlining/AggressiveOptimization)], [SkipLocalsInit]. [Conditional("DEBUG")] for zero-cost debug-only code. [Obsolete] with migration message and error flag. Generic attributes (C# 11). Custom validation attributes. Attribute inheritance.

---

### 2.33 — Generics: Variance, Generic Math, and Advanced Patterns

**TOPIC_ID:** `2.33` **TOPIC_NAME:** `Generics: Variance, Generic Math, and Advanced Patterns` **RELATED_TOPICS:**

```
- [[2.17 — Generics: Constraints and Reification]] — direct prerequisite; this note extends those foundations
- [[2.11 — Interfaces and Abstract Classes]] — variance (out T, in T) is an interface and delegate-only feature
- [[2.34 — Collections: Internals and Selection Guide]] — IEnumerable<out T> covariance directly impacts collection assignment
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — allows ref struct (C# 13) enables Span<T> in generic algorithms
```

**Key topics inside this note:** covariance (out T) — what it allows (IEnumerable<Animal> x = IEnumerable<Dog>()) and why, contravariance (in T) — what it allows (IComparer<Animal> as IComparer<Dog>), why variance only works on interfaces and delegates (not concrete classes). Static abstract interface members (C# 11) as a prerequisite for generic math. Generic math: INumber<T>, IAdditionOperators<T,T,T>, IComparisonOperators<T,T,bool> (.NET 7+). Static generic field as a per-T cache. MakeGenericType and MakeGenericMethod. allows ref struct constraint (C# 13). Combining multiple constraints.

---

### 2.34 — Collections: Internals and Selection Guide

**TOPIC_ID:** `2.34` **TOPIC_NAME:** `Collections: Internals and Selection Guide` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — List<T> of struct vs List<T> of class: one allocation vs N allocations
- [[2.17 — Generics]] — all collections are generic; the type parameter directly affects internal memory layout
- [[2.28 — Equality and Comparison]] — Dictionary and HashSet correctness depends entirely on the GetHashCode contract
- [[2.41 — Performance: Zero-Allocation Patterns]] — CollectionsMarshal.AsSpan(list) for zero-copy List<T> iteration
```

**Key topics inside this note:** Dictionary<K,V> internals (bucket array + entry array, hash → bucket index → chain, load factor 0.72, resize doubles capacity), List<T> internals (backing array, doubling-on-resize, capacity pre-sizing). HashSet<T> (same as Dictionary without values). SortedDictionary<K,V> (red-black tree, O(log n) operations). Queue<T> (circular buffer array). Stack<T>. PriorityQueue<TElement,TPriority> (min-heap, .NET 6+). ConcurrentDictionary<K,V> (striped locking, GetOrAdd with Lazy<T> pattern). ImmutableDictionary<K,V> (builder pattern). FrozenDictionary<K,V> (.NET 8, read-only ultra-fast lookup). CollectionsMarshal.GetValueRefOrAddDefault. Selection guide with Big-O table.

---

### 2.35 — Strings: Internals and High-Performance Operations

**TOPIC_ID:** `2.35` **TOPIC_NAME:** `Strings: Internals and High-Performance Operations` **RELATED_TOPICS:**

```
- [[2.14 — String Fundamentals]] — direct prerequisite; this note extends 2.14 with internals and performance
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — string.AsSpan() and ReadOnlySpan<char> are the primary zero-alloc string tools
- [[2.41 — Performance: Zero-Allocation Patterns]] — string.Create, TryFormat, and avoiding string allocations
- [[2.52 — Source Generators]] — [GeneratedRegex] generates a compile-time regex state machine (zero runtime overhead)
```

**Key topics inside this note:** string memory layout (object header + length field + chars[] embedded inline — no separate heap array). String interning and the intern pool (when to use it, when it causes memory leaks). string.Create<TState> for single-allocation building. string.GetHashCode() per-process randomization (why you cannot persist or serialize it). StringBuilder vs string.Create vs string.Join performance hierarchy. ReadOnlySpan<char> for zero-copy tokenizing and parsing. ReadOnlyMemory<char> for async patterns. Ordinal vs linguistic comparisons and the Turkish I problem. Deterministic stable hashing (FNV-1a pattern). u8 literal suffix (C# 11, UTF-8 bytes).

---

### 2.36 — Exception Handling: Production Patterns

**TOPIC_ID:** `2.36` **TOPIC_NAME:** `Exception Handling: Production Patterns` **RELATED_TOPICS:**

```
- [[2.15 — Exception Handling: Fundamentals]] — direct prerequisite; this note extends 2.15 with advanced patterns
- [[2.29 — async/await: The State Machine]] — AggregateException from Task.WhenAll; async exception propagation mechanics
- [[2.30 — IDisposable and Resource Management]] — finally blocks and Dispose interaction in exception paths
- [[2.18 — Nullable Types]] — null guard patterns as exception prevention at boundaries, not handling after the fact
```

**Key topics inside this note:** two-pass exception handling model (find handler pass → unwind stack pass — why when filter sees original call site). ExceptionDispatchInfo for cross-thread rethrowing with original stack trace preserved. Exception hierarchy design for domain exceptions (properties over message strings, hierarchy over catch-all). AggregateException.Flatten() and Handle(). Retry pattern with exponential backoff using when filter. OperationCanceledException special status in async flows. AppDomain.UnhandledException and TaskScheduler.UnobservedTaskException. When to use Result<T> vs exceptions (exceptional vs expected failure). Exception filter logging pattern.

---

### 2.37 — Virtual Dispatch, Polymorphism, and the CLR Object Model

**TOPIC_ID:** `2.37` **TOPIC_NAME:** `Virtual Dispatch, Polymorphism, and the CLR Object Model` **RELATED_TOPICS:**

```
- [[2.10 — Inheritance, Polymorphism, and the Object Hierarchy]] — direct prerequisite; this note explains the runtime mechanism behind 2.10
- [[2.11 — Interfaces and Abstract Classes]] — interface dispatch uses a separate table (IMT) from class virtual dispatch (vtable)
- [[2.16 — Value Types vs Reference Types]] — object header layout (sync block + type pointer) lives in this topic
- [[2.49 — Tiered Compilation, JIT Internals, and PGO]] — PGO uses type profile data from virtual calls to devirtualize them
```

**Key topics inside this note:** CLR object header layout (sync block index + method table pointer, 16-byte minimum object size). Method table (vtable) structure and how a virtual call works (load type pointer → load vtable slot → indirect call, ~3-5 ns). Interface method table (IMT) and how interface dispatch works (different from vtable, ~5-8 ns). JIT devirtualization — when the JIT turns a virtual call into a direct call (sealed type, provable type from PGO). sealed class and sealed method performance implication. Cost of virtual vs direct vs interface calls with numbers. Fragile base class problem. Abstract method slots. typeof() and GetType() at CLR level.

---

### 2.38 — Spans, Memory, and Zero-Copy Patterns

**TOPIC_ID:** `2.38` **TOPIC_NAME:** `Spans, Memory, and Zero-Copy Patterns` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — Span<T> is a ref struct (stack-only value type); these constraints flow from 2.16
- [[2.29 — async/await: The State Machine]] — Span<T> cannot cross await boundaries; Memory<T> is the async-safe alternative
- [[2.51 — Unsafe Code and Interop]] — Span<T> can wrap native (unmanaged) memory pointers safely
- [[2.41 — Performance: Zero-Allocation Patterns]] — Span<T> and ArrayPool<T> are the two primary zero-alloc tools
```

**Key topics inside this note:** Span<T> ref struct internals (managed pointer + length, stack-only). ReadOnlySpan<T>. Memory<T> (heap-compatible, can cross await). IMemoryOwner<T> and MemoryPool<T>. ArrayPool<T> for rental patterns (Shared pool vs custom). stackalloc with Span<T>. MemoryMarshal.Read<T> for zero-copy binary protocol parsing. MemoryMarshal.Cast for type-punning without unsafe. string.AsSpan() for zero-allocation string operations. u8 string literals (C# 11, ReadOnlySpan<byte> constant). Binary protocol parser pattern with no heap allocation.

---

### 2.39 — Threading Primitives

**TOPIC_ID:** `2.39` **TOPIC_NAME:** `Threading Primitives` **RELATED_TOPICS:**

```
- [[2.29 — async/await: The State Machine]] — async/await is for I/O-bound concurrency; threading primitives are for CPU-bound shared state
- [[2.16 — Value Types vs Reference Types]] — Interlocked operates on value types directly at the CPU instruction level; no boxing
- [[2.45 — Channels and Concurrent Pipelines]] — Channels replace most Monitor.Wait/Pulse producer-consumer patterns
- [[2.46 — TPL and PLINQ]] — Parallel.For internals use the thread pool, which threading primitives configure
```

**Key topics inside this note:** lock/Monitor mechanics (thin lock via sync block CAS, ~25 ns uncontended, ~1–10 μs contended). Monitor.Wait/Pulse/PulseAll for producer-consumer patterns. Interlocked operations (single atomic CPU instruction, ~5–10 ns, no lock needed). SemaphoreSlim for async-capable bounded concurrency. ReaderWriterLockSlim (multiple concurrent readers, exclusive writer). volatile keyword (memory visibility guarantee, NOT atomicity — the most misunderstood primitive). Thread.MemoryBarrier. CancellationTokenSource/CancellationToken internals (linked tokens, registration). System.Threading.Lock (C# 13). Deadlock detection patterns. Thread vs ThreadPool thread.

---

### 2.40 — GC Interaction, Finalizers, and WeakReference

**TOPIC_ID:** `2.40` **TOPIC_NAME:** `GC Interaction, Finalizers, and WeakReference` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — value types on the stack have zero GC cost; reference types do not
- [[2.30 — IDisposable and Resource Management]] — Dispose pattern, GC.SuppressFinalize, and the finalizer relationship
- [[2.41 — Performance: Zero-Allocation Patterns]] — GC pressure is the target of zero-alloc work; understanding GC is prerequisite
- [[2.51 — Unsafe Code and Interop]] — GC.AddMemoryPressure informs the GC about unmanaged allocations
```

**Key topics inside this note:** generational heap architecture (Gen0 ~4 MB, Gen1 ~32 MB, Gen2 unlimited, LOH ≥ 85,000 bytes, POH in .NET 5+). Object promotion lifecycle. Finalization queue and freachable queue (why finalized objects survive one extra GC collection). GC.SuppressFinalize() purpose (prevents unnecessary second collection). WeakReference<T>: does not prevent collection, TryGetTarget(). WeakCache<K,V> pattern for GC-managed caches. GC.AddMemoryPressure/RemoveMemoryPressure for unmanaged allocations. GCLatencyMode.SustainedLowLatency for real-time workloads. GC.RegisterForFullGCNotification for load balancer integration. GCSettings.LargeObjectHeapCompactionMode.

---

### 2.41 — Performance: Zero-Allocation Patterns

**TOPIC_ID:** `2.41` **TOPIC_NAME:** `Performance: Zero-Allocation Patterns` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — struct vs class is the foundation of zero-alloc design
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — Span<T> and ArrayPool<T> are the primary zero-alloc tools
- [[2.40 — GC Interaction, Finalizers, and WeakReference]] — understanding GC generations is the motivation for zero-alloc work
- [[2.35 — Strings: Internals and High-Performance Operations]] — string.Create, TryFormat, and string allocation avoidance
- [[2.48 — Benchmarking with BenchmarkDotNet]] — you cannot validate zero-alloc work without measuring it
```

**Key topics inside this note:** GC allocation budget model (Gen0 size, collection frequency, latency impact). Allocation sources to eliminate: string interpolation, boxing, LINQ iterators, params arrays, closures. ArrayPool<T> rental pattern. MemoryPool<T>. string.Create<TState> for single-pass string building. TryFormat/ISpanFormattable for zero-alloc formatting. CollectionsMarshal.AsSpan(list) for zero-copy List<T> iteration. ObjectPool<T> via Microsoft.Extensions.ObjectPool. [SkipLocalsInit] (eliminates stack zeroing). Struct-based parser state machine. Measuring with BenchmarkDotNet's Allocated column.

---

### 2.42 — Reflection

**TOPIC_ID:** `2.42` **TOPIC_NAME:** `Reflection` **RELATED_TOPICS:**

```
- [[2.32 — Attributes and Metadata]] — reflection is the runtime mechanism for reading attributes
- [[2.43 — Expression Trees]] — compiled expression trees replace reflection in hot paths (10–100× faster)
- [[2.52 — Source Generators]] — source generators eliminate reflection entirely for serializers and mappers
- [[2.17 — Generics]] — MakeGenericType and MakeGenericMethod are reflection operations on generic types
```

**Key topics inside this note:** reflection model hierarchy (Assembly → Module → Type → MemberInfo). Reflection invocation cost (~1–5 μs vs ~5–10 ns for compiled delegate). MethodInfo.Invoke vs compiled Expression.Lambda().Compile() caching pattern. Property getter/setter compiled delegate cache using ConcurrentDictionary. Generic mapper built from reflection + compiled delegates. Plugin loading via AssemblyLoadContext (isolation, unloadability). Type.GetCustomAttribute<T> and attribute inheritance. Why reflection breaks NativeAOT (and [DynamicallyAccessedMembers] as the fix). Reflection vs source generators decision.

---

### 2.43 — Expression Trees

**TOPIC_ID:** `2.43` **TOPIC_NAME:** `Expression Trees` **RELATED_TOPICS:**

```
- [[2.21 — Delegates, Func, Action, and Closures]] — Expression<Func<T,R>> vs Func<T,R>: same lambda syntax, different compilation target
- [[2.24 — LINQ: Execution Model]] — IQueryable<T> captures the LINQ chain as an expression tree for SQL translation
- [[2.42 — Reflection]] — expression trees compiled via Compile() are far faster than runtime reflection
- [[2.17 — Generics]] — generic expression tree construction and type parameters
```

**Key topics inside this note:** Expression<Func<T,R>> vs Func<T,R> compilation difference (data structure vs compiled IL). Expression tree node types: BinaryExpression, MemberExpression, ConstantExpression, ParameterExpression, MethodCallExpression. How EF Core translates Where(u => u.Age > 18) to a SQL WHERE clause. ExpressionVisitor for tree inspection and transformation. Specification pattern with composable expression trees (AndSpecification, OrSpecification). Building dynamic property getters/setters — compiled once, cached in ConcurrentDictionary. Expression.Lambda().Compile() vs reflection performance comparison. Expression tree limitations (no await, no statement blocks, no out/ref).

---

### 2.44 — Dynamic, the DLR, and Late Binding

**TOPIC_ID:** `2.44` **TOPIC_NAME:** `Dynamic, the DLR, and Late Binding` **RELATED_TOPICS:**

```
- [[2.42 — Reflection]] — dynamic is not reflection; DLR call site caching makes repeat calls faster than reflection
- [[2.10 — Inheritance]] — dynamic bypasses the CLR type system's vtable; uses DLR dispatch instead
- [[2.17 — Generics]] — generics resolve types at JIT time; dynamic resolves at runtime — the fundamental tradeoff
- [[2.08 — Classes]] — ExpandoObject implements IDynamicMetaObjectProvider and is the most common dynamic use case
```

**Key topics inside this note:** dynamic keyword and the DLR (Dynamic Language Runtime). Call site caching: why dynamic gets fast after first use (call site binder caches the resolved method). ExpandoObject for runtime property bags. DynamicObject for custom dynamic dispatch behavior. COM interop with dynamic (the original motivating use case — cleaner than object + reflection). dynamic vs object vs generics — when each is correct. Why dynamic does not box value types. NativeAOT and trimming incompatibility of dynamic. When not to use dynamic in production.

---

### 2.45 — Channels and Concurrent Pipelines

**TOPIC_ID:** `2.45` **TOPIC_NAME:** `Channels and Concurrent Pipelines` **RELATED_TOPICS:**

```
- [[2.29 — async/await: The State Machine]] — Channel reads/writes are async operations; the state machine drives pipeline stages
- [[2.39 — Threading Primitives]] — Channels replace BlockingCollection<T> which blocks OS threads; Channels do not
- [[2.46 — TPL and PLINQ]] — TPL Dataflow vs Channel-based pipelines: when to use each
- [[2.25 — Iterators and yield return]] — ChannelReader.ReadAllAsync() returns IAsyncEnumerable<T>
```

**Key topics inside this note:** Channel.CreateBounded<T> vs CreateUnbounded<T> (backpressure vs unlimited). BoundedChannelFullMode options (Wait, DropOldest, DropNewest, DropWrite). SingleWriter/SingleReader optimization hints. Multi-stage pipeline with bounded backpressure. Fan-out pub/sub pattern with per-subscriber channels. Complete() and graceful drain (writing side signals completion, reading side drains remaining items). ChannelReader<T>/ChannelWriter<T> as separate objects for access control. Comparison with BlockingCollection<T> and why Channels win on thread efficiency. When TPL Dataflow (TransformBlock, ActionBlock) is better than raw Channels.

---

### 2.46 — Task Parallel Library (TPL) and PLINQ

**TOPIC_ID:** `2.46` **TOPIC_NAME:** `Task Parallel Library (TPL) and PLINQ` **RELATED_TOPICS:**

```
- [[2.29 — async/await: The State Machine]] — async/await for I/O-bound; TPL for CPU-bound — this distinction is the entry point
- [[2.39 — Threading Primitives]] — TPL uses the thread pool internally; understanding the pool is prerequisite
- [[2.45 — Channels and Concurrent Pipelines]] — Channels vs TPL Dataflow: when each is the right tool
- [[2.24 — LINQ: Execution Model]] — PLINQ is AsParallel() on IEnumerable<T>; execution model differs from sequential LINQ
```

**Key topics inside this note:** Parallel.For with work-stealing scheduler. Parallel.ForEach with thread-local state accumulation pattern. Parallel.ForEachAsync (.NET 6+) for I/O-bound bounded parallelism. PLINQ: AsParallel(), AsOrdered(), WithDegreeOfParallelism, ForceParallelism, aggregation with seed factory and partition accumulators. Parallel.ForEach vs Task.WhenAll — CPU-bound vs I/O-bound decision. TPL Dataflow: TransformBlock, ActionBlock, BoundedCapacity for backpressure, LinkTo pipeline. Task.Factory.StartNew vs Task.Run (difference matters). When NOT to use TPL (tiny work items, heavy shared state, I/O-bound work).

---

### 2.47 — Dependency Injection Internals

**TOPIC_ID:** `2.47` **TOPIC_NAME:** `Dependency Injection Internals` **RELATED_TOPICS:**

```
- [[2.29 — async/await: The State Machine]] — async scope management with IServiceScope and CreateAsyncScope()
- [[2.43 — Expression Trees]] — the DI container compiles call-site expression trees at first resolve; ~50 ns per subsequent call
- [[2.42 — Reflection]] — DI uses reflection for initial service discovery at startup; then compiles to delegates
- [[2.30 — IDisposable and Resource Management]] — scopes are IDisposable; scoped service lifetime management
```

**Key topics inside this note:** service lifetimes (Singleton/Scoped/Transient) with captive dependency rule (Singleton consuming Scoped = silent bug). How BuildServiceProvider() compiles call-site expression trees for fast resolution. Scope validation in development mode (catches captive dependencies). IServiceScopeFactory for manual scope management in background workers. Registration patterns: TryAdd, factory registration, open generic registration, keyed services (.NET 8+). IOptions<T> vs IOptionsSnapshot<T> vs IOptionsMonitor<T>. Service locator anti-pattern. ActivatorUtilities for DI-aware construction outside the container.

---

### 2.48 — Benchmarking with BenchmarkDotNet

**TOPIC_ID:** `2.48` **TOPIC_NAME:** `Benchmarking with BenchmarkDotNet` **RELATED_TOPICS:**

```
- [[2.41 — Performance: Zero-Allocation Patterns]] — BenchmarkDotNet is the measurement tool for all zero-alloc work
- [[2.16 — Value Types vs Reference Types]] — struct vs class benchmarks are the most common BDN first examples
- [[2.35 — Strings: Internals and High-Performance Operations]] — string operation benchmarks are the most common real-world BDN use
- [[2.49 — Tiered Compilation, JIT Internals, and PGO]] — understanding JIT explains why warmup phases are mandatory in benchmarks
```

**Key topics inside this note:** benchmark lifecycle (pilot → warmup → target phases — why each is necessary). Dead code elimination and how to prevent it (return values, Consume). Loop hoisting and the [Params] solution. [MemoryDiagnoser] and what the Allocated column means. [DisassemblyDiagnoser] for reading generated assembly. [Baseline = true] for ratio columns. [SimpleJob] with RuntimeMoniker for multi-runtime comparison. StatisticColumn.P95 for tail latency reporting. Mean vs median vs P95 — when each matters. BDN anti-patterns: Debug mode, insufficient warmup, loaded machine, benchmarking I/O.

---

### 2.49 — Tiered Compilation, JIT Internals, and PGO

**TOPIC_ID:** `2.49` **TOPIC_NAME:** `Tiered Compilation, JIT Internals, and PGO` **RELATED_TOPICS:**

```
- [[2.01 — The .NET Platform]] — JIT compilation is the execution layer of the CLR; this topic is its deep dive
- [[2.37 — Virtual Dispatch and the CLR Object Model]] — PGO uses type profiles from virtual calls to devirtualize them in Tier 1
- [[2.48 — Benchmarking with BenchmarkDotNet]] — tiered compilation explains why BDN warmup phases are mandatory
- [[2.41 — Performance: Zero-Allocation Patterns]] — JIT optimizations (escape analysis, stack elision) affect allocation behavior
```

**Key topics inside this note:** Tier 0 compilation (quick, unoptimized, call count instrumentation inserted). Tier 1 recompilation (full optimization after call count threshold, ~30 calls). Dynamic Profile-Guided Optimization (PGO, .NET 7+) — collects branch, type, and call frequency profiles, feeds into Tier 1 recompile. JIT inlining decisions and [MethodImpl(AggressiveInlining/NoInlining)]. Devirtualization from PGO type profiles. Loop unrolling. Escape analysis and stack allocation elision. ReadyToRun (R2R) ahead-of-time compilation. [MethodImpl(NoOptimization)] for preventing JIT interference in tests. Tiered compilation behavior in benchmarks.

---

### 2.50 — Advanced Async Patterns: ValueTask, Custom Awaitables, and Async Streams

**TOPIC_ID:** `2.50` **TOPIC_NAME:** `Advanced Async Patterns: ValueTask, Custom Awaitables, and Async Streams` **RELATED_TOPICS:**

```
- [[2.29 — async/await: The State Machine]] — direct prerequisite; this topic extends 2.29 into advanced territory
- [[2.25 — Iterators and yield return]] — async iterators combine yield return + await into IAsyncEnumerable<T>
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — Memory<T> as the async-compatible alternative to Span<T>
- [[2.41 — Performance: Zero-Allocation Patterns]] — ValueTask<T> is the primary tool for zero-allocation async hot paths
```

**Key topics inside this note:** ValueTask<T> allocation model (zero allocation when result is synchronous, one Task when truly async). ManualResetValueTaskSourceCore<T> for pooled awaitable objects. Custom awaiter protocol: GetAwaiter(), IsCompleted property, OnCompleted(Action), GetResult(). INotifyCompletion vs ICriticalNotifyCompletion (security context). IAsyncEnumerable<T> composition and chaining patterns. [EnumeratorCancellation] attribute on async iterators. ConfigureAwait on await foreach. Async streams with yield return + await combined. Cancellation propagation in async streams.

---

### 2.51 — Unsafe Code and Interop

**TOPIC_ID:** `2.51` **TOPIC_NAME:** `Unsafe Code and Interop` **RELATED_TOPICS:**

```
- [[2.16 — Value Types vs Reference Types]] — blittable value types are the currency of P/Invoke interop
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — Span<T> over native memory uses unsafe mechanics under the hood
- [[2.40 — GC Interaction, Finalizers, and WeakReference]] — GCHandle.Alloc, pinning, and why heap pinning causes fragmentation
```

**Key topics inside this note:** fixed statement and stack/heap pinning. GCHandle for long-term pinning (and the fragmentation cost). P/Invoke with [LibraryImport] (modern, source-generated, C# 11) vs [DllImport] (legacy). [StructLayout(LayoutKind.Sequential)] for interop structs. Blittable vs non-blittable types (what can be passed directly vs what requires marshaling). SafeHandle vs raw IntPtr (always prefer SafeHandle). Pointer arithmetic with unsafe blocks. MemoryMarshal.Cast<TFrom,TTo> for type-punning. MemoryMarshal.Read<T> for binary parsing. GC.AddMemoryPressure for unmanaged allocations. SIMD and hardware intrinsics: Vector<T> and Vector256<T>.

---

### 2.52 — Source Generators

**TOPIC_ID:** `2.52` **TOPIC_NAME:** `Source Generators` **RELATED_TOPICS:**

```
- [[2.32 — Attributes and Metadata]] — source generators are triggered by attribute inspection at compile time
- [[2.42 — Reflection]] — source generators eliminate the runtime cost of reflection in serializers and mappers
- [[2.29 — async/await: The State Machine]] — the async state machine is compiler-generated code (analogous pattern)
- [[2.53 — Native AOT, Trimming, and Publish-Time Constraints]] — source generators are the primary path to AOT-compatible code
```

**Key topics inside this note:** compilation pipeline and where generators run. Incremental generators vs v1 generators (performance difference — incremental caches nodes). [JsonSerializable] for System.Text.Json (AOT-safe, 3–5× faster serialization). [GeneratedRegex] (compile-time regex state machine, zero runtime JIT cost). [LoggerMessage] (zero-allocation structured logging). Reading the Roslyn semantic model in a generator (SyntaxProvider, semantic model queries). IncrementalValueProvider and pipeline composition. Output file naming conventions. Debugging generators with launch settings. AOT compatibility requirements.

---

### 2.53 — Native AOT, Trimming, and Publish-Time Constraints

**TOPIC_ID:** `2.53` **TOPIC_NAME:** `Native AOT, Trimming, and Publish-Time Constraints` **RELATED_TOPICS:**

```
- [[2.42 — Reflection]] — reflection breaks Native AOT; this topic explains how to annotate or eliminate it
- [[2.52 — Source Generators]] — source generators replace runtime reflection with compile-time code generation for AOT scenarios
- [[2.49 — Tiered Compilation, JIT Internals, and PGO]] — Native AOT replaces the JIT entirely with a static ahead-of-time compiler
- [[2.32 — Attributes and Metadata]] — [DynamicallyAccessedMembers] and [RequiresDynamicCode] are attributes that guide the trimmer
```

**Key topics inside this note:** Native AOT compilation model (no JIT, no runtime code generation, single self-contained binary). IL trimming (removes unreachable code at publish time, reduces binary size). [DynamicallyAccessedMembers] to tell the trimmer which types must be preserved for reflection. [RequiresDynamicCode] to mark APIs unsafe for AOT. What breaks in AOT: Reflection.Emit, dynamic, certain serializers, Type.MakeGenericType with runtime types. Source-generated System.Text.Json as the AOT-safe serialization path. PublishAot and PublishTrimmed MSBuild properties. When to use AOT: microservices, serverless (cold start), CLI tools, WebAssembly. Startup time and binary size comparison.

---

### 2.54 — C# Language Features Cheatsheet (C# 9–13)

**TOPIC_ID:** `2.54` **TOPIC_NAME:** `C# Language Features Cheatsheet (C# 9–13)` **RELATED_TOPICS:**

```
- [[2.19 — Records]] — records were introduced in C# 9; record struct in C# 10
- [[2.16 — Value Types vs Reference Types]] — record struct (C# 10), ref struct generics (C# 13 allows ref struct)
- [[2.38 — Spans, Memory, and Zero-Copy Patterns]] — collection expressions with Span (C# 12), params ReadOnlySpan<T> (C# 13)
- [[2.39 — Threading Primitives]] — System.Threading.Lock was introduced in C# 13
```

**Key topics inside this note:** C# 9: records, init-only setters, target-typed new(), covariant return types, pattern matching enhancements (relational, logical), top-level statements, nint/nuint. C# 10: global using, file-scoped namespace, constant interpolated strings, extended property patterns, lambda natural types, record struct, with on structs. C# 11: required members, raw string literals, generic attributes, list patterns, static abstract interface members, params Span<T>, ref fields in ref structs, file-scoped types, [StringSyntax]. C# 12: collection expressions, spread operator (..), primary constructors on classes, inline arrays, default lambda parameters, ref readonly parameters, alias any type. C# 13: params ReadOnlySpan<T>, allows ref struct, System.Threading.Lock, partial properties, field keyword in accessors.

---

## GENERATION ORDER (Recommended)

If you have 2+ years of production C# experience, start at Tier 1 and skip Level 1. If you are newer to C#, generate Level 1 topics (2.01–2.15) in order first.

```
── LEVEL 1 — FOUNDATIONS (generate if new to C# or want complete coverage) ──

[ ] 2.01    The .NET Platform: CLR, SDK, Runtimes, and the Compilation Pipeline
[ ] 2.02    C# Program Structure: Syntax, Namespaces, and Project Files
[ ] 2.03    Data Types, Literals, and Type Conversions
[ ] 2.04    Variables, Constants, and Scope
[ ] 2.05    Operators: Complete Reference
[ ] 2.06    Control Flow: Conditionals, Loops, and Branching
[ ] 2.07    Methods: Signatures, Parameters, Overloading, and Local Functions
[ ] 2.08    Classes: Fields, Constructors, Static Members, and Object Initialization
[ ] 2.09    Properties, Indexers, and Access Modifiers
[ ] 2.10    Inheritance, Polymorphism, Casting, and the Object Hierarchy
[ ] 2.11    Interfaces and Abstract Classes
[ ] 2.12    Enums and Structs: Fundamentals
[ ] 2.13    Arrays and Collection Basics
[ ] 2.14    String Fundamentals: Methods, Formatting, and StringBuilder
[ ] 2.15    Exception Handling: Fundamentals

── TIER 1 — Interview + Production Critical ──

[✅] 2.16   Value Types vs Reference Types: Deep Mechanics
[ ] 2.17    Generics: Constraints, Reification, and the Type System
[ ] 2.23    LINQ: Every Operator Reference
[ ] 2.24    LINQ: Execution Model, Deferred Evaluation, and IQueryable
[ ] 2.29    async/await: The State Machine
[ ] 2.37    Virtual Dispatch, Polymorphism, and the CLR Object Model
[ ] 2.34    Collections: Internals and Selection Guide
[ ] 2.39    Threading Primitives

── TIER 2 — Daily Production + High Interview Value ──

[ ] 2.18    Nullable Types: Nullable<T> and Nullable Reference Types
[ ] 2.21    Delegates, Func, Action, and Closures
[ ] 2.27    Tuples, ValueTuple, and Deconstruction
[ ] 2.28    Equality and Comparison
[ ] 2.30    IDisposable, IAsyncDisposable, and Resource Management
[ ] 2.36    Exception Handling: Production Patterns
[ ] 2.38    Spans, Memory, and Zero-Copy Patterns
[ ] 2.40    GC Interaction, Finalizers, and WeakReference
[ ] 2.41    Performance: Zero-Allocation Patterns

── TIER 3 — Core Language Completion ──

[ ] 2.19    Records
[ ] 2.20    Pattern Matching
[ ] 2.22    Events and the Event Pattern
[ ] 2.25    Iterators and yield return
[ ] 2.26    Extension Methods and Fluent APIs
[ ] 2.31    Operator Overloading and Conversions
[ ] 2.32    Attributes and Metadata
[ ] 2.33    Generics: Variance, Generic Math, and Advanced Patterns
[ ] 2.35    Strings: Internals and High-Performance Operations
[ ] 2.42    Reflection
[ ] 2.43    Expression Trees
[ ] 2.44    Dynamic, the DLR, and Late Binding
[ ] 2.45    Channels and Concurrent Pipelines
[ ] 2.46    Task Parallel Library (TPL) and PLINQ

── TIER 4 — Advanced and Specialist ──

[ ] 2.47    Dependency Injection Internals
[ ] 2.48    Benchmarking with BenchmarkDotNet
[ ] 2.49    Tiered Compilation, JIT Internals, and PGO
[ ] 2.50    Advanced Async Patterns: ValueTask, Custom Awaitables, Async Streams
[ ] 2.51    Unsafe Code and Interop
[ ] 2.52    Source Generators
[ ] 2.53    Native AOT, Trimming, and Publish-Time Constraints
[ ] 2.54    C# Language Features Cheatsheet (C# 9–13)
```

---

_Last updated: 2026-06 · Domain: C# Language Mastery · File: Topic Index v2 — Full Curriculum (54 topics)_ _Tags: #index #csharp #engineering #study-system_
