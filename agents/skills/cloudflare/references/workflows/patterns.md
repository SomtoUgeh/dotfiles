# Workflow Patterns

## Image Processing Pipeline

```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
type Params = { imageKey: string };

export class ImageProcessingWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    const imageData = await step.do('fetch', async () => {
      const object = await this.env.BUCKET.get(event.payload.imageKey);
      if (!object) throw new Error('Image not found');
      return object.arrayBuffer();
    });
    const description = await step.do('generate description', async () => 
      await this.env.AI.run('@cf/llava-hf/llava-1.5-7b-hf', {image: Array.from(new Uint8Array(imageData)), prompt: 'Describe this image', max_tokens: 50})
    );
    await step.waitForEvent('await approval', { type: 'approved', timeout: '24 hours' });
    await step.do('publish', async () => { await this.env.BUCKET.put(`public/${event.payload.imageKey}`, imageData); });
  }
}
```

## User Lifecycle

```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
type Params = { email: string; userId: string };

export class UserLifecycleWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    await step.do('welcome email', async () => await sendEmail(event.payload.email, 'Welcome!'));
    await step.sleep('trial period', '7 days');
    const hasConverted = await step.do('check conversion', async () => {
      const user = await this.env.DB.prepare('SELECT subscription_status FROM users WHERE id = ?').bind(event.payload.userId).first<{ subscription_status: string }>();
      return user?.subscription_status === 'active';
    });
    if (!hasConverted) await step.do('trial expiration email', async () => await sendEmail(event.payload.email, 'Trial ending'));
  }
}
```

## Data Pipeline

```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
import { z } from "zod";
type Params = { sourceUrl: string };
const Items = z.array(z.object({ id: z.string(), value: z.string() }));
const normalizeData = (item: z.infer<typeof Items>[number]) => item.value.trim();

export class DataPipelineWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    const rawData = await step.do('extract', {retries: { limit: 10, delay: '30 seconds', backoff: 'exponential' }}, async () => {
      const res = await fetch(event.payload.sourceUrl);
      if (!res.ok) throw new Error('Fetch failed');
      return Items.parse(await res.json());
    });
    const transformed = await step.do('transform', async () => 
      rawData.map(item => ({ id: item.id, normalized: normalizeData(item) }))
    );
    const dataRef = await step.do('store', async () => {
      const key = `processed/${event.instanceId}.json`;
      await this.env.BUCKET.put(key, JSON.stringify(transformed));
      return { key };
    });
    await step.do('load', async () => {
      const object = await this.env.BUCKET.get(dataRef.key);
      if (!object) throw new Error('Processed object not found');
      const data = await object.json<Array<{ id: string; normalized: string }>>();
      for (let i = 0; i < data.length; i += 100) {
        await this.env.DB.batch(data.slice(i, i + 100).map(item => 
          this.env.DB.prepare('INSERT INTO records (id, normalized) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET normalized = excluded.normalized').bind(item.id, item.normalized)
        ));
      }
    });
  }
}
```

## Human-in-the-Loop Approval

```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
type Params = { userId: string };

export class ApprovalWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    await step.do('create approval', async () => { await this.env.DB.prepare('INSERT INTO approvals (id, user_id, status) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING').bind(event.instanceId, event.payload.userId, 'pending').run(); });
    const approval = await step.waitForEvent<{ approved: boolean }>('wait for approval', { type: 'approval-response', timeout: '48 hours' });
    if (approval.payload.approved) {
      await step.do('process approval', async () => {});
    } else {
      await step.do('handle rejection', async () => {});
    }
    // A timeout remains a workflow failure unless a specific timeout policy is implemented.
    // Never catch processing failures and relabel them as approval timeouts.
  }
}
```

## Testing Workflows

### Setup

```typescript
// vitest.config.ts
import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: './wrangler.jsonc' } })]
});
```

### Introspection API

For TypeScript `await using`, include `ESNext.Disposable` in the test tsconfig libraries; use a supported modern compiler. This test uses the Cloudflare Vitest integration, not a plain Node environment.

```typescript
import { introspectWorkflowInstance } from 'cloudflare:test';

const id = crypto.randomUUID();
await using introspector = await introspectWorkflowInstance(env.MY_WORKFLOW, id);
await introspector.modify(async (m) => {
  await m.mockStepResult({ name: 'api call' }, { mocked: true });
});
await env.MY_WORKFLOW.create({ id, params: { userId: '123' } });
const result = await introspector.waitForStepResult({ name: 'fetch user', index: 1 });
// Step occurrence indexes are 1-based; omitting index also selects the first.
// Configure mocks before starting the instance; await using disposes them.
```

## Best Practices

### ✅ DO

1. **Granular steps**: One API call per step (unless proving idempotency)
2. **Idempotency**: Use atomic writes or a downstream idempotency contract; a separate check followed by a write can race
3. **Deterministic names**: Use static or step-output-based names
4. **Return state**: Persist via step returns, not variables
5. **Always await**: `await step.do()`, avoid dangling promises
6. **Deterministic conditionals**: Base on `event.payload` or step outputs
7. **Store large data externally**: R2/KV for data exceeding step return limit, return refs
8. **Batch creation**: `createBatch()` for multiple instances

### ❌ DON'T

1. **One giant step**: Breaks durability & retry control
2. **State outside steps**: Lost on hibernation
3. **Mutate events**: Events immutable, return new state
4. **Non-deterministic logic outside steps**: `Math.random()`, `Date.now()` must be in steps
5. **Side effects outside steps**: May duplicate on restart
6. **Non-deterministic step names**: Prevents caching
7. **Ignore timeouts**: `waitForEvent` throws, use try-catch
8. **Reuse instance IDs**: Must be unique within retention

## Orchestration Patterns

### Fan-Out (Parallel Processing)
```typescript
// Process one listed page; repeat with cursor until list.truncated is false.
const files = await step.do('list page', async () => {
  const page = await this.env.BUCKET.list();
  return {
    objects: page.objects.map(file => ({ key: file.key })),
    truncated: page.truncated,
    cursor: page.truncated ? page.cursor : null,
  };
});
await Promise.all(files.objects.map((file) => step.do(`process ${file.key}`, async () => {
  const object = await this.env.BUCKET.get(file.key);
  if (!object) throw new Error(`Missing object: ${file.key}`);
  return processFile(await object.arrayBuffer());
})));
```

### Parent-Child Workflows
```typescript
const childId = await step.do('start child', async () => {
  const id = `child-${event.instanceId}`;
  await this.env.CHILD_WORKFLOW.createBatch([{ id, params: { data: result.data } }]);
  return id;
});
await step.do('other work', async () => console.log(`Child started: ${childId}`));
```

### Race Pattern

`Promise.race` does not cancel the losing operation; both side effects can complete. Use only when that behavior is acceptable.
```typescript
const winner = await Promise.race([
  step.do('option A', async () => slowOperation()),
  step.do('option B', async () => fastOperation())
]);
```

### Scheduled Workflow Chain
```typescript
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from "cloudflare:workers";
type Params = { timestamp: number };
interface Env { DAILY_WORKFLOW: Workflow<Params> }

export default { async scheduled(event: ScheduledController, env: Env) { await env.DAILY_WORKFLOW.create({id: `daily-${event.scheduledTime}`, params: { timestamp: event.scheduledTime }}); }};
export class DailyWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    await step.do('daily task', async () => {});
    await step.sleep('wait 7 days', '7 days');
    await step.do('weekly followup', async () => {});
  }
}
```

See: [configuration.md](./configuration.md), [api.md](./api.md), [gotchas.md](./gotchas.md)
