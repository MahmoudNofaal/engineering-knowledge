# Chat System

> A real-time messaging service that delivers messages between users with low latency and guaranteed ordering.

---

## When To Use It

Design a dedicated chat system when you need real-time, bidirectional, low-latency message delivery — not polling. Don't build this for asynchronous messaging where a few seconds delay is acceptable (use a notification system instead). The key challenge is maintaining persistent connections at scale, storing message history efficiently, and handling the difference between 1-on-1 chats, group chats, and broadcast channels.

---

## Core Concept

HTTP is request/response — the client always initiates. Chat needs the server to push messages to clients. The three options are: short polling (client asks every N seconds — wasteful), long polling (client holds a request open until there's a message — better, but clunky), and WebSockets (persistent bidirectional TCP connection — the right answer for chat). Once you have WebSockets sorted, the rest is: how do you route a message from sender's WebSocket server to the receiver's WebSocket server when they're connected to different nodes? The answer is a pub/sub layer (Redis Pub/Sub or Kafka) that all WebSocket servers subscribe to.

---

## The Code

```python
# WebSocket server (FastAPI/websockets example)
# Each connected client maintains a persistent WebSocket connection

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import dict

app = FastAPI()

# In-memory connection registry (use Redis in production for multi-node)
active_connections: dict[int, WebSocket] = {}

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    await websocket.accept()
    active_connections[user_id] = websocket

    try:
        while True:
            data = await websocket.receive_json()
            await handle_message(user_id, data)
    except WebSocketDisconnect:
        del active_connections[user_id]

async def handle_message(sender_id: int, data: dict):
    recipient_id = data["to"]
    message = {
        "from": sender_id,
        "content": data["content"],
        "timestamp": data["timestamp"],
        "message_id": generate_message_id()  # Snowflake ID for ordering
    }

    # Persist first, then deliver
    await save_to_db(message)

    if recipient_id in active_connections:
        # Recipient is on THIS server node
        await active_connections[recipient_id].send_json(message)
    else:
        # Recipient is on a different node — publish to shared channel
        await redis_pubsub.publish(f"user:{recipient_id}", message)
```

```python
# Redis Pub/Sub bridge for cross-node delivery
import asyncio
import redis.asyncio as aioredis
import json

class PubSubBridge:
    def __init__(self, user_id: int, websocket):
        self.user_id = user_id
        self.websocket = websocket
        self.redis = aioredis.from_url("redis://localhost")

    async def listen(self):
        """Subscribe to this user's channel and forward to WebSocket."""
        pubsub = self.redis.pubsub()
        await pubsub.subscribe(f"user:{self.user_id}")

        async for message in pubsub.listen():
            if message["type"] == "message":
                payload = json.loads(message["data"])
                await self.websocket.send_json(payload)
```

```sql
-- Message storage: append-only, partitioned by channel
CREATE TABLE messages (
    message_id  BIGINT NOT NULL,      -- Snowflake ID (sortable by time)
    channel_id  BIGINT NOT NULL,      -- 1:1 chat or group chat ID
    sender_id   BIGINT NOT NULL,
    content     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_id, message_id)  -- Clustered by channel for range scans
);

-- Last seen for unread count + delivery receipts
CREATE TABLE message_receipts (
    user_id         BIGINT NOT NULL,
    channel_id      BIGINT NOT NULL,
    last_read_id    BIGINT,           -- Last message_id the user has seen
    PRIMARY KEY (user_id, channel_id)
);
```

---

## Gotchas

- **Message ordering requires Snowflake IDs, not timestamps**: Two messages created at the "same" millisecond will have identical `created_at`. Use a Snowflake-style monotonic ID (encodes timestamp + server ID + sequence) as the primary key to guarantee total ordering within a channel.
- **WebSocket connections are stateful**: If your WebSocket server crashes, all connected clients drop. You need client-side reconnect logic with exponential backoff and message re-sync on reconnect (fetch messages since last known ID).
- **Group chat fan-out**: Sending to a group of 1000 members means 1000 WebSocket writes per message. For very large groups (Slack channels, Discord servers), switch to a channel subscription model where clients pull from a shared channel feed instead.
- **Online presence is expensive**: Tracking who is "online" requires a heartbeat (ping every 5s) and a centralized store (Redis sorted set with TTL). At 10M concurrent users, this is a significant Redis write load — batch heartbeats and use coarser presence buckets (last active within 5 minutes).
- **Message delivery guarantees**: By default, WebSocket fire-and-forget. If the network drops between server write and client receipt, the message appears "lost." Use ACK messages from the client and a pending queue on the server to implement at-least-once delivery.

---

## Interview Angle

**What they're really testing:** Real-time connection management, pub/sub routing across nodes, and message ordering/storage tradeoffs.

**Common question form:** "Design a chat application like WhatsApp that supports 1-on-1 and group messaging."

**The depth signal:** A junior answer describes REST endpoints for sending and polling for messages. A senior answer explains *why* WebSockets over HTTP polling (connection overhead, latency), describes the cross-node routing problem and solves it with Redis Pub/Sub or Kafka, explains why Snowflake IDs are necessary for message ordering, and discusses the difference in architecture between 1:1 chat (direct routing) and group chat (fan-out vs channel-subscription model) — with a concrete threshold where you'd switch strategies.

---

## Related Topics

- [[system-design/design-notification-system]] — Push notifications are the offline fallback when the recipient's WebSocket is closed
- [[system-design/design-distributed-cache]] — Redis is used for both pub/sub routing and presence tracking
- [[system-design/design-news-feed]] — Feed uses a pull model; contrast with chat's push model for the same underlying data

---

## Source

[System Design Interview – An Insider's Guide, Chapter 12 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*