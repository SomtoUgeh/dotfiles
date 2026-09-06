# Pulumi Architecture Patterns

## Component resources

Use components for actual shared ownership. Declare outputs, parent child resources, and register outputs:

```typescript
interface WorkerAppArgs {
  accountId: pulumi.Input<string>;
  code: pulumi.Input<string>;
}
class WorkerApp extends pulumi.ComponentResource {
  readonly worker: cloudflare.WorkerScript;
  readonly kv: cloudflare.WorkersKvNamespace;

  constructor(name: string, args: WorkerAppArgs, opts?: pulumi.ComponentResourceOptions) {
    super('example:cloudflare:WorkerApp', name, {}, opts);
    this.kv = new cloudflare.WorkersKvNamespace(`${name}-kv`, {
      accountId: args.accountId, title: `${name}-kv`,
    }, { parent: this });
    this.worker = new cloudflare.WorkerScript(`${name}-worker`, {
      accountId: args.accountId, scriptName: `${name}-worker`,
      mainModule: 'index.js', content: args.code, compatibilityDate: '2026-09-05',
      bindings: [{ type: 'kv_namespace', name: 'KV', namespaceId: this.kv.id }],
    }, { parent: this });
    this.registerOutputs({ scriptName: this.worker.scriptName, namespaceId: this.kv.id });
  }
}
```

## Full-stack and service-bound applications

Create storage once and pass its outputs to the Worker's `bindings` array; see [configuration.md](configuration.md). For microservices, use `{ type: 'service', name: 'AUTH', service: authWorker.scriptName }`. Keep credentials in secret Outputs and choose resource names per stack, such as `app-${pulumi.getStack()}`.

For event processing, create `Queue` and `QueueConsumer` separately. The producer binding uses `queueName`; the consumer uses `queueId` and the consumer Worker's `scriptName`. Runtime retries and idempotency remain application responsibilities, not infrastructure guarantees.

## Build before infrastructure evaluation

Build in CI before `pulumi preview`/`pulumi up`, then load the resulting artifact. Reading the file during evaluation requires it to exist at preview time too.

If a Pulumi command owns the build, include both `create` and `update` commands and a deterministic source hash trigger. `dependsOn` only orders execution; it does not rerun an unchanged command when source files change. Avoid using stdout as a fake build-content hash.

For file-backed script content:

```typescript
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const contentFile = './dist/index.js';
const contentSha256 = createHash('sha256').update(readFileSync(contentFile)).digest('hex');
const worker = new cloudflare.WorkerScript('worker', {
  accountId, scriptName: 'app-worker', mainModule: 'index.js',
  contentFile, contentSha256, compatibilityDate: '2026-09-05',
});
```

Do not add `Date.now()` bindings to force every run to redeploy. Changes in actual content or its hash should drive updates.

## D1 migration sequencing

Create/resolve the database, apply versioned migrations against the intended remote database, and deploy code that needs that schema. Make the migration step depend on the database and the deployment depend on successful migration. Include migration-content changes in update triggers; do not use an untracked `CREATE TABLE` side effect in `apply()`.

## Local Wrangler configuration

Decide which system owns bindings and deployment. Export a plain JSON configuration artifact from resolved non-secret stack outputs using a dedicated build/CI step, rather than interpolating arbitrary values into shell heredocs. Preserve a tested compatibility date and local-versus-remote resource semantics. Secrets belong in local secret files or environment configuration, never generated committed config.

## Gradual rollouts

Use the versioning pattern in [api.md](api.md). Bindings travel with versions; a deployment only selects percentages. Ensure schema changes and Durable Object migrations are compatible with all simultaneously active versions, then validate the real route before increasing traffic.
