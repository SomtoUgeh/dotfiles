# Cron Triggers API

## Basic Handler

```typescript
export default {
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    console.log("Cron executed:", new Date(controller.scheduledTime));
  },
};
```

**JavaScript:** Same signature without types
**Python:** `class Default(WorkerEntrypoint): async def scheduled(self, controller, env, ctx)`

## ScheduledController

```typescript
interface ScheduledController {
  scheduledTime: number;  // Unix ms when scheduled to run
  cron: string;           // Expression that triggered (e.g., "*/5 * * * *")
  type: string;           // Always "scheduled"
  noRetry(): void;        // Prevent automatic retry on failure
}
```

**Prevent retry on failure:**
```typescript
export default {
  async scheduled(controller, env, ctx) {
    try {
      await riskyOperation(env);
    } catch (error) {
      // Don't retry - failure is expected/acceptable
      controller.noRetry();
      console.error("Operation failed, not retrying:", error);
    }
  },
};
```

**When to use noRetry():**
- External API failures outside your control (avoid hammering failed services)
- Rate limit errors (retry would fail again immediately)
- Duplicate execution detected (idempotency check failed)
- Non-critical operations where skip is acceptable (analytics, caching)
- Validation errors that won't resolve on retry

## Handler Parameters

**`controller: ScheduledController`**
- Access cron expression and scheduled time

**`env: Env`**
- All bindings: KV, R2, D1, secrets, service bindings

**`ctx: ExecutionContext`**
- `ctx.waitUntil(promise)` - Extend execution for async tasks (logging, cleanup, external APIs)
- First `waitUntil` failure recorded in Cron Events

## Multiple Schedules

```typescript
export default {
  async scheduled(controller, env, ctx) {
    switch (controller.cron) {
      case "*/3 * * * *": ctx.waitUntil(updateRecentData(env)); break;
      case "0 * * * *": ctx.waitUntil(processHourlyAggregation(env)); break;
      case "0 2 * * *": ctx.waitUntil(performDailyMaintenance(env)); break;
      default: console.warn(`Unhandled: ${controller.cron}`);
    }
  },
};
```

## ctx.waitUntil Usage

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const data = await fetchCriticalData(); // Critical path

    // Non-blocking background tasks
    ctx.waitUntil(Promise.all([
      logToAnalytics(data),
      cleanupOldRecords(env.DB),
      notifyWebhook(env.WEBHOOK_URL, data),
    ]));
  },
};
```

## Workflow Integration

```typescript
import { WorkflowEntrypoint } from "cloudflare:workers";

export class DataProcessingWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const data = await step.do("fetch-data", () => fetchLargeDataset());
    const processed = await step.do("process-data", () => processDataset(data));
    await step.do("store-results", () => storeResults(processed));
  }
}

export default {
  async scheduled(controller, env, ctx) {
    const instance = await env.MY_WORKFLOW.create({
      params: { scheduledTime: controller.scheduledTime, cron: controller.cron },
    });
    console.log(`Started workflow: ${instance.id}`);
  },
};
```

## Testing Handler

**Local development (/cdn-cgi/local/scheduled endpoint):**
```bash
# Start dev server
npx wrangler dev

# Trigger any cron
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=*/5+*+*+*+*"

# Trigger specific cron with custom time
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=0+2+*+*+*&time=1704067200000"
```

**Query parameters:**
- `cron` - Optional. URL-encoded cron expression (use `+` for spaces)
- `time` - Optional. Unix timestamp in milliseconds (defaults to current time)

The `/cdn-cgi/local/scheduled` route is a local development route. It is not automatically a deployed Worker endpoint. Any custom HTTP job trigger you implement must authenticate callers.

**Unit testing:** Use `createScheduledController`, `createExecutionContext`, and `waitOnExecutionContext` from `cloudflare:test`. Await both the handler and its registered background work; a stubbed `waitUntil` does not prove completion.

## Error Handling

**Failures:** A `noRetry()` method exists, but do not infer a retry schedule or exactly-once guarantee from it. For required retries, use a documented Workflows/Queues policy and durable state. Monitor cron failures explicitly.

**Best practices:**
```typescript
export default {
  async scheduled(controller, env, ctx) {
    try {
      await criticalOperation(env);
    } catch (error) {
      // Log error details
      console.error("Cron failed:", {
        cron: controller.cron,
        scheduledTime: controller.scheduledTime,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });

      // Decide: retry or skip
      if (error instanceof Error && error.message.includes("rate limit")) {
        controller.noRetry(); // Skip retry for rate limits
      }
      // Otherwise allow automatic retry
      throw error;
    }
  },
};
```

## See Also

- [README.md](./README.md) - Overview
- [patterns.md](./patterns.md) - Use cases, examples
- [gotchas.md](./gotchas.md) - Common errors, testing issues

Current source: [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). Local handler tests do not verify hosted scheduling, retries, or global propagation.
