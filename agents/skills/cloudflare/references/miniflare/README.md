# Miniflare

Miniflare runs Workers locally in workerd. Select the API from the installed version before copying examples. On 2026-09-05, npm `latest` resolves to `5.20260903.0-alpha`; its constructor requires `workers` entries with a `config`. The older top-level `script`, `scriptPath`, and `kvNamespaces` examples do not work unchanged.

For applications with Wrangler config, prefer the verified [Wrangler integration test harness](../wrangler/api.md). For tests inside workerd, use the [Vitest integration](../wrangler/patterns.md#testing-with-vitest). Use direct Miniflare when you need low-level runtime configuration.

## Quick start: Miniflare 5

The following example was run with `miniflare@5.20260903.0-alpha`:

```js
import { Miniflare } from "miniflare";
import assert from "node:assert/strict";

const mf = new Miniflare({
  port: 0,
  cf: false,
  workers: [{
    config: {
      name: "test",
      type: "worker",
      compatibilityDate: "2026-09-05",
      manifest: {
        mainModule: "index.js",
        modules: {
          "index.js": {
            type: "esm",
            contents: `export default {
              async fetch(request, env) {
                await env.KV.put("key", "value");
                return new Response(await env.KV.get("key"));
              }
            }`,
          },
        },
      },
      env: { KV: { type: "kv", id: "test-kv" } },
    },
  }],
});
try {
  const response = await mf.dispatchFetch("http://test/");
  assert.equal(await response.text(), "value");
  const kv = await mf.getKVNamespace("KV");
  assert.equal(await kv.get("key"), "value");
} finally {
  await mf.dispose();
}
```

Pin the version used for low-level tooling; an alpha API can change. Do not upgrade an existing project's major version merely to match this example. For a project still using v4, use its installed `MiniflareOptions` types and corresponding [upstream source](https://github.com/cloudflare/workers-sdk/tree/main/packages/miniflare).

For TypeScript host tests, also install a matching `@cloudflare/workers-types` package: Miniflare 5's declarations import its types, but the alpha package does not install it. Missing declarations can produce misleading return types when `skipLibCheck` hides the missing import. Use a Node TypeScript configuration for the test runner; keep generated Worker globals in the separate Worker configuration.

Local execution is not inherently offline: Worker fetches, `cf: true`, and remote bindings can use the network. Mock outbound requests for isolated tests.

- [Configuration](./configuration.md)
- [API](./api.md)
- [Testing patterns](./patterns.md)
- [Troubleshooting](./gotchas.md)

## Existing Miniflare 4 projects

This recipe was separately executed against `miniflare@4.20260730.0` (the latest published v4 version at verification). It preserves that version's supported constructor contract:

```js
import { Miniflare } from "miniflare";
import assert from "node:assert/strict";

const mf = new Miniflare({
  port: 0,
  cf: false,
  modules: true,
  compatibilityDate: "2026-07-30",
  kvNamespaces: ["KV"],
  script: `export default {
    async fetch(request, env) {
      await env.KV.put("key", "value");
      return new Response(await env.KV.get("key"));
    }
  }`,
});
try {
  const response = await mf.dispatchFetch("http://test/");
  assert.equal(await response.text(), "value");
} finally {
  await mf.dispose();
}
```

For v4, file-based modules use `modules: true` with compiled `scriptPath`; named storage bindings use `kvNamespaces`, `r2Buckets`, or `d1Databases`, with their matching persistence options. SQL-backed Durable Objects use `{ className: "Counter", useSQLite: true }`. Check the installed v4 types for the full option set. These fields belong to v4 and must not be copied unchanged into v5.
