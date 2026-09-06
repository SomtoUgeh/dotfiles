# Miniflare configuration

Start with the complete [Miniflare 5 example](./README.md#quick-start-miniflare-5). Validate options against the project's installed `MiniflareOptions`, not snippets from another major version.

## Runtime and modules

- Server options (`port`, `host`, `cf`, `inspectorPort`) belong at the top level. Use `port: 0` for an available port and `cf: false` for deterministic tests.
- Each `workers` entry has `config.name`, `config.type: "worker"`, and `config.compatibilityDate`.
- Compiled modules belong in `config.manifest`; the `mainModule` must name an entry in `modules`. Use `type: "esm"` for an ES module.
- Miniflare does not transpile TypeScript or automatically read Wrangler config. Build JavaScript first or use [Wrangler's harness](../wrangler/api.md).
- Match production's tested compatibility date and flags. Updating the date changes behavior; it is not a generic fix for a failed test.

## Bindings and multiple Workers

In v5, `config.env` maps binding names to typed binding descriptors. The quick start demonstrates a KV descriptor. Other storage, service, Queue, and Durable Object descriptors have different required fields: check the installed schema before constructing them. Prefer Wrangler config through the harness when configuring an application's full binding graph; this avoids manually translating storage and migration rules.

List each Worker as another `workers` entry. Worker names and service binding targets must agree. Use a fake Worker service for API mocks and isolate storage per test. For SQL-backed Durable Objects, configure the exported class with SQLite enabled using the selected API; a plain class name does not establish SQL storage in older APIs.

## Persistence, logging, and inspection

Use the installed version's persistence configuration (`resourcePersistencePath` in v5); older per-product `kvPersist`/`r2Persist` examples use the v4 shape. Give parallel tests separate storage paths and dispose every instance. Do not reset a development database as routine test cleanup.

`log` accepts a Miniflare `Log` instance. Enable the inspector with `inspectorPort`, then use `getInspectorURL()`. Avoid logging binding values or secrets. `scriptTimeout` and `workersConcurrencyLimit` are not supported Miniflare options.
  
Wrangler and Miniflare expose different configuration schemas. Do not copy `wrangler.jsonc` directly into `new Miniflare()` or treat an upstream URL as a complete request fallback policy.
