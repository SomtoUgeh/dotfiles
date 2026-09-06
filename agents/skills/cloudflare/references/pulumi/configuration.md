# Pulumi Resource Configuration

Use the imports/account configuration from [README.md](README.md). Examples target `@pulumi/cloudflare` 6.20.0. Values such as names/domains are examples; use the user's real resources.

## Storage and Queues

```typescript
const kv = new cloudflare.WorkersKvNamespace('kv', { accountId, title: 'app-kv' });
const db = new cloudflare.D1Database('db', { accountId, name: 'app-db' });
const bucket = new cloudflare.R2Bucket('bucket', { accountId, name: 'app-files' });
const queue = new cloudflare.Queue('queue', { accountId, queueName: 'app-jobs' });
```

Omit R2 `location` for automatic placement instead of inventing an `auto` location value. Distinguish queue ID from queue name: consumers identify the queue by ID; producer bindings use its name.

## Worker and bindings

```typescript
import { readFileSync } from 'node:fs';
const code = readFileSync('./dist/index.js', 'utf8');
const apiToken = new pulumi.Config().requireSecret('apiToken');

const worker = new cloudflare.WorkerScript('worker', {
  accountId,
  scriptName: 'app-worker',
  mainModule: 'index.js',
  content: code,
  compatibilityDate: '2026-09-05',
  bindings: [
    { type: 'kv_namespace', name: 'KV', namespaceId: kv.id },
    { type: 'd1', name: 'DB', id: db.id },
    { type: 'r2_bucket', name: 'BUCKET', bucketName: bucket.name },
    { type: 'queue', name: 'JOBS', queueName: queue.queueName },
    { type: 'secret_text', name: 'API_TOKEN', text: apiToken },
    { type: 'plain_text', name: 'STAGE', text: pulumi.getStack() },
    { type: 'analytics_engine', name: 'ANALYTICS', dataset: 'app_metrics' },
    { type: 'ai', name: 'AI' },
  ],
});
```

Provider v6 uses one typed-by-`type` bindings array, not `kvNamespaceBindings`, `secretTextBindings`, `module: true`, or `name` on `WorkerScript`. Other examples: `{ type: 'service', name: 'AUTH', service: auth.scriptName }`, `{ type: 'browser', name: 'BROWSER' }`, and `{ type: 'hyperdrive', name: 'HYPERDRIVE', id: hyperdrive.id }`. Add only bindings required by the application.

Queue consumers are separate resources, not WorkerScript properties:

```typescript
const consumer = new cloudflare.QueueConsumer('consumer', {
  accountId, queueId: queue.id, type: 'worker', scriptName: worker.scriptName,
  settings: { batchSize: 10, maxRetries: 3, maxWaitTimeMs: 5000 },
});
```

The target Worker must actually export a `queue()` handler. Configure a dead-letter queue and idempotent effects as the application requires.

## Routes, domains and DNS

```typescript
const route = new cloudflare.WorkersRoute('route', {
  zoneId, pattern: 'example.com/api/*', script: worker.scriptName,
});
const domain = new cloudflare.WorkersCustomDomain('domain', {
  accountId, zoneId, hostname: 'api.example.com', service: worker.scriptName,
});
const zone = cloudflare.getZone({ filter: { name: 'example.com' } });
const record = new cloudflare.DnsRecord('www', {
  zoneId: zone.then(value => value.id), name: 'www', type: 'A',
  content: '192.0.2.1', ttl: 1, proxied: true,
});
```

Use a route or custom domain according to the desired routing model; do not create redundant routing resources by copying every example.

## Pages

```typescript
const pages = new cloudflare.PagesProject('pages', {
  accountId, name: 'app-pages', productionBranch: 'main',
  buildConfig: { buildCommand: 'npm run build', destinationDir: 'dist' },
  deploymentConfigs: {
    production: {
      envVars: { NODE_VERSION: { type: 'plain_text', value: '22' } },
      kvNamespaces: { KV: { namespaceId: kv.id } },
      d1Databases: { DB: { id: db.id } },
    },
  },
});
```

Git integration requires an authorized source connection; creating a project alone does not establish provider credentials or build/deploy application files.

## Assets and D1 migrations

`WorkerScript.assets` takes upload metadata/configuration, not a local `path`. A valid assets upload must produce the required completion token; use the provider's current upload workflow or keep asset deployment under Wrangler. Do not have two tools own the same deployment without an explicit ownership model.

D1 schema migrations are separate from database creation. Apply checked-in migrations through the established deployment pipeline with `wrangler d1 migrations apply <binding-or-name> --remote` against the intended account/database, then deploy dependent code. Previewing infrastructure should not run schema writes.

See [api.md](api.md) for versioned uploads and [patterns.md](patterns.md) for reproducible build dependencies.
