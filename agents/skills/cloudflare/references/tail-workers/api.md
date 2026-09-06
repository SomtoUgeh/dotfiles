# Tail Workers API

Generate the project's runtime types with `wrangler types`. Use the global `TraceItem` and `ExportedHandler` types; do not redeclare a smaller `TraceItem` interface. The installed runtime type is authoritative for additional outcomes and event kinds.

## Handler and event shape

A tail handler returns `void` or `Promise<void>`. Await asynchronous delivery, or register its promise with `ctx.waitUntil()`. An ordinary `await` does not block the producer; the tail invocation occurs after its execution.

`TraceItem.event` is a nullable union: fetch, scheduled, queue, email, RPC, alarm, WebSocket and other invocations do not have the same fields. Narrow before accessing HTTP properties. `scriptName` and `eventTimestamp` can be null; a numeric timestamp is milliseconds. `outcome` is execution status, not HTTP status. A normally returned HTTP 500 can have outcome `ok`.

```typescript
interface Env {
  LOG_ENDPOINT: string;
  LOG_TOKEN: string;
}

function summarize(event: TraceItem) {
  const info = event.event;
  const request = info && "request" in info ? info.request : undefined;
  const response = info && "response" in info ? info.response : undefined;
  return {
    script: event.scriptName,
    timestamp: event.eventTimestamp,
    outcome: event.outcome,
    method: request?.method,
    status: response?.status,
    exceptionCount: event.exceptions.length,
    truncated: event.truncated,
  };
}

export default {
  async tail(events, env) {
    const response = await fetch(env.LOG_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.LOG_TOKEN}`,
      },
      body: JSON.stringify(events.map(summarize)),
    });
    await response.body?.cancel();
    if (!response.ok) throw new Error(`Log destination rejected batch: ${response.status}`);
  },
} satisfies ExportedHandler<Env>;
```

## Redaction and serialization

Trace requests redact sensitive URL/header values. `request.getUnredacted()` deliberately bypasses that protection; use it only for a justified field and never export raw credentials. Console messages and exception text can themselves contain sensitive data; request redaction does not sanitize those application logs.

Prefer an explicit allowlisted projection such as `summarize` rather than spreading the entire trace into an external payload. Check `truncated` when assessing log completeness. If a destination requires console details, validate/normalize their unknown values, limit the payload, and redact application-specific secrets before transmission. Do not assert the runtime's console data is always a particular hand-written array type.

[Handler contract](https://developers.cloudflare.com/workers/runtime-apis/handlers/tail/) · [Tail Workers guide](https://developers.cloudflare.com/workers/observability/logs/tail-workers/)
