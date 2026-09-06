## Container Class API

```typescript
import { Container } from "@cloudflare/containers";

export class MyContainer extends Container {
  defaultPort = 8080;
  requiredPorts = [8080];
  sleepAfter = "30m";
  enableInternet = true;
  pingEndpoint = "/health";
  envVars = {};
  entrypoint = [];

  onStart() { /* container started */ }
  onStop() { /* container stopping */ }
  onError(error: Error) { /* container error */ }
  async onActivityExpired(): Promise<void> { await this.stop(); }
  // Keep the inherited alarm handler for SDK scheduling.
}
```

## Routing

**getByName(id)** - Named instance for session affinity, per-user state
**getRandom()** - Random instance for load balancing stateless services

```typescript
const container = env.MY_CONTAINER.getByName("user-123");
const container = await getRandom(env.MY_CONTAINER, 3); // import from @cloudflare/containers
```

## Startup Methods

### start() - Basic start (8s timeout)

```typescript
await container.start();
await container.start({ envVars: { KEY: "value" } });
```

Returns when **process starts**, NOT when ports ready. Use for fire-and-forget.

### startAndWaitForPorts() - Recommended (20s timeout)

```typescript
await container.startAndWaitForPorts();  // Uses requiredPorts
await container.startAndWaitForPorts({ ports: [8080, 9090] });
await container.startAndWaitForPorts({ 
  ports: [8080],
  startOptions: { envVars: { KEY: "value" } }
});
```

Returns when **ports listening**. Use before HTTP/TCP requests.

**Port resolution:** explicit ports → requiredPorts → defaultPort → port 33

### waitForPort() - Wait for specific port

```typescript
await container.waitForPort({ portToCheck: 8080 });
await container.waitForPort({ portToCheck: 8080, retries: 30, waitInterval: 1000 });
```

## Communication

### fetch() - HTTP with WebSocket support

```typescript
// ✅ Supports WebSocket upgrades
const response = await container.fetch(request);
const response = await container.fetch("http://container/api", {
  method: "POST",
  body: JSON.stringify({ data: "value" })
});
```

**Use for:** All HTTP, especially WebSocket.

### containerFetch() - HTTP and internal WebSocket forwarding

```typescript
// For external WebSocket upgrades prefer stub.fetch(request)
const response = await container.containerFetch(request); // Inside a DO this also supports WebSockets; external RPC transport differs.
```

For WebSocket requests originating outside the Durable Object, use `fetch()` with `switchPort(request, port)` when needed. Do not generalize this RPC limitation to internal containerFetch calls.

### TCP Connections

```typescript
const container = this.ctx.container;
if (!container) throw new Error("Container binding is missing");
await this.startAndWaitForPorts({ ports: [8080] });
const port = container.getTcpPort(8080);
const conn = port.connect("10.0.0.1:8080");
await conn.opened;

if (request.body) await request.body.pipeTo(conn.writable);
return new Response(conn.readable);
```

### switchPort() - Select a port for one request

```typescript
// import { switchPort } from "@cloudflare/containers";
return super.fetch(switchPort(request, 8081)); // Per-request target, no shared mutation
```

## Lifecycle Hooks

### onStart()

Called when container process starts (ports may not be ready). Runs in `blockConcurrencyWhile` - no concurrent requests.

```typescript
onStart() {
  console.log("Container starting");
}
```

### onStop()

Called after the container shuts down, with exit details. Handle SIGTERM inside the container process; this hook cannot flush a process that has already stopped.

```typescript
onStop() {
  // Record the stop outcome in Durable Object storage if needed
}
```

### onError()

Called when container crashes or fails to start.

```typescript
onError(error: Error) {
  console.error("Container error:", error);
}
```

### onActivityExpired()

Called when the activity timeout expires. This is an async hook returning `Promise<void>`, not a boolean keep-alive signal. Call `this.renewActivityTimeout()` to extend activity or `await this.stop()` to stop; the default implementation stops.

## Scheduling

```typescript
export class ScheduledContainer extends Container {
  async fetch(request: Request) {
    await this.schedule(60, "recordCheck", { requestedAt: Date.now() });
    return new Response("Scheduled");
  }
  async recordCheck(payload: { requestedAt: number }) {
    await this.ctx.storage.put("last-check", payload.requestedAt);
  }
}
```

`schedule` takes a `Date` or delay in seconds, a callback method name, and optional payload. Do not override the SDK's `alarm()` when using this scheduler.

## State Inspection

### External state check

```typescript
const state = await container.getState();
// See installed State: includes running, healthy, stopping, stopped, stopped_with_code.
```

### Internal state check

```typescript
export class MyContainer extends Container {
  async fetch(request: Request) {
    return Response.json({ running: this.ctx.container?.running ?? false });
  }
}
```

**⚠️ Use `getState()` for external checks, `ctx.container.running` for internal.**
