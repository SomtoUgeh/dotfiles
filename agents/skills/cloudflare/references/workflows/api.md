# Workflow APIs

## Step APIs

```typescript
// step.do()
const result = await step.do('step name', async () => { /* logic */ });
const result = await step.do('step name', { retries, timeout }, async () => {});

// step.sleep()
await step.sleep('description', '1 hour');
await step.sleep('description', 5000); // ms

// step.sleepUntil()
await step.sleepUntil('description', Date.parse(event.payload.deadline));

// step.waitForEvent()
const received = await step.waitForEvent<PayloadType>('wait', {type: 'webhook-type', timeout: '24 hours'});
const data = received.payload;
try { const event = await step.waitForEvent('wait', { type: 'approval', timeout: '1 hours' }); } catch (e) { /* Timeout */ }
```

## WorkflowStepContext

The `WorkflowStepContext` is passed as the first argument to the `step.do()` callback. It provides runtime information about the current step execution.

```typescript
type WorkflowStepContext = {
  step: {
    name: string;   // Step name as passed to step.do()
    count: number;  // How many times step.do() called with this name in current run (1-indexed)
  };
  attempt: number;  // Current attempt number (1-indexed): 1 = first try, 2 = first retry, etc.
  config: WorkflowStepConfig; // Resolved config for this step, including runtime defaults
};
```

**Use cases:**
```typescript
// Adjust behavior based on retry attempt
await step.do('call api', { retries: { limit: 3, delay: '5 seconds', backoff: 'exponential' } }, async (ctx) => {
  if (ctx.attempt > 1) console.log(`Retry attempt ${ctx.attempt} for step "${ctx.step.name}"`);
  const res = await fetch('https://api.example.com/data');
  if (!res.ok) throw new Error(`API failed (attempt ${ctx.attempt})`);
  return res.text(); // Validate against your schema when decoding JSON.
});

```

## Instance Management

```typescript
// Create single
const instance = await env.MY_WORKFLOW.create({id: crypto.randomUUID(), params: { userId: 'user123' }}); // id optional, auto-generated if omitted; throws if ID already exists within retention period

// Create with custom retention (check docs for default per plan)
const instance = await env.MY_WORKFLOW.create({
  id: crypto.randomUUID(),
  params: { userId: 'user123' },
  retention: { successRetention: '30 days', errorRetention: '30 days' }
});

// Batch (max 100, idempotent: skips existing IDs)
const instances = await env.MY_WORKFLOW.createBatch([{id: 'user1', params: {name: 'John'}}, {id: 'user2', params: {name: 'Jane'}}]);

// Get & Status
const instance = await env.MY_WORKFLOW.get('instance-id');
const status = await instance.status(); // {status: 'queued' | 'running' | 'paused' | 'errored' | 'terminated' | 'complete' | 'waiting' | 'waitingForPause' | 'unknown', error?, output?}

// Control
await instance.pause(); await instance.resume(); await instance.terminate(); await instance.restart();

// Send Events
await instance.sendEvent({type: 'approval', payload: { approved: true }}); // Must match waitForEvent type
```

## Triggering Workflows

```typescript
// From Worker
export default { async fetch(req, env) { const instance = await env.MY_WORKFLOW.create({id: crypto.randomUUID(), params: { userId: 'user123' }}); return Response.json({ id: instance.id }); }};

// From Queue
export default { async queue(batch, env) { for (const msg of batch.messages) { await env.MY_WORKFLOW.createBatch([{id: `job-${msg.id}`, params: msg.body}]); msg.ack(); } }};

// From Cron
export default { async scheduled(event, env) { await env.CLEANUP_WORKFLOW.create({id: `cleanup-${event.scheduledTime}`, params: { timestamp: event.scheduledTime }}); }};

// From Another Workflow (non-blocking)
export class ParentWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    const childId = await step.do('start child', async () => {
      const id = `child-${event.instanceId}`;
      await this.env.CHILD_WORKFLOW.createBatch([{ id, params: {} }]);
      return id; // Persist an ID, not a WorkflowInstance handle
    });
  }
}
```

## Error Handling

