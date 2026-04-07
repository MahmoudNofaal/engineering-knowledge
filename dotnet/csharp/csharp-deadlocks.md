# C# Deadlocks

> A deadlock is a permanent standstill where two or more threads each hold a resource the other needs — none can proceed, the application hangs silently.

---

## Quick Reference

| Deadlock type | Classic cause | Fix |
|---|---|---|
| Lock ordering | Thread A holds L1, waits for L2; Thread B holds L2, waits for L1 | Consistent lock order |
| `async`/`sync` blocking | `.Result` / `.Wait()` on `Task` with `SynchronizationContext` | Always `await` |
| Re-entry | Single-thread semaphore waiting on itself | Re-entrant lock or `AsyncLocal` guard |

---

## Core Concept

A deadlock requires four conditions simultaneously: mutual exclusion, hold and wait, no preemption, and circular wait. Eliminating any one breaks the deadlock. In practice, you target **circular wait** (consistent lock ordering) and **hold and wait** (acquire all resources atomically or release before waiting).

The async/await deadlock is the most common in .NET: calling `.Result` or `.Wait()` on a `Task` in an environment with a `SynchronizationContext` (WPF, WinForms, classic ASP.NET) blocks the context thread; the awaiting continuation needs to resume on that thread; neither can proceed.

---

## The Code

**Lock ordering deadlock — and the fix**
```csharp
// DEADLOCK: Thread A locks accountA then waits for accountB
//           Thread B locks accountB then waits for accountA
void TransferBad(Account from, Account to, decimal amount)
{
    lock (from) { lock (to) { from.Balance -= amount; to.Balance += amount; } }
}

// FIX: always lock in a consistent order — e.g. lower Id first
void TransferSafe(Account from, Account to, decimal amount)
{
    var first  = from.Id < to.Id ? from : to;
    var second = from.Id < to.Id ? to   : from;
    lock (first) { lock (second) { from.Balance -= amount; to.Balance += amount; } }
}
```

**Async/sync deadlock — `.Result` with SynchronizationContext**
```csharp
// DEADLOCK in WinForms/WPF or classic ASP.NET:
// The UI thread calls .Result, blocking it.
// The continuation from GetDataAsync needs to resume on the UI thread.
// The UI thread is blocked waiting for the completion — deadlock.
string data = GetDataAsync().Result; // DEADLOCK in UI context

// FIX 1: always async all the way — never mix sync blocking and async
string data = await GetDataAsync();

// FIX 2: ConfigureAwait(false) in library code avoids capturing UI context
async Task<string> GetDataAsync()
    => await HttpClient.GetStringAsync("https://...").ConfigureAwait(false);
```

**Detecting with timeout**
```csharp
// Add timeouts to detect deadlocks during development
if (!Monitor.TryEnter(lockObj, TimeSpan.FromSeconds(5)))
    throw new TimeoutException("Potential deadlock: could not acquire lock within 5s");
```

---

## Gotchas

- **`await task.ConfigureAwait(false)` in library code prevents the common async deadlock** by not capturing the calling `SynchronizationContext` — the continuation resumes on any thread pool thread.
- **ASP.NET Core has no `SynchronizationContext`** — `.Result` won't cause the classic async deadlock there. But it still blocks a thread pool thread unnecessarily.
- **`lock` allows re-entry by the same thread** (re-entrant). `SemaphoreSlim(1,1)` does not — the same thread calling `WaitAsync` twice deadlocks itself.

---

## Interview Angle

**What they're really testing:** Whether you can diagnose and fix the async deadlock — the most common production deadlock in .NET.

**Common question forms:**
- "What is a deadlock and how do you prevent one?"
- "Why does `.Result` sometimes deadlock?"

**The depth signal:** A senior describes the `.Result`/`SynchronizationContext` deadlock mechanically — context thread blocked by `.Result`, continuation waiting for context thread — and prescribes "async all the way" as the fix.

---

## Related Topics

- [[dotnet/csharp/csharp-lock-mutex.md]] — Lock ordering is the primary tool for preventing lock-based deadlocks
- [[dotnet/csharp/csharp-async-await.md]] — "Async all the way" is the fix for async/sync deadlocks

---

## Source

[Deadlocks — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/threading/managed-threading-best-practices)

---
*Last updated: 2026-04-06*