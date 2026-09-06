# Queues Gotchas & Troubleshooting

## Completion and failures

Successful completion auto-acknowledges any messages not explicitly retried. A caught error followed only by a log is therefore a data-loss risk. Use per-message try/catch and `msg.retry()` for failures. An uncaught failure retries unacknowledged messages; messages explicitly acknowledged earlier are not retried.

```typescript
async function consume(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await processMessage(msg.body); // Application function; must be idempotent.
      msg.ack();
    } catch (error) {
      console.error('Processing failed', error);
      msg.retry({ delaySeconds: 60 });
    }
  }
}
```

The first per-message ack/retry call wins. Batch-level calls do not override it. [Current semantics](https://developers.cloudflare.com/queues/configuration/batching-retries/).

## Common Errors

### "Duplicate Message Processing"

**Problem:** Same message processed multiple times
**Cause:** At-least-once delivery guarantee means duplicates are possible during retries
**Solution:** Use a business idempotency key with the destination's atomic operation or a database uniqueness constraint. A KV read followed by an effect and KV write is not atomic: concurrent consumers or a crash between effect and marker can duplicate work. Keep idempotency records for the full retry/replay horizon. See [patterns.md](patterns.md#idempotency-pattern).

### "Pull Consumer Can't Decode Messages"

**Problem:** Pull consumer or dashboard shows unreadable message bodies
**Cause:** Messages sent with `v8` content type are only decodable by Workers push consumers
**Solution:** Use `json` content type for pull consumers or dashboard visibility

```typescript
// Use json for pull consumers
await env.MY_QUEUE.send(data, { contentType: 'json' });

// Use v8 only for push consumers with complex JS types
await env.MY_QUEUE.send({ date: new Date(), tags: new Set() }, { contentType: 'v8' });
```

### "Messages Not Being Delivered"

**Problem:** Messages sent but consumer not processing
**Cause:** Queue paused, consumer not configured, or consumer errors
**Solution:** Check queue status with `wrangler queues list`, verify consumer configured with `wrangler queues consumer add`, and check logs with `wrangler tail`

### "High Dead Letter Queue Rate"

**Problem:** Many messages ending up in DLQ
**Cause:** Consumer repeatedly failing to process messages after max retries
**Solution:** Review consumer error logs, check external dependency availability, verify message format matches expectations, or increase retry delay

## Error Classification Patterns

Classify errors to decide whether to retry or DLQ:

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await processMessage(msg.body);
      msg.ack();
    } catch (error) {
      // Transient errors: retry with backoff
      if (isRetryable(error)) {
        const delay = Math.min(30 * (2 ** Math.max(0, msg.attempts - 1)), 86400);
        msg.retry({ delaySeconds: delay });
      }
      // Known permanent errors: persist to a failure store before acknowledging
      else {
        console.error('Permanent error, storing failure record:', error);
        await env.ERROR_LOG.put(msg.id, JSON.stringify({ msg: msg.body, error: String(error) }));
        msg.ack(); // Prevent further retries
      }
    }
  }
}

function isRetryable(error: unknown): boolean {
  if (error instanceof Response) {
    // Retry: rate limits, timeouts, server errors
    return error.status === 429 || error.status >= 500;
  }
  if (error instanceof Error) {
    // Don't retry: validation, auth, not found
    return !error.message.includes('validation') &&
           !error.message.includes('unauthorized') &&
           !error.message.includes('not found');
  }
  return true; // Unknown failures retry within max_retries; use a DLQ for exhaustion
}
```

### "CPU Time Exceeded in Consumer"

**Problem:** Consumer fails with CPU time limit exceeded
**Cause:** Consumer processing exceeding 30s default CPU time limit
**Solution:** Increase CPU limit in wrangler.jsonc: `{ "limits": { "cpu_ms": 300000 } }` (5 minutes max)

## Content Type Decision Guide

**When to use each content type:**

| Content Type | Use When | Readable By | Supports |
|--------------|----------|-------------|----------|
| `json` (default) | Pull consumers, dashboard visibility, simple objects | All (push/pull/dashboard) | JSON-serializable types only |
| `v8` | Push consumers only, complex JS objects | Push consumers only | Date, Map, Set, BigInt, typed arrays |
| `text` | String-only payloads | All | Strings only |
| `bytes` | Binary data (images, files) | All | ArrayBuffer, Uint8Array |

**Decision tree:**
1. Need to view in dashboard or use pull consumer? → Use `json`
2. Need Date, Map, Set, or other V8 types? → Use `v8` (push consumers only)
3. Just strings? → Use `text`
4. Binary data? → Use `bytes`

```typescript
// Dashboard/pull: use json
await env.QUEUE.send({ id: 123, name: 'test' }, { contentType: 'json' });

// Complex JS types (push only): use v8
await env.QUEUE.send({
  created: new Date(),
  tags: new Set(['a', 'b'])
}, { contentType: 'v8' });
```

## Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max queues | 10,000 | Per account |
| Message size | 128 KB | Maximum per message |
| Batch size (consumer) | 100 messages | Maximum messages per batch |
| Batch size (sendBatch) | 100 msgs or 256 KB | Whichever limit reached first |
| Throughput | 5,000 msgs/sec | Per queue |
| Retention | Up to 14 days Paid; 24 hours Free | Configurable retention period |
| Max backlog | 25 GB | Maximum queue backlog size |
| Max delay | 24 hours (86,400s) | Maximum send/retry delay; pull visibility timeout is 12 hours |
| Max retries | 100 | Maximum retry attempts |
| CPU time default | 30s | Per consumer invocation |
| CPU time max | 300s (5 min) | Configurable via `limits.cpu_ms` |
| Operations per message | 3 (write + read + delete) | Base cost per message |
| Pricing | $0.40 per 1M operations | After 1M free operations |
| Message charging | Per 64 KB chunk | Messages charged in 64 KB increments |
