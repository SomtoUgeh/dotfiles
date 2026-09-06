# Miniflare API

The following method names were checked against Miniflare 5.20260903.0-alpha. Import the package's own types for exact request, response, binding, and event signatures.

| Operation | Method |
|---|---|
| Ready URL | `await mf.ready` |
| Fetch | `await mf.dispatchFetch(url, init)` |
| Particular Worker | `await mf.getWorker(name)` |
| Environment | `await mf.getBindings(name)` |
| Request metadata | `await mf.getCf()` |
| Storage binding | `getKVNamespace`, `getR2Bucket`, `getD1Database`, `getDurableObjectNamespace` |
| Cache/Queue | `getCaches`, `getQueueProducer` |
| Replace configuration | `await mf.setOptions(completeOptions)` |
| Inspector | `await mf.getInspectorURL()` |
| Cleanup | `await mf.dispose()` |
  
`dispatchFetch()` waits for startup; it does not prevent the local runtime from binding a port. Use `port: 0` to avoid collisions.
  
## Scheduled and Queue events
  
```js
const worker = await mf.getWorker();
await worker.scheduled({ cron: "0 0 * * *" });
await worker.queue("tasks", [
  { id: "one", timestamp: new Date(), body: { item: 1 }, attempts: 1 },
]);
```

The target Worker must implement those handlers and have matching configuration. Assert the returned outcome and side effects in real tests.

## Durable Objects

Obtain a namespace with `getDurableObjectNamespace(bindingName)`, select a stub, and exercise its public interface. `getDurableObjectStorage(id)` does not exist. For storage inspection, prefer the harness's `getDurableObjectStorage` or the Vitest `runInDurableObject` helper; their arguments and return types differ. The v5 low-level `unsafeGetDurableObjectStorage` is explicitly unstable and takes a script name, class name, and instance selector.

## Lifecycle and bindings

Use `try/finally` as in the [complete example](./README.md#quick-start-miniflare-5). Close filesystem watchers as well as disposing Miniflare. Reloads should supply a full valid configuration and be serialized so overlapping watch events do not race. Log binding names only, never values.

Miniflare's Node-facing Request/Response types differ from runtime global types. Use inferred package types for tests and generated Wrangler types inside the Worker.
