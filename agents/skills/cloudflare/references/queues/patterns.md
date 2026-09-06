# Queues Patterns & Best Practices

## Async Task Processing

```typescript
// Producer: Accept request, queue work
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { userId, reportType } = await request.json();
    await env.REPORT_QUEUE.send({ userId, reportType, requestedAt: Date.now() });
    return Response.json({ message: 'Report queued', status: 'pending' });
  }
};

// Consumer: Process reports
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      const { userId, reportType } = msg.body;
      const report = await generateReport(userId, reportType, env);
      await env.REPORTS_BUCKET.put(`${userId}/${reportType}.pdf`, report);
      msg.ack();
    }
  }
};
```

## Buffering API Calls

```typescript
// Producer: Queue log entries
ctx.waitUntil(env.LOGS_QUEUE.send({
  method: request.method,
  url: request.url,
  timestamp: Date.now()
}));

// Consumer: Batch write to external API
async queue(batch: MessageBatch, env: Env): Promise<void> {
  const logs = batch.messages.map(m => m.body);
  const response = await fetch(env.LOG_ENDPOINT, { method: 'POST', body: JSON.stringify({ logs }) });
  if (!response.ok) throw new Error(`Log endpoint failed: ${response.status}`);
  batch.ackAll();
}
```

## Rate Limiting Upstream

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await callRateLimitedAPI(msg.body);
      msg.ack();
    } catch (error) {
      if (error instanceof Response && error.status === 429) {
        const header = error.headers.get('Retry-After') ?? '60';
        const seconds = /^\d+$/.test(header) ? Number(header) : (Date.parse(header) - Date.now()) / 1000;
        const delay = Number.isFinite(seconds) ? Math.max(0, Math.min(86400, Math.ceil(seconds))) : 60;
        msg.retry({ delaySeconds: delay });
      } else throw error;
    }
  }
}
```

## Event-Driven Workflows

```typescript
// R2 event → Queue → Worker
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      const event = msg.body;
      if (event.action === 'PutObject') {
        await processNewFile(event.object.key, env);
      } else if (event.action === 'DeleteObject') {
        await cleanupReferences(event.object.key, env);
      }
      msg.ack();
    }
  }
};
```

## Dead Letter Queue Pattern

```typescript
// Main queue: After max_retries, goes to DLQ automatically
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      try {
        await riskyOperation(msg.body);
        msg.ack();
      } catch (error) {
        console.error(`Failed after ${msg.attempts} attempts:`, error);
        msg.retry(); // Required: catching alone would acknowledge on successful return.
      }
    }
  }
};

// DLQ consumer: Log and store failed messages
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      await env.FAILED_KV.put(msg.id, JSON.stringify(msg.body));
      msg.ack();
    }
  }
};
```

## Priority Queues

High priority: `max_batch_size: 5, max_batch_timeout: 1`. Low priority: `max_batch_size: 100, max_batch_timeout: 30`.

## Delayed Job Processing

```typescript
await env.EMAIL_QUEUE.send({ to, template, userId }, { delaySeconds: 3600 });
```

## Fan-out Pattern

```typescript
async fetch(request: Request, env: Env): Promise<Response> {
  const event = await request.json();

  // Send to multiple queues for parallel processing
  await Promise.all([
    env.ANALYTICS_QUEUE.send(event),
    env.NOTIFICATIONS_QUEUE.send(event),
    env.AUDIT_LOG_QUEUE.send(event)
  ]);

  return Response.json({ status: 'queued' }, { status: 202 });
}
```

## Idempotency Pattern

Use a stable business-event ID, not only a delivery attempt ID. For effects wholly in D1, enforce a unique event ID and commit the effect and processing record in the same transaction/batch. For external APIs, pass the provider's supported idempotency key and persist the result. A KV existence check followed by a remote effect and KV write cannot provide atomic deduplication.

Fan-out is also not transactional: some queue sends may succeed before another fails. Retrying requires per-destination idempotency or an outbox that records delivery progress.

## Integration: D1 Batch Writes

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  // Requires events.id PRIMARY KEY or UNIQUE; duplicate deliveries are ignored.
  // Collect all inserts for single D1 batch
  const statements = batch.messages.map(msg =>
    env.DB.prepare('INSERT INTO events (id, data, created) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING')
      .bind(msg.id, JSON.stringify(msg.body), Date.now())
  );

  try {
    await env.DB.batch(statements);
    batch.ackAll();
  } catch (error) {
    console.error('D1 batch failed:', error);
    batch.retryAll({ delaySeconds: 60 });
  }
}
```

## Integration: Workflows

```typescript
// Queue triggers Workflow for long-running tasks
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      const instance = await env.MY_WORKFLOW.create({
        id: msg.id,
        params: msg.body
      });
      console.log('Workflow started:', instance.id);
      msg.ack();
    } catch (error) {
      msg.retry({ delaySeconds: 30 });
    }
  }
}
```

## Integration: Durable Objects

```typescript
// Queue distributes work to Durable Objects by ID
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    const { userId, action } = msg.body;

    // Route to user-specific DO
    const id = env.USER_DO.idFromName(userId);
    const stub = env.USER_DO.get(id);

    try {
      const response = await stub.fetch(new Request('https://do/process', {
        method: 'POST',
        body: JSON.stringify({ action, messageId: msg.id })
      }));
      if (!response.ok) throw new Error(`DO processing failed: ${response.status}`);
      msg.ack();
    } catch (error) {
      msg.retry({ delaySeconds: 60 });
    }
  }
}
```
