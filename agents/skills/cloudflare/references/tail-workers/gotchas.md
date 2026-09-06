# Tail Workers troubleshooting

| Symptom | Check and correction |
|---|---|
| Delivery ends early | Await the promise or register it with `ctx.waitUntil`; do not fire and forget. Awaiting is valid. |
| Destination returns 401/429/500 without an exception | `fetch` resolves for HTTP failures. Inspect `response.ok`, consume/cancel the body, and handle rejection. |
| Type error on `event.request` | Narrow the nullable event union. Scheduled, email, queue and RPC events are not fetch events. |
| HTTP 500 missing from error filters | Execution `outcome` and response status are separate. Handle both according to the monitoring requirement. |
| Wrong timestamp | Numeric `eventTimestamp` is milliseconds; preserve null instead of manufacturing a 1970 timestamp. |
| Producer deployment cannot attach a consumer | Deploy the intended consumer with a `tail()` handler before the producer. Check account/environment/name. |
| Logs expose secrets | Redaction of trace requests does not sanitize arbitrary console messages, exception text or diagnostics. Export allowlisted fields. |
| Unexpected logging costs | Tail Workers run after producer invocations; in-handler sampling reduces work/egress rather than invocation count. |

## Failure handling

The example below assumes `payload` is an already redacted, bounded JSON string inside the tail handler. A failed external delivery falls back to KV, and a failed fallback still rejects the handler. The random suffix avoids overwriting same-millisecond events.

```typescript
try {
  const response = await fetch(env.LOG_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: payload,
  });
  await response.body?.cancel();
  if (!response.ok) throw new Error(`Delivery rejected: ${response.status}`);
} catch {
  await env.FALLBACK_KV.put(`failed:${crypto.randomUUID()}`, payload, {
    expirationTtl: 86400,
  });
}
```

Fallback storage is not an automatic replay system. Define a reader/retry process, retention and duplicate handling if recovery is required. For critical audit records, write through an appropriate durable path from the application; do not claim complete delivery merely because a tail handler ran.

During debugging, log counts, statuses and safe identifiers rather than dumping full traces. Restrict any synthetic error endpoint to the test environment and remove it when validation is done.

See [api.md](api.md) for the typed handler and [configuration.md](configuration.md) for attachment checks.
