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

```csharp
// WebSocket server (ASP.NET Core example)
// Each connected client maintains a persistent WebSocket connection

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Net.WebSockets;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

public class ChatWebSocketHandler
{
    private static readonly Dictionary<int, WebSocket> ActiveConnections = new();

    public async Task OnWebSocketConnected(HttpContext context, WebSocket webSocket, int userId)
    {
        ActiveConnections[userId] = webSocket;
        byte[] buffer = new byte[1024 * 4];

        try
        {
            while (webSocket.State == WebSocketState.Open)
            {
                WebSocketReceiveResult result = await webSocket.ReceiveAsync(
                    new ArraySegment<byte>(buffer),
                    CancellationToken.None
                );

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var text = System.Text.Encoding.UTF8.GetString(buffer, 0, result.Count);
                    var data = JsonSerializer.Deserialize<ChatMessage>(text);
                    await HandleMessage(userId, data!);
                }
            }
        }
        finally
        {
            ActiveConnections.Remove(userId);
            webSocket.Dispose();
        }
    }

    private async Task HandleMessage(int senderId, ChatMessage data)
    {
        int recipientId = data.To;
        var message = new
        {
            from = senderId,
            content = data.Content,
            timestamp = data.Timestamp,
            message_id = GenerateMessageId()
        };

        // Persist first, then deliver
        await SaveToDb(message);

        if (ActiveConnections.ContainsKey(recipientId))
        {
            // Recipient is on THIS server node
            var ws = ActiveConnections[recipientId];
            byte[] bytes = System.Text.Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
            await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }
        else
        {
            // Recipient is on a different node — publish to shared channel
            await RedisPubSub.PublishAsync($"user:{recipientId}", JsonSerializer.Serialize(message));
        }
    }

    private string GenerateMessageId() => Guid.NewGuid().ToString();
    private async Task SaveToDb(object message) => await Task.CompletedTask;  // DB implementation
}

public class ChatMessage
{
    public int To { get; set; }
    public string Content { get; set; }
    public long Timestamp { get; set; }
}
```

```csharp
// Redis Pub/Sub bridge for cross-node delivery
using StackExchange.Redis;
using System;
using System.Net.WebSockets;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

public class PubSubBridge
{
    private readonly int _userId;
    private readonly WebSocket _webSocket;
    private readonly ISubscriber _redis;

    public PubSubBridge(int userId, WebSocket webSocket, IConnectionMultiplexer redis)
    {
        _userId = userId;
        _webSocket = webSocket;
        _redis = redis.GetSubscriber();
    }

    public async Task ListenAsync()
    {
        // Subscribe to this user's channel and forward to WebSocket
        await _redis.SubscribeAsync($"user:{_userId}", async (channel, message) =>
        {
            if (!message.IsNull)
            {
                var payload = JsonSerializer.Deserialize<dynamic>(message.ToString())!;
                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload));
                await _webSocket.SendAsync(
                    new ArraySegment<byte>(bytes),
                    WebSocketMessageType.Text,
                    true,
                    CancellationToken.None
                );
            }
        });

        // Keep listening
        await Task.Delay(Timeout.Infinite);
    }
}
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