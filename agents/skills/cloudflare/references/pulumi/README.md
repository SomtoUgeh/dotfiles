# Cloudflare Pulumi Provider

Manage Cloudflare resources with `@pulumi/cloudflare`. These examples were checked against provider 6.20.0 and Pulumi 3.261.0; resource names and argument shapes differ substantially from older releases. Inspect the installed declarations before applying examples.

## Setup and authentication

Use the project's package manager to install `@pulumi/cloudflare` and `@pulumi/pulumi`. Pulumi 3.261.0's optional TypeScript peer range is `>=3.8.3 <7`; TypeScript 6.0.3 was used for these checks. Do not force an incompatible dependency tree.

```yaml
# Pulumi.yaml
name: my-cloudflare-app
runtime: nodejs
```

Use `CLOUDFLARE_API_TOKEN` in the deployment environment, or store provider credentials with `pulumi config set --secret cloudflare:apiToken`. Do not expect `${ENV_VAR}` in a Pulumi YAML value to perform shell interpolation. Keep account/zone IDs in ordinary stack configuration:

```typescript
import * as pulumi from '@pulumi/pulumi';
import * as cloudflare from '@pulumi/cloudflare';
const config = new pulumi.Config();
const accountId = config.require('accountId');
const zoneId = config.require('zoneId');
```

Other SDKs are `pulumi-cloudflare` (Python), `github.com/pulumi/pulumi-cloudflare/sdk/v6/go/cloudflare` (Go), and `Pulumi.Cloudflare` (.NET). Match their versions and generated schemas.

## Current resource map

| Need | Resource |
|---|---|
| Upload and deploy Worker script | `WorkerScript` (`scriptName`, `mainModule`, `bindings`) |
| Versioned Worker | `Worker`, `WorkerVersion`, `WorkersDeployment` |
| KV | `WorkersKvNamespace`, `WorkersKvValue` |
| D1 / R2 | `D1Database`, `R2Bucket` |
| Queue / consumer | `Queue`, `QueueConsumer` |
| Pages | `PagesProject` |
| DNS | `DnsRecord` |
| Worker route / custom domain | `WorkersRoute`, `WorkersCustomDomain` |

Build Worker code before Pulumi evaluation. Set a tested compatibility date, keep binding names consistent, and run `pulumi preview` against the intended stack. A successful type check proves API shape, not account permission or deployed runtime behavior.

## Reading order

- [configuration.md](configuration.md): resource and binding examples.
- [api.md](api.md): outputs, dependencies, imports, secrets, and versioning.
- [patterns.md](patterns.md): components, environments, build/migration workflows.
- [gotchas.md](gotchas.md): diagnosis and version differences.

Sources: [Provider registry](https://www.pulumi.com/registry/packages/cloudflare/), [API docs](https://www.pulumi.com/registry/packages/cloudflare/api-docs/), installed 6.20.0 declarations. Related: [Terraform](../terraform/), [Wrangler](../wrangler/), [Workers](../workers/).
