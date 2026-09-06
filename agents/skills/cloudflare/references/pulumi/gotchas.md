# Pulumi Troubleshooting

## Version/schema mismatch

Provider 6.20.0 uses `WorkerScript.scriptName`, `mainModule`, and `bindings`. Old `name`, `module: true`, and `*Bindings` examples do not type-check. Queue creation uses `queueName`; consumers use `QueueConsumer`. Routes/domains are `WorkersRoute`/`WorkersCustomDomain`. Run the project's TypeScript check before any deployment.

Pulumi 3.261.0 excludes TypeScript 7 from its optional peer range. Use a supported TypeScript version for the Pulumi project; do not override dependency resolution to hide the incompatibility.

## Code and updates

Pulumi does not bundle raw TypeScript into a Worker. Build first, upload compiled module code, and set `mainModule`. An import error can also mean a service-worker/module syntax mismatch; inspect the artifact and metadata.

When no change is detected, inspect the actual built bytes and content hash. Whitespace removed by bundling can legitimately produce an identical artifact. For `contentFile`, compute `contentSha256` from those bytes. Do not introduce timestamps that redeploy on every preview/update.

Command resources with only an unchanged `create` string do not automatically rerun for changed source files. Add deterministic triggers/update commands or build in CI before Pulumi evaluation.

## Config and resources

- Pulumi does not consume Wrangler bindings automatically. Keep an explicit ownership/export process and compare generated local config against deployed resources.
- Missing `accountId`/wrong credentials: inspect selected stack and provider; do not print secrets.
- Missing binding: compare the exact runtime name and binding type with the version actually deployed.
- Database exists but schema does not: run the versioned migration pipeline, explicitly targeting the intended remote database.
- A created Worker version receives no traffic until a deployment selects it. Bindings go on the version, not the deployment.
- Imported resources show diffs: reconcile code/state with the exact provider import contract and actual resource before applying changes.
- Missing asset files: `assets.path` is not a provider upload mechanism. Complete the supported assets upload flow or retain a single Wrangler deployment owner.

## Limits and verification

Cloudflare product limits are independent of Pulumi. Read current [Workers limits](https://developers.cloudflare.com/workers/platform/limits/), [Pages limits](https://developers.cloudflare.com/pages/platform/limits/), and each storage/Queues limit page before capacity estimates. Do not reuse obsolete compressed bundle limits, made-up KV operation rates, or a universal Paid-plan quota table.

Verification sequence: compile resource code, inspect `pulumi preview` for the intended stack, perform only authorized changes, and then verify actual route/handler/binding behavior. Type-checking alone does not prove provisioning or service availability.

References: [configuration.md](configuration.md), [api.md](api.md), [patterns.md](patterns.md), [provider registry](https://www.pulumi.com/registry/packages/cloudflare/).
