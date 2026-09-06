# VPC request patterns

## Fixed-destination Redis health check

This helper belongs behind the existing application's authorization. Its fixed
destination prevents callers selecting arbitrary hosts. The example reads a
complete Redis PING response with a size limit and closes on success or failure.
It does not implement a general Redis client or cross-request connection pool.

```typescript
type Env = { PRIVATE_VPC: Fetcher };

export async function pingPrivateRedis(env: Env): Promise<boolean> {
  const socket = await env.PRIVATE_VPC.connect({ hostname: '10.0.1.50', port: 6379 });
  const timer = setTimeout(() => { void socket.close().catch(() => {}); }, 5000);
  const writer = socket.writable.getWriter();
  const reader = socket.readable.getReader();
  try {
    await writer.write(new TextEncoder().encode('*1\r\n$4\r\nPING\r\n'));
    const decoder = new TextDecoder();
    let result = '';
    while (result.length <= 128) {
      const { value, done } = await reader.read();
      if (done) return false;
      result += decoder.decode(value, { stream: true });
      if (result.includes('\r\n')) return result === '+PONG\r\n';
    }
    return false;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
    writer.releaseLock();
    reader.releaseLock();
    await socket.close().catch(() => {});
  }
}
```

Connection establishment failures reject before a Socket is returned; the caller
must handle that rejection. The timer bounds operations after connect completes,
not the connection establishment itself. Do not claim a total deadline from a
`Promise.race()` that leaves the underlying connection running.

## HTTP and failover

Use the fixed-service HTTP helper in [api.md](./api.md). Handle an HTTP error
status separately from a connection exception. Allow redirects only after
validating their destination. For network bindings, select destinations from
trusted application configuration, not query parameters or caller-supplied URLs.

Retry only operations that can safely repeat, with a bounded policy. A timeout
does not establish that an upstream write failed. Database connection pooling
belongs in [Hyperdrive](../hyperdrive/) or a supported driver; Worker socket I/O
objects cannot be shared across unrelated request contexts.

For streaming, transfer ownership explicitly: keep the socket alive while its
response body is consumed, and close it on EOF, failure, or downstream cancel.
Do not close it in a handler's `finally` before the returned stream is read.
