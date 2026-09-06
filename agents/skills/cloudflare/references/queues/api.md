# Queues API Reference

## Producer: Send Messages

```typescript
// Basic send
await env.MY_QUEUE.send({ url: request.url, timestamp: Date.now() });

// Options: delay (max 86400s), contentType (json|text|bytes|v8)
await env.MY_QUEUE.send(message, { delaySeconds: 600 });
await env.MY_QUEUE.send(message, { delaySeconds: 0 }); // Override queue default

// Batch (up to 100 msgs or 256 KB)
await env.MY_QUEUE.sendBatch([
  { body: 'msg1' },
  { body: 'msg2' },
  { body: 'msg3', delaySeconds: 300 }
]);

// Non-blocking with ctx.waitUntil - send continues after response
ctx.waitUntil(env.MY_QUEUE.send({ data: 'async' }));

// Background tasks in queue consumer
export default {
  async queue(batch: MessageBatch, env: Env, ctx: ExecutionContext): Promise<void> {
    for (const msg of batch.messages) {
      await processMessage(msg.body);

      // Queue-handler waitUntil work participates in batch completion.
      // Explicitly ack only when the required processing is safely complete.
      ctx.waitUntil(
        env.ANALYTICS_QUEUE.send({ messageId: msg.id, processedAt: Date.now() })
      );

      msg.ack();
    }
  }
};
```

## Consumer: Push-based (Worker)

```typescript
// Type-safe handler with ExportedHandler
interface Env {
  MY_QUEUE: Queue;
  DB: D1Database;
}

export default {
  async queue(batch: MessageBatch<MessageBody>, env: Env, ctx: ExecutionContext): Promise<void> {
    // batch.queue, batch.messages.length
    for (const msg of batch.messages) {
      // msg.id, msg.body, msg.timestamp, msg.attempts
      try {
        await processMessage(msg.body);
        msg.ack();
      } catch (error) {
        msg.retry({ delaySeconds: 600 });
      }
    }
  }
} satisfies ExportedHandler<Env>;
```

**Completion and retry semantics:**

- Successful handler completion automatically acknowledges messages not explicitly retried.
- An uncaught error (including required background work failure) retries unacknowledged messages. Earlier explicit acknowledgements remain acknowledged.
- If you catch a processing error, call `msg.retry()`; logging and returning successfully otherwise acknowledges it.

## Ack/Retry Precedence Rules

1. The first `msg.ack()` or `msg.retry()` call wins; later calls on that message are ignored.
2. Per-message decisions take precedence over `ackAll()` or `retryAll()`.
3. No explicit action means automatic acknowledgement on success, or retry on failure.

```typescript
async function consume(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    msg.ack();
    msg.retry(); // Ignored: ack was first.
  }
  batch.retryAll(); // Does not override those per-message acknowledgements.
}
```

See [acknowledgement rules](https://developers.cloudflare.com/queues/configuration/batching-retries/).

## Batch Operations

```typescript
// Acknowledge entire batch
try {
  await bulkProcess(batch.messages);
  batch.ackAll();
} catch (error) {
  batch.retryAll({ delaySeconds: 300 });
}
```

## Exponential Backoff

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await processMessage(msg.body);
      msg.ack();
    } catch (error) {
      // 30s, 60s, 120s, 240s, 480s, ... up to 24h max
      const delay = Math.min(30 * (2 ** Math.max(0, msg.attempts - 1)), 86400);
      msg.retry({ delaySeconds: delay });
    }
  }
}
```

## Multiple Queues, Single Consumer

```typescript
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    switch (batch.queue) {
      case 'high-priority': await processUrgent(batch.messages); break;
      case 'low-priority': await processDeferred(batch.messages); break;
      case 'email': await sendEmails(batch.messages); break;
      default: batch.retryAll();
    }
  }
};
```

## Consumer: Pull-based (HTTP)

```typescript
// Pull messages
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/queues/${QUEUE_ID}/messages/pull`,
  {
    method: 'POST',
    headers: { 'authorization': `Bearer ${API_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ visibility_timeout_ms: 6000, batch_size: 50 })
  }
);

const data = await response.json();

// Acknowledge
await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/queues/${QUEUE_ID}/messages/ack`,
  {
    method: 'POST',
    headers: { 'authorization': `Bearer ${API_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      acks: [{ lease_id: msg.lease_id }],
      retries: [{ lease_id: msg2.lease_id, delay_seconds: 600 }]
    })
  }
);
```

## Interfaces

```typescript
interface MessageBatch<Body = unknown> {
  readonly queue: string;
  readonly messages: Message<Body>[];
  ackAll(): void;
  retryAll(options?: QueueRetryOptions): void;
}

interface Message<Body = unknown> {
  readonly id: string;
  readonly timestamp: Date;
  readonly body: Body;
  readonly attempts: number;
  ack(): void;
  retry(options?: QueueRetryOptions): void;
}

interface QueueSendOptions {
  contentType?: 'text' | 'bytes' | 'json' | 'v8';
  delaySeconds?: number; // 0-86400
}
```
