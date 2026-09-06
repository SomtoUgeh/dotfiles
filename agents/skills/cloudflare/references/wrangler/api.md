# Wrangler Programmatic API

Use the project's installed Wrangler and inspect its exports/types before selecting an API. Verified with Wrangler 4.129.0: `createTestHarness`, `getPlatformProxy`, and `unstable_startWorker` exist; `startWorker` does not. The unstable API has no stability guarantee.

## Integration tests

```typescript
import { createTestHarness } from "wrangler";
import assert from "node:assert/strict";

const server = createTestHarness({
  workers: [{ configPath: "./wrangler.jsonc" }],
});
try {
  await server.listen();
  const response = await server.fetch("https://example.test/");
  assert.equal(response.status, 200);
} finally {
  await server.close();
}
```

Add other Workers to `workers` and declare their service bindings in config. Use `getWorker(name)` for a particular Worker. Test only local resources by default; remote bindings access real account data. Check support against the installed version before adding remote-resource tests.

## Bindings in Node.js

```typescript
import { getPlatformProxy } from "wrangler";

interface Env { MY_KV: KVNamespace }
const proxy = await getPlatformProxy<Env>({
  configPath: "./wrangler.jsonc",
  persist: false,
});
try {
  await proxy.env.MY_KV.put("test-key", "test-value");
  console.log(await proxy.env.MY_KV.get("test-key"));
} finally {
  await proxy.dispose();
}
```

Generate the binding types with the project-local `wrangler types`. `getPlatformProxy` provides bindings to Node code; it does not execute the Worker's request handler.

## Advanced development APIs

For a programmatic development server use the Cloudflare Vite plugin and Vite's `createServer`. Existing Wrangler integrations can use `unstable_startWorker` with the installed package's exact parameter types. Do not copy options from Miniflare or `getPlatformProxy`: they use different shapes. In Wrangler 4.129.0, lifecycle events are on `worker.raw`; `worker.on`, top-level `remote: "minimal"`, and `{ bindings: { AUTH: anotherWorker } }` are not supported contracts.

See the [official API reference](https://developers.cloudflare.com/workers/wrangler/api/) for version-specific reconfiguration and the [test harness guide](https://developers.cloudflare.com/workers/testing/integration-test-harness/) for mocks and storage setup. For in-runtime unit tests use the [Vitest pattern](./patterns.md#testing-with-vitest).
