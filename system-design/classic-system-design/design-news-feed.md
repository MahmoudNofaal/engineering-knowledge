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

```python
# Fan-out on write worker
# Triggered when a user creates a new post

import redis
import json

r = redis.Redis(host='localhost', port=6379, db=0)

def fan_out_post(post: dict, follower_ids: list[int], max_feed_size: int = 500):
    """
    post = {"post_id": 101, "author_id": 42, "content": "...", "created_at": 1711234567}
    Writes the post_id into every follower's feed list in Redis.
    """
    pipe = r.pipeline()
    for follower_id in follower_ids:
        feed_key = f"feed:{follower_id}"
        # LPUSH = prepend (newest first), LTRIM = cap feed at max_feed_size
        pipe.lpush(feed_key, post["post_id"])
        pipe.ltrim(feed_key, 0, max_feed_size - 1)
    pipe.execute()  # Single round-trip to Redis
```

```python
# Feed read — hydrate post IDs from cache into full post objects

def get_feed(user_id: int, page: int = 0, page_size: int = 20) -> list[dict]:
    feed_key = f"feed:{user_id}"
    start = page * page_size
    end = start + page_size - 1

    # Fetch post IDs from user's pre-built feed list
    post_ids = r.lrange(feed_key, start, end)
    if not post_ids:
        return []

    # Batch fetch post details (from cache or DB)
    posts = []
    for post_id in post_ids:
        post_data = r.get(f"post:{post_id.decode()}")
        if post_data:
            posts.append(json.loads(post_data))

    return posts
```

```python
# Hybrid approach: skip fan-out for celebrities (high follower count)
# Their posts are injected at read time instead

CELEBRITY_THRESHOLD = 1_000_000  # followers

def create_post(author_id: int, content: str, db, follower_ids: list[int]):
    post_id = db.insert_post(author_id, content)

    follower_count = len(follower_ids)
    if follower_count < CELEBRITY_THRESHOLD:
        # Normal user: fan out immediately
        fan_out_post(
            {"post_id": post_id, "author_id": author_id},
            follower_ids
        )
    else:
        # Celebrity: skip fan-out, inject at read time
        # Just cache the post object; feed reads will pull it on demand
        pass

    return post_id
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