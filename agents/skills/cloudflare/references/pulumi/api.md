# Pulumi Outputs, Dependencies and Versioning

## Outputs and dependencies

Pass resource outputs directly into dependent resource arguments. `kv.id`, `db.id`, `bucket.name`, `queue.queueName`, and `worker.scriptName` create dependency edges. A Worker script name is not a URL: construct/export a URL only after its actual route/domain exists.

Use `dependsOn` for ordering not expressed by resource inputs. Do not run database mutations in `Output.apply`: it is value transformation, not a migration lifecycle or exactly-once executor. External commands need explicit create/update behavior and a source/migration hash as a trigger.

## Secrets

```typescript
const config = new pulumi.Config();
const apiToken = config.requireSecret('apiToken');
// Use apiToken as a secret_text binding value; Pulumi propagates secrecy.
```

Store with `pulumi config set --secret apiToken`. Keep credentials out of command strings/stdout. A custom dynamic provider must preserve secret outputs, validate HTTP/API success, implement read/diff/update/delete lifecycle semantics, and have an idempotency strategy. Prefer the maintained provider or an established migration tool to a generic SQL-in-create dynamic resource.

## Imports and lookups

Look up a zone with `cloudflare.getZone({ filter: { name: 'example.com' } })`. Use the installed provider's registry import section for each resource's exact import ID. Do not assume IDs are uniform across KV, scripts, buckets, and D1. After import, run `pulumi preview` and reconcile drift before applying changes.

## Versioned Worker deployment

```typescript
import { readFileSync } from 'node:fs';
const worker = new cloudflare.Worker('versioned', { accountId, name: 'versioned-worker' });
const code = readFileSync('./dist/index.js', 'utf8');
const version = new cloudflare.WorkerVersion('version', {
  accountId, workerId: worker.id, mainModule: 'index.js',
  compatibilityDate: '2026-09-05',
  modules: [{
    name: 'index.js', contentType: 'application/javascript+module',
    contentBase64: Buffer.from(code).toString('base64'),
  }],
  bindings: [{ type: 'kv_namespace', name: 'KV', namespaceId: kv.id }],
});
const deployment = new cloudflare.WorkersDeployment('deployment', {
  accountId, scriptName: worker.name, strategy: 'percentage',
  versions: [{ versionId: version.id, percentage: 100 }],
});
```

Bindings belong to each immutable version. Deployment uses `scriptName`, `strategy`, and a `versions` traffic-split array; it does not accept `workerId`, a singular `versionId`, or binding properties. For a canary, include both real version IDs with percentages totalling 100 and verify runtime/binding compatibility before shifting traffic.

## Argument customization

Prefer an ordinary typed function for local argument customization:

```typescript
function createBucket(
  name: string,
  args: cloudflare.R2BucketArgs,
  customize: (args: cloudflare.R2BucketArgs) => cloudflare.R2BucketArgs = value => value,
) {
  return new cloudflare.R2Bucket(name, customize(args));
}
```

Do not confuse this function with Pulumi resource transforms, which have their own callback contract. Use the installed Pulumi API when adding a resource transform.

Sources: [WorkerVersion](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workerversion/), [WorkersDeployment](https://www.pulumi.com/registry/packages/cloudflare/api-docs/workersdeployment/), installed provider 6.20.0 declarations.
