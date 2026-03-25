# Redis Distributed Lock

> A mechanism for ensuring only one process across multiple machines can execute a critical section at a time, implemented using Redis's atomic SET NX command and the Redlock algorithm.

---

## When To Use It

Use a distributed lock when you have multiple application instances (horizontal scaling) and need to guarantee that exactly one of them executes a piece of code at a time — payment processing, inventory decrement, scheduled job execution, or any operation where running twice causes data corruption. Don't use it as a substitute for database transactions when the work you're protecting is purely database operations — a DB transaction with proper isolation is stronger and simpler. Distributed locks are for coordinating across processes, not for replacing ACID guarantees.

---

## Core Concept

A distributed lock has three requirements: only one owner at a time, automatic release if the owner crashes (TTL), and only the owner can release it. The naive `SETNX` + `EXPIRE` implementation looks correct but isn't — between the two commands, the process can crash leaving no TTL and a permanent lock. The fix is a single atomic `SET key value NX EX ttl` command. The release problem is subtler: if you just `DEL` the key, you might delete a lock owned by a different process that acquired it after yours expired. The fix is a Lua script that checks ownership before deleting — atomically. Redlock extends this to multiple Redis nodes for failure tolerance, at significant added complexity.

---

## The Code

**Single-node lock — production correct**
```csharp
using StackExchange.Redis;
using System;

public class RedisLockManager
{
    private readonly IDatabase _db;
    private const string UNLOCK_SCRIPT = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";

    public RedisLockManager(IDatabase db)
    {
        _db = db;
    }

    /// <summary>
    /// Returns a lock token if acquired, null if not.
    /// ttl: seconds before lock auto-releases (must exceed critical section duration)
    /// </summary>
    public string? AcquireLock(string resource, int ttl = 10)
    {
        string token = Guid.NewGuid().ToString();
        string key = $"lock:{resource}";

        // SET NX EX is atomic — no gap between existence check and TTL set
        bool acquired = _db.StringSet(key, token, TimeSpan.FromSeconds(ttl), When.NotExists);
        return acquired ? token : null;
    }

    /// <summary>
    /// Only releases the lock if we still own it.
    /// Returns true if released, false if already expired or stolen.
    /// </summary>
    public bool ReleaseLock(string resource, string token)
    {
        string key = $"lock:{resource}";
        var result = _db.ScriptEvaluate(UNLOCK_SCRIPT, new RedisKey[] { key }, new RedisValue[] { token });
        return (int)result > 0;
    }
}

// Usage — manual
var db = ConnectionMultiplexer.Connect("localhost:6379").GetDatabase();
var lockMgr = new RedisLockManager(db);
string? token = lockMgr.AcquireLock("payment:user:42", ttl: 15);
if (token == null)
    throw new Exception("Could not acquire lock — another process holds it");
try
{
    // ProcessPayment();
}
finally
{
    lockMgr.ReleaseLock("payment:user:42", token);
}
```

**Context manager — cleaner usage**
```csharp
using System;
using StackExchange.Redis;

public class RedisLock : IDisposable
{
    private readonly RedisLockManager _lockMgr;
    private readonly string _resource;
    private readonly int _ttl;
    private string? _token;

    public RedisLock(RedisLockManager lockMgr, string resource, int ttl = 10)
    {
        _lockMgr = lockMgr;
        _resource = resource;
        _ttl = ttl;
    }

    public void Acquire(int retries = 3, float delay = 0.1f)
    {
        for (int attempt = 0; attempt < retries; attempt++)
        {
            _token = _lockMgr.AcquireLock(_resource, _ttl);
            if (_token != null)
                return;
            System.Threading.Thread.Sleep((int)(delay * (attempt + 1) * 1000));
        }
        throw new TimeoutException($"Failed to acquire lock for: {_resource}");
    }

    public void Dispose()
    {
        if (_token != null)
            _lockMgr.ReleaseLock(_resource, _token);
    }
}

// Usage
var lockMgr = new RedisLockManager(db);
using (var @lock = new RedisLock(lockMgr, "inventory:item:88", ttl: 10))
{
    @lock.Acquire();
    // DecrementInventory(itemId: 88);
}
```

**Watchdog — extend TTL if work takes longer than expected**
```csharp
using StackExchange.Redis;
using System;
using System.Threading;

public class WatchdogLock
{
    private readonly IDatabase _db;
    private string _key;  
    private int _ttl;
    private string? _token;
    private readonly CancellationTokenSource _cts = new CancellationTokenSource();
    private Thread? _watchdogThread;
    private const string UNLOCK_SCRIPT = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";

    public WatchdogLock(IDatabase db, string resource, int ttl = 10)
    {
        _db = db;
        _key = $"lock:{resource}";
        _ttl = ttl;
    }

    public bool Acquire()
    {
        _token = Guid.NewGuid().ToString();
        bool acquired = _db.StringSet(_key, _token, TimeSpan.FromSeconds(_ttl), When.NotExists);
        if (acquired)
            StartWatchdog();
        return acquired;
    }

    private void StartWatchdog()
    {
        void Renew()
        {
            // Renew at 1/3 of TTL interval so there's always headroom
            int interval = _ttl / 3;
            while (!_cts.Token.WaitHandle.WaitOne(interval * 1000))
            {
                // Only extend if we still own the lock
                var current = _db.StringGet(_key);
                if (current == _token)
                    _db.KeyExpire(_key, TimeSpan.FromSeconds(_ttl));
                else
                    break;  // lock was lost — stop renewing
            }
        }
        _watchdogThread = new Thread(Renew) { IsBackground = true };
        _watchdogThread.Start();
    }

    public void Release()
    {
        _cts.Cancel();
        if (_token != null)
        {
            var result = _db.ScriptEvaluate(UNLOCK_SCRIPT, new RedisKey[] { _key }, new RedisValue[] { _token });
        }
    }
}
```

