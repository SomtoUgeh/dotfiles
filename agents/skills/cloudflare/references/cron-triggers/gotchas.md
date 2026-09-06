# Cron Triggers Gotchas

## Common Errors

### "Timezone Issues"

**Problem:** Cron runs at wrong time relative to local timezone
**Cause:** All crons execute in UTC, no local timezone support
**Solution:** Convert local time to UTC manually

**Conversion formula:** `utcHour = (localHour - utcOffset + 24) % 24`

**Examples:**
- 9am PST (UTC-8) → `(9 - (-8) + 24) % 24 = 17` → `0 17 * * *`
- 2am EST (UTC-5) → `(2 - (-5) + 24) % 24 = 7` → `0 7 * * *`
- 6pm JST (UTC+9) → `(18 - 9 + 24) % 24 = 33 % 24 = 9` → `0 9 * * *`

**Daylight Saving Time:** Adjust manually when DST changes, or explicitly implement an IANA-time-zone schedule. Early-morning hours can be skipped or repeated during DST transitions.

### "Cron Not Executing"

**Cause:** Missing `scheduled()` export, invalid syntax, propagation delay (<15min), or plan limits
**Solution:** Verify export exists, validate at crontab.guru, wait 15+ min after deploy, check plan limits

### "Duplicate Executions"

**Cause:** At-least-once delivery
**Solution:** Use durable coordination and idempotent side effects; KV read-then-write is not a lock

### "Execution Failures"

**Cause:** CPU exceeded, unhandled exceptions, network timeouts, binding errors
**Solution:** Use try-catch, AbortController timeouts, `ctx.waitUntil()` for long ops, or Workflows for heavy tasks

### "Local Testing Not Working"

**Problem:** `/cdn-cgi/local/scheduled` endpoint returns 404 or doesn't trigger handler
**Cause:** Missing `scheduled()` export, wrangler not running, or incorrect endpoint format
**Solution:**

1. Verify `scheduled()` is exported:
```typescript
export default {
  async scheduled(controller, env, ctx) {
    console.log("Cron triggered");
  },
};
```

2. Start dev server:
```bash
npx wrangler dev
```

3. Use correct endpoint format (URL-encode spaces as `+`):
```bash
# Correct
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=*/5+*+*+*+*"

# Wrong (will fail)
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=*/5 * * * *"
```

4. Update Wrangler if outdated:
```bash
npm install -g wrangler@latest
```

### "waitUntil() Tasks Not Completing"

**Problem:** Background tasks in `ctx.waitUntil()` fail silently or don't execute
**Cause:** Promises rejected without error handling, or execution limits are exceeded
**Solution:** Always await or handle errors in waitUntil promises:

```typescript
export default {
  async scheduled(controller, env, ctx) {
    // Rejections are recorded; catching is useful for extra context
    ctx.waitUntil(riskyOperation());

    // GOOD: Explicit error handling
    ctx.waitUntil(
      riskyOperation().catch(err => {
        console.error("Background task failed:", err);
        throw err; // Preserve failure status after logging.
      })
    );
  },
};
```

### Idempotency and custom HTTP triggers

KV read-then-write is not an atomic lock. Marking a job done before its side effect can also permanently skip failed work. Use an idempotency key based on schedule and scheduled time with the side-effect provider, or coordinate durable job state in a Durable Object/transactional database. Test concurrent duplicate calls and failures between state changes and the side effect.

The local scheduled test route is not automatically deployed. If you add an HTTP trigger yourself, authenticate and authorize it. A `cf-ray` header or request URL substring is not authorization.

## Limits & Quotas

| Limit | Free | Paid | Notes |
|-------|------|------|-------|
| Triggers per Worker | 3 | Unlimited | Maximum cron schedules per Worker |
| CPU time | 10ms | 30s (<1hr interval), 15min (≥1hr interval) | May need `ctx.waitUntil()` or Workflows |
| Propagation delay | Up to 15 minutes | Up to 15 minutes | Time for changes to take effect globally |
| Min interval | 1 minute | 1 minute | Cannot schedule more frequently |

## Testing Best Practices

**Unit tests:**
- Mock `ScheduledController`, `ExecutionContext`, and bindings
- Test each cron expression separately
- Verify `noRetry()` is called when expected
- Use Vitest with `@cloudflare/vitest-plugin` for realistic env

**Integration tests:**
- Test via `/cdn-cgi/local/scheduled` endpoint in dev environment
- Verify idempotency logic with duplicate `scheduledTime` values
- Test error handling and retry behavior

**Production:** Start with long intervals (`*/30 * * * *`), monitor Cron Events for 24h, set up alerts before reducing interval

## Resources

- [Cron Triggers Docs](https://developers.cloudflare.com/workers/configuration/cron-triggers/)
- [Scheduled Handler API](https://developers.cloudflare.com/workers/runtime-apis/handlers/scheduled/)
- [Cloudflare Workflows](https://developers.cloudflare.com/workflows/)
- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Crontab Guru](https://crontab.guru/) - Validator
- [Workers Vitest plugin](https://github.com/cloudflare/workers-sdk/tree/main/fixtures/vitest-plugin-examples)

Current source: [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). Local handler tests do not verify hosted scheduling, retries, or global propagation.
