# Miniflare testing patterns

## Choose the runtime

| Need | Approach |
|---|---|
| Pure function test | Normal Node test runner |
| Node business logic with bindings | `getPlatformProxy` |
| Request handler and multiple Workers | `createTestHarness` |
| Tests inside workerd | Cloudflare Vitest plugin |
| Low-level runtime configuration | Direct Miniflare |

All binding-backed approaches use local workerd for platform behavior. `cloudflare:test` is provided by the Cloudflare Vitest integration; it cannot be imported into an ordinary Node Vitest environment.

## getPlatformProxy

Use the [complete proxy example](../wrangler/api.md#bindings-in-nodejs), create local test values, assert their behavior, and dispose in `finally`. Do not assume remote secrets or account storage are present.

## Vitest

Use the [version-compatible ESM setup](../wrangler/patterns.md#testing-with-vitest). Assert response status, body, and relevant binding effects. A successful request alone does not verify storage isolation, retry behavior, or external delivery.

## Direct Miniflare

Start with the [executed v5 example](./README.md#quick-start-miniflare-5). Build TypeScript first. Create isolated instances or reset test storage between tests; use unique persistence paths in parallel runs. Always dispose on assertion failure. `dispatchFetch()` still starts a local runtime server, so choose an available port.

For HTTP integration tests with Wrangler configuration use the [harness](../wrangler/api.md#integration-tests), including its multi-Worker and storage setup support.

## Events and WebSockets

Use [event dispatch methods](./api.md#scheduled-and-queue-events) with configured handlers. For a WebSocket response, assert status 101, confirm a socket exists, accept the client endpoint, exchange a message, and close it. An upgrade status alone does not verify message handling or hibernation.

## Mocks and migration

Inject a mock service binding or use the test runner's outbound mocking support; reject unexpected external requests. Do not treat local mode as automatic network isolation.

When migrating from `unstable_dev`, use `createTestHarness` for a config-driven test. Passing a `.ts` source path directly to Miniflare does not preserve Wrangler's bundling. For low-level v4-to-v5 migration, inspect the installed `convertV4MiniflareOptions` helper and v5 types rather than inventing a conversion.