```typescript
import { NonRetryableError } from 'cloudflare:workflows';

// NonRetryableError
await step.do('validate', async () => {
  if (!event.payload.paymentMethod) throw new NonRetryableError('Payment method required');
  const res = await fetch('https://api.example.com/charge', { method: 'POST' });
  if (res.status === 401) throw new NonRetryableError('Invalid credentials'); // Don't retry
  if (!res.ok) throw new Error('Retryable failure'); // Will retry
  return res.text(); // Validate against your schema when decoding JSON.
});

// Catching Errors
try { await step.do('risky op', async () => { throw new NonRetryableError('Failed'); }); } catch (e) { await step.do('cleanup', async () => {}); }

// Idempotency: requires downstream support for the Idempotency-Key contract.
await step.do('charge', async () => {
  const response = await fetch(`https://api.example.com/subscriptions/${id}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': `charge-${event.instanceId}` },
    body: JSON.stringify({ amount: 10.0 }),
  });
  if (!response.ok) throw new Error(`Charge failed: ${response.status}`);
  return response.text(); // Validate against your schema when decoding JSON.
});
```

## Type Constraints

Params and step returns must be `Rpc.Serializable<T>`:

```typescript
// ✅ Valid types
type ValidParams = {
  userId: string;
  count: number;
  tags: string[];
  metadata: Record<string, unknown>;
};

// ❌ Invalid types
type InvalidParams = {
  callback: () => void;      // Functions not serializable
  symbol: symbol;            // Symbols not serializable
  circular: any;             // Circular references not allowed
};

// Step returns follow same rules
const result = await step.do('fetch', async () => {
  return { userId: '123', data: [1, 2, 3] }; // ✅ Plain object
});

// ✅ ReadableStream<Uint8Array> for large binary output (bypasses non-stream step result size limit)
const stream = await step.do('read from R2', async () => {
  const obj = await this.env.BUCKET.get('large-file.csv');
  if (!obj) throw new Error("Object not found");
  return obj.body; // Return the ReadableStream directly
});
```

## Sleep & Scheduling

```typescript
// Relative
await step.sleep('wait 1 hour', '1 hour');
await step.sleep('wait 30 days', '30 days');
await step.sleep('wait 5s', 5000); // ms

// Absolute: caller supplies validated future ISO timestamps.
await step.sleepUntil('launch date', Date.parse(event.payload.launchAt));
await step.sleepUntil('deadline', new Date(event.payload.deadline));
```

Units: second, minute, hour, day, week, month, year.
Sleeping instances don't count toward concurrency.
`sleepUntil()` rejects a target in the past. Choose targets that remain in the
future when the step is first reached, including any preceding sleeps; do not
copy a fixed historical date or recompute a deadline on every replay.

## Parameters

**Pass from Worker:**
```typescript
const instance = await env.MY_WORKFLOW.create({
  id: crypto.randomUUID(),
  params: { userId: 'user123', email: 'user@example.com' }
});
```

**Access in Workflow:**
```typescript
async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
  const userId = event.payload.userId;
  const instanceId = event.instanceId;
  const createdAt = event.timestamp;
}
```

**CLI Trigger:**
```bash
npx wrangler workflows trigger my-workflow '{"userId":"user123"}'
```

## Wrangler CLI

```bash
npm create cloudflare@latest my-workflow -- --template "cloudflare/workflows-starter"
npx wrangler deploy
npx wrangler workflows list
npx wrangler workflows trigger my-workflow '{"userId":"user123"}'
npx wrangler workflows instances list my-workflow
npx wrangler workflows instances describe my-workflow instance-id
npx wrangler workflows instances pause my-workflow instance-id
npx wrangler workflows instances resume my-workflow instance-id
npx wrangler workflows instances terminate my-workflow instance-id
```

## REST API

Use the [current REST reference](https://developers.cloudflare.com/api/resources/workflows/subresources/instances/) and check the HTTP result:

- Create: `POST /accounts/{account_id}/workflows/{workflow_name}/instances`
- Inspect: `GET /accounts/{account_id}/workflows/{workflow_name}/instances/{instance_id}`
- Change status: `PATCH /accounts/{account_id}/workflows/{workflow_name}/instances/{instance_id}/status`
- Send event: `POST /accounts/{account_id}/workflows/{workflow_name}/instances/{instance_id}/events/{event_type}` with the event payload as the JSON body.

The event type belongs in the REST URL; the binding's `sendEvent({ type, payload })` shape is a different API.

See: [configuration.md](./configuration.md), [patterns.md](./patterns.md)
