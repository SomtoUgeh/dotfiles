# Cloudflare Queues

Flexible message queuing for async task processing with guaranteed at-least-once delivery and configurable batching.

## Overview

Queues provide:
- At-least-once delivery guarantee
- Push-based (Worker) and pull-based (HTTP) consumers
- Configurable batching and retries
- Dead Letter Queues (DLQ)
- Delays up to 24 hours

**Use cases:** Async processing, API buffering, rate limiting, event workflows, deferred jobs

## Quick Start

```bash
wrangler queues create my-queue
wrangler queues consumer add my-queue my-worker
```

```typescript
// Producer
await env.MY_QUEUE.send({ userId: 123, action: 'notify' });

// Consumer (with proper error handling)
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      try {
        await process(msg.body);
        msg.ack();
      } catch (error) {
        msg.retry({ delaySeconds: 60 });
      }
    }
  }
};
```

## Critical Warnings

**Before using Queues, understand these production mistakes:**

1. **A successful handler automatically acknowledges messages** unless explicitly marked for retry. Catching an error and merely logging it can therefore lose the failed work.
2. **Failure retries messages that were not already acknowledged.** Explicit per-message acknowledgements survive a later batch failure. Use `msg.retry()` for caught failures.

See [gotchas.md](./gotchas.md) for detailed solutions.

## Core Operations

| Operation | Purpose | Limit |
|-----------|---------|-------|
| `send(body, options?)` | Publish message | 128 KB |
| `sendBatch(messages)` | Bulk publish | 100 msgs/256 KB |
| `message.ack()` | Acknowledge success | - |
| `message.retry(options?)` | Retry with delay | - |
| `batch.ackAll()` | Ack entire batch | - |

## Architecture

```
[Producer Worker] → [Queue] → [Consumer Worker/HTTP] → [Processing]
```

- Max 10,000 queues per account
- 5,000 msgs/second per queue
- Paid retention configurable up to 14 days; Free retention is 24 hours

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## In This Reference

- [configuration.md](./configuration.md) - wrangler.jsonc setup, producer/consumer config, DLQ, content types
- [api.md](./api.md) - Send/batch methods, queue handler, ack/retry rules, type-safe patterns
- [patterns.md](./patterns.md) - Async tasks, buffering, rate limiting, D1/Workflows/DO integrations
- [gotchas.md](./gotchas.md) - Critical batch error handling, idempotency, error classification

## See Also

- [workers](../workers/) - Worker runtime for producers/consumers
- [r2](../r2/) - Process R2 event notifications via queues
- [d1](../d1/) - Batch write to D1 from queue consumers
