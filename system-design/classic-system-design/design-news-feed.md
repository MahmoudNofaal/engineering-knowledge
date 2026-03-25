# News Feed

> A personalized, reverse-chronological (or ranked) stream of posts from accounts a user follows.

---

## When To Use It

Build a dedicated news feed system when your social platform needs to serve a personalized stream to millions of users with low latency. This doesn't apply to simple "all posts" timelines with no social graph — that's just a sorted DB query. The design challenge is fan-out: when a user with millions of followers posts, how do you get that post into every follower's feed fast enough that it feels real-time?

---

## Core Concept

There are two fundamental approaches: **fan-out on write** (push model) and **fan-out on read** (pull model). Fan-out on write: when a post is created, immediately write it to every follower's pre-computed feed in cache. Feed reads are instant — just fetch the cache. Fan-out on read: store nothing upfront; when a user opens their feed, query the social graph in real time and merge posts from everyone they follow. The first approach is fast for reads but explodes on writes for celebrities. The second is cheap on writes but slow on reads. Production systems (Twitter, Facebook) use a hybrid: push for normal users, pull for celebrities (high follower-count accounts).

---

## The Code

```csharp
// Fan-out on write worker
// Triggered when a user creates a new post

using StackExchange.Redis;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;

public class FeedFanOutService
{
    private readonly IDatabase _redis;
    private const int MaxFeedSize = 500;

    public async Task FanOutPostAsync(Post post, List<int> followerIds)
    {
        // post = { post_id: 101, author_id: 42, content: "...", created_at: 1711234567 }
        // Writes the post_id into every follower's feed list in Redis.
        
        var transaction = _redis.CreateTransaction();
        foreach (int followerId in followerIds)
        {
            string feedKey = $"feed:{followerId}";
            // LPUSH = prepend (newest first), LTRIM = cap feed at max_feed_size
            transaction.ListLeftPushAsync(feedKey, post.PostId.ToString());
            transaction.ListTrimAsync(feedKey, 0, MaxFeedSize - 1);
        }
        await transaction.ExecuteAsync();  // Single round-trip to Redis
    }
}

public class Post
{
    public int PostId { get; set; }
    public int AuthorId { get; set; }
    public string Content { get; set; }
    public long CreatedAt { get; set; }
}
```

```csharp
// Feed read — hydrate post IDs from cache into full post objects

using StackExchange.Redis;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;

public class FeedReadService
{
    private readonly IDatabase _redis;
    private readonly IPostRepository _db;

    public async Task<List<Post>> GetFeedAsync(int userId, int page = 0, int pageSize = 20)
    {
        string feedKey = $"feed:{userId}";
        int start = page * pageSize;
        int end = start + pageSize - 1;

        // Fetch post IDs from user's pre-built feed list
        var postIdValues = _redis.ListRange(feedKey, start, end);
        if (postIdValues.Length == 0)
            return new List<Post>();

        // Batch fetch post details (from cache or DB)
        var posts = new List<Post>();
        foreach (var idValue in postIdValues)
        {
            if (int.TryParse(idValue.ToString(), out int postId))
            {
                var postData = _redis.StringGet($"post:{postId}");
                if (postData.HasValue)
                    posts.Add(JsonSerializer.Deserialize<Post>(postData.ToString())!);
            }
        }
        return posts;
    }
}
```

```csharp
// Hybrid approach: skip fan-out for celebrities (high follower count)
// Their posts are injected at read time instead

using StackExchange.Redis;
using System.Collections.Generic;
using System.Threading.Tasks;

public class HybridFeedService
{
    private const int CelebrityThreshold = 1_000_000;  // followers
    private readonly IDatabase _redis;
    private readonly IPostRepository _db;

    public async Task<int> CreatePostAsync(
        int authorId,
        string content,
        List<int> followerIds)
    {
        int postId = await _db.InsertPostAsync(authorId, content);

        int followerCount = followerIds.Count;
        if (followerCount < CelebrityThreshold)
        {
            // Normal user: fan out immediately
            await FanOutPostAsync(
                new Post { PostId = postId, AuthorId = authorId },
                followerIds
            );
        }
        else
        {
            // Celebrity: skip fan-out, inject at read time
            // Just cache the post object; feed reads will pull it on demand
            var post = await _db.GetPostAsync(postId);
            _redis.StringSet($"post:{postId}", System.Text.Json.JsonSerializer.Serialize(post));
        }

        return postId;
    }

    private async Task FanOutPostAsync(Post post, List<int> followerIds)
    {
        // Implementation from FanOutPostAsync above
        await Task.CompletedTask;
    }
}
```

```sql
-- Core tables for a news feed backend
CREATE TABLE posts (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    author_id   BIGINT NOT NULL,
    content     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_author_created (author_id, created_at DESC)
);

CREATE TABLE follows (
    follower_id BIGINT NOT NULL,
    followee_id BIGINT NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, followee_id),
    INDEX idx_followee (followee_id)  -- Needed for fan-out lookups
);
```

---

## Gotchas

- **Feed cache is eventually consistent**: After fan-out, a follower's cached feed may show a post out of order if the worker lags. Design the UI to tolerate this — show "new posts available" rather than live-sorting the feed client-side.
- **LTRIM loses old posts silently**: Capping the feed list at 500 means users who scroll deep either see nothing or fall through to a DB query. Design a fallback: if cache miss, load from DB and backfill.
- **Unfollowing is hard**: When user A unfollows user B, you don't retroactively remove B's posts from A's cached feed. The feed just naturally ages out. This is usually acceptable, but document it as a known behavior.
- **The celebrity edge case is the main design question**: If you don't mention the hybrid push/pull approach in an interview, you've missed the core of the problem. Sending to 10M follower queues synchronously on post creation will take minutes.
- **Feed ranking vs chronological**: Adding a ranking model (ML-based relevance scoring) changes the architecture significantly — you can no longer just LPUSH; you need scored sets (Redis ZADD) and more complex merging logic.

---

## Interview Angle

**What they're really testing:** Fan-out tradeoffs, the social graph data model, and caching strategy for read-heavy personalized content.

**Common question form:** "Design a news feed for a platform like Instagram with 500M daily active users."

**The depth signal:** A junior answer describes a DB query joining posts and follows sorted by date. A senior answer defines fan-out on write vs read, explains *exactly* why fan-out on write breaks for celebrities (write amplification: 1 post × 10M followers = 10M writes), proposes the hybrid model with a concrete threshold, discusses how Redis sorted sets (`ZADD`) enable ranked feeds vs lists for chronological feeds, and mentions that the `follows` table needs an index on `followee_id` — not `follower_id` — for fan-out lookups to work at scale.

---

## Related Topics

- [[system-design/design-notification-system]] — Post creation triggers both feed fan-out and push notifications
- [[system-design/design-distributed-cache]] — Redis is the entire read path; cache eviction policy matters
- [[system-design/design-chat-system]] — Chat uses a different delivery model (WebSockets) vs feed (pull/cache)

---

## Source

[System Design Interview – An Insider's Guide, Chapter 11 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*