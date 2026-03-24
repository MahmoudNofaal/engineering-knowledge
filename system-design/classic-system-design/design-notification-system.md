# Notification System

> A service that delivers messages to users across multiple channels (push, email, SMS) reliably and at scale.

---

## When To Use It

Build a dedicated notification system when your app needs to send messages to millions of users across different channels with delivery guarantees, retry logic, and user preferences. You do NOT need this complexity for a simple app sending a few transactional emails — just use SendGrid directly. The interesting design challenge is fan-out: when one event triggers notifications to millions of users (think: Twitter follower notifications), how do you do that without melting your DB or blocking your main app?

---

## Core Concept

The core is an event-driven pipeline. Your main app publishes an event ("user liked your post") to a queue. Workers pull from that queue, look up user preferences and delivery channels, and dispatch to third-party providers (APNs for iOS push, FCM for Android, Twilio for SMS, SendGrid for email). You decouple the event from the delivery so your main app never blocks on slow HTTP calls to external services. The hardest parts are: idempotency (don't send the same notification twice), respecting user opt-outs, and handling delivery failures with exponential backoff.

---

## The Code

```python
# Event producer — publishes to a queue (Kafka/SQS example)
import json
import boto3

sqs = boto3.client('sqs', region_name='us-east-1')
QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789/notifications"

def publish_notification_event(event: dict):
    """
    event = {
        "type": "like",
        "actor_id": 42,
        "recipient_id": 99,
        "entity_id": 1001,
        "idempotency_key": "like-42-99-1001"
    }
    """
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(event),
        MessageDeduplicationId=event["idempotency_key"],  # Prevents duplicates
        MessageGroupId=str(event["recipient_id"])         # FIFO per user
    )
```

```python
# Notification worker — processes events and routes to channels
import json

class NotificationWorker:
    def __init__(self, user_prefs_db, push_service, email_service, sms_service):
        self.prefs = user_prefs_db
        self.push = push_service
        self.email = email_service
        self.sms = sms_service

    def process(self, raw_message: str):
        event = json.loads(raw_message)
        user_id = event["recipient_id"]

        prefs = self.prefs.get(user_id)
        if not prefs or prefs.get("opt_out_all"):
            return  # Respect opt-outs before any work

        message = self._render_message(event)

        # Fan out to enabled channels
        if prefs.get("push_enabled") and prefs.get("device_token"):
            self._send_with_retry(
                self.push.send, prefs["device_token"], message
            )
        if prefs.get("email_enabled") and prefs.get("email"):
            self._send_with_retry(
                self.email.send, prefs["email"], message
            )
        if prefs.get("sms_enabled") and prefs.get("phone"):
            self._send_with_retry(
                self.sms.send, prefs["phone"], message
            )

    def _send_with_retry(self, fn, target, message, max_retries=3):
        for attempt in range(max_retries):
            try:
                fn(target, message)
                return
            except Exception as e:
                if attempt == max_retries - 1:
                    # Dead-letter queue the failure
                    print(f"Failed after {max_retries} attempts: {e}")
                else:
                    import time
                    time.sleep(2 ** attempt)  # Exponential backoff

    def _render_message(self, event: dict) -> str:
        templates = {
            "like": "Someone liked your post.",
            "follow": "You have a new follower.",
            "comment": "Someone commented on your post."
        }
        return templates.get(event["type"], "You have a new notification.")
```

```sql
-- User notification preferences table
CREATE TABLE notification_preferences (
    user_id         BIGINT PRIMARY KEY,
    email           VARCHAR(255),
    phone           VARCHAR(20),
    device_token    VARCHAR(255),
    push_enabled    BOOLEAN DEFAULT TRUE,
    email_enabled   BOOLEAN DEFAULT TRUE,
    sms_enabled     BOOLEAN DEFAULT FALSE,
    opt_out_all     BOOLEAN DEFAULT FALSE,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification log for deduplication and audit
CREATE TABLE notification_log (
    id              BIGINT PRIMARY KEY AUTO_INCREMENT,
    idempotency_key VARCHAR(255) UNIQUE NOT NULL,
    user_id         BIGINT NOT NULL,
    channel         ENUM('push', 'email', 'sms'),
    status          ENUM('sent', 'failed', 'opted_out'),
    sent_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id)
);
```

---

## Gotchas

- **Idempotency is non-negotiable**: Queue consumers can receive the same message more than once (at-least-once delivery). Without an idempotency key checked against a log table, users get duplicate notifications. Always check before send, then write to the log.
- **Device token staleness**: APNs/FCM tokens expire or rotate. If you get a `410 Gone` from APNs, you must delete that token immediately — continuing to send to it gets your app flagged.
- **Fan-out at scale**: If a celebrity with 10M followers posts, your worker queue gets 10M messages instantly. Design for horizontal worker scaling and consider a separate high-priority vs low-priority queue so system notifications (security alerts) aren't behind social notifications.
- **User timezone and quiet hours**: Sending a push notification at 3am destroys user trust. Store user timezone in preferences and schedule sends accordingly.
- **Third-party provider failures**: APNs and FCM go down. Your retry logic must send failures to a dead-letter queue, not drop them silently, so you can replay after the outage.

---

## Interview Angle

**What they're really testing:** Async architecture, queue design, idempotency, and multi-channel delivery reliability.

**Common question form:** "Design a notification system for a social platform that supports push, email, and SMS with 10M daily active users."

**The depth signal:** A junior answer draws boxes for "notification service" and arrows to email/SMS APIs. A senior answer explains the fan-out problem specifically, distinguishes pull-model vs push-model workers for different scale characteristics, knows what a dead-letter queue is and why it's essential, discusses idempotency key design (not just "check for duplicates"), and explicitly handles the device token lifecycle including how APNs feedback responses should trigger token cleanup.

---

## Related Topics

- [[system-design/design-rate-limiter]] — Outbound notifications need per-user send rate limits to prevent spam
- [[system-design/design-news-feed]] — News feed generation is often what triggers notification fan-out
- [[system-design/design-chat-system]] — Chat messages use a different real-time delivery path but fall back to push notifications

---

## Source

[System Design Interview – An Insider's Guide, Chapter 10 (Alex Xu)](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)

---

*Last updated: 2026-03-24*