**Redlock — multi-node lock for failure tolerance**
```csharp
using StackExchange.Redis;
using System;
using System.Collections.Generic;
using System.Diagnostics;

public class RedlockManager
{
    private readonly IDatabase[] _nodes;
    private const string UNLOCK_SCRIPT = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";

    public RedlockManager(params IDatabase[] dbs)
    {
        _nodes = dbs;
    }

    public (string token, int validityMs)? AcquireLock(string resource, int ttl = 10)
    {
        string token = Guid.NewGuid().ToString();
        string key = $"lock:{resource}";
        int quorum = _nodes.Length / 2 + 1;
        int acquired = 0;
        var sw = Stopwatch.StartNew();

        foreach (var node in _nodes)
        {
            try
            {
                if (node.StringSet(key, token, TimeSpan.FromSeconds(ttl), When.NotExists))
                    acquired++;
            }
            catch (Exception)
            {
                // treat node failure as a non-acquire
            }
        }

        sw.Stop();
        int validityMs = ttl * 1000 - (int)sw.ElapsedMilliseconds;

        if (acquired >= quorum && validityMs > 0)
            return (token, validityMs);  // lock held with remaining validity time

        // Failed to get quorum — release whatever we did acquire
        ReleaseLock(resource, token);
        return null;
    }

    public void ReleaseLock(string resource, string token)
    {
        string key = $"lock:{resource}";
        foreach (var node in _nodes)
        {
            try
            {
                node.ScriptEvaluate(UNLOCK_SCRIPT, new RedisKey[] { key }, new RedisValue[] { token });
            }
            catch (Exception)
            {
                // best effort — TTL will clean up
            }
        }
    }
}
```

**What goes wrong — failure scenarios in code**
```csharp
// WRONG: two separate commands — crash between them = permanent lock
db.StringSet("lock:payments", token);    // acquires
db.KeyExpire("lock:payments", TimeSpan.FromSeconds(10));  // crash here → lock never expires

// WRONG: DEL without ownership check — deletes another owner's lock
db.KeyDelete("lock:payments");  // dangerous if our TTL already expired

// WRONG: checking then deleting — race between check and delete
var val = db.StringGet("lock:payments");
if (val == token)
{
    // another process could acquire here
    db.KeyDelete("lock:payments");  // we just deleted their lock
}

// CORRECT: atomic SET NX EX + Lua release (shown above)
```

---

## Gotchas

- **TTL shorter than critical section = two owners simultaneously.** If payment processing takes 12 seconds and TTL is 10, the lock expires and another process acquires it while you're still running. Either use a watchdog to extend TTL, or set TTL to the worst-case execution time plus a safety margin.
- **Redlock is controversial.** Martin Kleppmann argued that Redlock is unsafe under process pauses (GC, VM suspension) — the lock can expire while the process is paused, another acquires it, then the first resumes and both think they hold it. The fix is a fencing token (monotonic counter) that the downstream resource validates. If you need that level of correctness, use ZooKeeper or etcd instead.
- **Redis failover breaks single-node lock guarantees.** If a Redis master fails before replicating the lock key to the replica, and the replica is promoted, the lock is gone — another process can acquire it. Redlock was designed to address this but carries its own tradeoffs (see above).
- **Never use `KEYS lock:*` to inspect locks in production.** It blocks Redis for the duration of the full keyspace scan. Use `SCAN` with a match pattern instead.
- **Clock drift matters in Redlock.** Redlock subtracts elapsed acquisition time from the validity window to account for drift, but significant clock skew between nodes can still cause the calculated validity to be wrong. Keep NTP synchronized across all Redis nodes.

---

## Interview Angle

**What they're really testing:** Whether you understand the failure modes of distributed systems and can reason about atomicity, TTL, and split-brain scenarios.

**Common question form:** *"How would you implement a distributed lock?"* or *"What happens if the process holding a lock crashes?"* or *"Is Redlock safe?"*

**The depth signal:** A junior says "use SETNX and set a TTL." A senior explains why those must be a single atomic command, why release needs a Lua script (check-and-delete atomicity), what happens when the TTL is shorter than the work (two owners), and what happens on Redis failover (replica promotion loses the key). At the senior+ level: they know Kleppmann's critique of Redlock — that a GC pause can cause a process to resume after its lock expired and proceed anyway — and that the real solution is a fencing token validated by the protected resource, not just the lock itself.

---

## Related Topics

- [[databases/redis-fundamentals.md]] — SET NX EX, Lua scripting, and TTL mechanics that the lock is built on.
- [[databases/redis-patterns.md]] — The lock pattern in context alongside rate limiting, caching, and queues.
- [[system-design/distributed-locks.md]] — Fencing tokens, ZooKeeper vs Redis tradeoffs, and when you need stronger guarantees than Redlock.
- [[databases/mvcc-and-isolation-levels.md]] — Understanding what DB transactions give you clarifies when a distributed lock is actually needed vs. when a serializable transaction suffices.

---

## Source

[Martin Kleppmann — How to do distributed locking](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)

---
*Last updated: 2026-03-24*