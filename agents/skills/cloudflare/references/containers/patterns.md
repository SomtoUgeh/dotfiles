## Routing Patterns

### Session Affinity (Stateful)

```typescript
export class SessionBackend extends Container {
  defaultPort = 3000;
  sleepAfter = "30m";
}

export default {
  async fetch(request: Request, env: Env) {
    const sessionId = await authenticatedSessionId(request, env) // Application verifies the session; do not trust a raw header;
    const container = env.SESSION_BACKEND.getByName(sessionId);
    return container.fetch(request); // SDK starts the container and waits for readiness.
  }
};
```

**Use:** User sessions, WebSocket, stateful games, per-user caching.

### Load Balancing (Stateless)

```typescript
import { getRandom } from "@cloudflare/containers";

export default {
  async fetch(request: Request, env: Env) {
    const container = await getRandom(env.STATELESS_API, 3); // import getRandom from @cloudflare/containers
    return container.fetch(request); // SDK starts the container and waits for readiness.
  }
};
```

**Use:** Stateless HTTP APIs, CPU-intensive work, read-only queries.

### Singleton Pattern

```typescript
export default {
  async fetch(request: Request, env: Env) {
    const container = env.GLOBAL_SERVICE.getByName("singleton");
    return container.fetch(request); // SDK starts the container and waits for readiness.
  }
};
```

**Use:** Global cache, centralized coordinator, single source of truth.

## WebSocket Forwarding

```typescript
export default {
  async fetch(request: Request, env: Env) {
    if (request.headers.get("Upgrade") === "websocket") {
      const sessionId = await authenticatedSessionId(request, env) // Application verifies the session; do not trust a raw header;
      const container = env.WS_BACKEND.getByName(sessionId);
      // ⚠️ MUST use fetch(), not containerFetch()
      return container.fetch(request);
    }
    return new Response("Not a WebSocket request", { status: 400 });
  }
};
```

**⚠️ Critical:** Always use `fetch()` for WebSocket.

## Graceful shutdown and lifecycle

Handle SIGTERM inside the container process. `onStop(params)` runs after shutdown; use it to record exit status, not to ask the stopped application to save state. Keep lifecycle hooks short.

The SDK coordinates startup. Do not keep an `initialized` boolean forever: a container can stop and restart while its Durable Object remains alive. Use the SDK's start/readiness methods or normal forwarding path.

## Activity renewal

Use `this.renewActivityTimeout()` for background activity; writes to arbitrary storage keys do not extend it. If overriding `onActivityExpired`, return `Promise<void>` and explicitly renew or stop. Do not return a boolean.

## Multiple port routing

```typescript
import { Container, switchPort } from "@cloudflare/containers";

export class MultiPortContainer extends Container {
  defaultPort = 8080;
  requiredPorts = [8080, 8081, 9090];
  async fetch(request: Request) {
    const path = new URL(request.url).pathname;
    const port = path.startsWith("/grpc") ? 8081 : path.startsWith("/metrics") ? 9090 : 8080;
    return super.fetch(switchPort(request, port));
  }
}
```

Select the port on each Request; there is no `this.switchPort()` method or global default-port mutation needed.

## Workflow Integration

```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
import type { Container } from "@cloudflare/containers";

type Job = { jobId: string; data: unknown };
interface Env { PROCESSOR: DurableObjectNamespace<Container> }

export class ProcessingWorkflow extends WorkflowEntrypoint<Env, Job> {
  async run(event: WorkflowEvent<Job>, step: WorkflowStep) {
    const container = this.env.PROCESSOR.getByName(event.payload.jobId);
    
    await step.do("start", async () => {
      await container.startAndWaitForPorts();
    });
    
    const result = await step.do("process", async () => {
      return container.fetch("http://container/process", {
        method: "POST",
        body: JSON.stringify(event.payload.data)
      }).then(async r => { if (!r.ok) throw new Error(`Processing failed: ${r.status}`); return r.text(); });
    });
    
    return result; // Parse against the application's result schema if JSON is expected.
  }
}
```

**Use:** Orchestrating multi-step container operations, durable execution.

## Queue Consumer Integration

```typescript
export default {
  async queue(batch: MessageBatch<unknown>, env: Env) {
    for (const msg of batch.messages) {
      try {
        if (typeof msg.body !== "object" || msg.body === null ||
            !("jobId" in msg.body) || typeof msg.body.jobId !== "string") {
          throw new Error("Invalid job payload");
        }
        const container = env.PROCESSOR.getByName(msg.body.jobId);
        const response = await container.fetch("http://container/process", {
          method: "POST",
          body: JSON.stringify(msg.body)
        });
        
        response.ok ? msg.ack() : msg.retry();
      } catch (err) {
        console.error("Queue processing error:", err);
        msg.retry();
      }
    }
  }
};
```

**Use:** Asynchronous job processing, batch operations, event-driven execution.

Workflow and Queue processing can retry after a side effect succeeds. Give the container endpoint a stable job ID and an idempotency contract before using these patterns for writes.
