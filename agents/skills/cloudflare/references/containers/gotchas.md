## Critical Gotchas

### ⚠️ WebSocket: fetch() vs containerFetch()

**Problem:** A WebSocket upgrade fails when `containerFetch()` is called through external Durable Object RPC.

**Cause:** The external RPC transport cannot return the WebSocket response. Inside the container Durable Object, `this.containerFetch(request)` supports upgrades.

**Fix:** Use the fetch handler transport, `stub.fetch(request)`, for external upgrades.

```typescript
// ❌ WRONG
return container.containerFetch(request);

// ✅ CORRECT
return container.fetch(request);
```

### ⚠️ startAndWaitForPorts() vs start()

**Problem:** "connection refused" after `start()`

**Cause:** `start()` does not wait for port readiness. Direct TCP/port operations need an explicit readiness wait. The SDK `fetch()` and `containerFetch()` methods already start the container and wait for their target port.

**Fix:** Use `startAndWaitForPorts()` for explicit prewarming or before direct port operations. Ordinary SDK fetch calls handle readiness.

```typescript
// Valid, but start() is redundant: fetch() handles startup and readiness.
await container.start();
return container.fetch(request);

// Explicit prewarming, useful when startup needs separate control.
await container.startAndWaitForPorts();
return container.fetch(request);
```

### Activity timeout during background work

Call `this.renewActivityTimeout()` when appropriate. Writing arbitrary Durable Object storage does not renew container activity. Use a bounded job lifetime and clear renewal timers; long work that must survive request termination needs durable orchestration.

### Startup across restarts

The SDK coordinates startup and readiness for `fetch()` and `containerFetch()`. Use `startAndWaitForPorts()` for explicit prewarming or direct port access; do not cache readiness in a permanent `initialized` boolean because the container can stop while its Durable Object remains alive. Reserve `blockConcurrencyWhile` for application state initialization that actually needs serialization. See the [Container interface](https://developers.cloudflare.com/containers/reference/container-class/#start-and-stop).

### ⚠️ Lifecycle Hooks Block Requests

**Problem:** Container unresponsive during `onStart()`

**Cause:** Hooks run in `blockConcurrencyWhile` - no concurrent requests

**Fix:** Keep hooks fast, avoid long operations

### ⚠️ Don't Override alarm() When Using schedule()

**Problem:** Scheduled tasks don't execute

**Cause:** `schedule()` uses `alarm()` internally

**Fix:** Keep the inherited alarm handler and pass a callback method name to `schedule(delaySeconds, callback, payload)`.

## Common Errors

### "Container start timeout"

**Cause:** Container took >8s (`start()`) or >20s (`startAndWaitForPorts()`)

**Solutions:**
- Optimize image (smaller base, fewer layers)
- Check `entrypoint` correct
- Verify app listens on correct ports
- Increase timeout if needed

### "Port not available"

**Cause:** The target port is not listening within the readiness timeout, or direct TCP/port code skipped readiness.

**Solution:** Verify the target port and server bind address. Use `startAndWaitForPorts()` before direct port access.

### "Container memory exceeded"

**Cause:** Using more memory than instance type allows

**Solutions:**
- Use larger instance type (standard-2, standard-3, standard-4)
- Optimize app memory usage
- Use custom instance type

```jsonc
{ "instance_type": { "vcpu": 2, "memory_mib": 8192, "disk_mb": 16000 } }
```

### "Max instances reached"

**Cause:** All `max_instances` slots in use

**Solutions:**
- Increase `max_instances`
- Implement proper `sleepAfter`
- Use `getRandom()` for distribution
- Check for instance leaks

### "No container instance available"

**Cause:** Account capacity limits reached

**Solutions:**
- Check account limits
- Review instance types across containers
- Contact Cloudflare support

## Limits

Read the [current limits and instance types](https://developers.cloudflare.com/containers/platform/limits/) for account totals and allocation constraints. Cold start duration is workload-dependent. SDK startup timeouts are configurable and are not infrastructure capacity limits. Container disk is ephemeral; store durable state externally or in Durable Object storage.

## Best Practices

1. **Wait for ports before direct access** - SDK fetch calls already handle readiness
2. **Set appropriate `sleepAfter`** - Balance resources vs cold starts
3. **Use stub `fetch()` for external WebSocket upgrades** - `this.containerFetch()` is valid inside the Durable Object
4. **Design for restarts** - Ephemeral disk, implement graceful shutdown
5. **Monitor resources** - Stay within account limits
6. **Keep hooks fast** - Run in `blockConcurrencyWhile`
7. **Renew activity for long ops** - Use `renewActivityTimeout()`

## Beta Caveats

⚠️ Containers in **beta**:

- **API may change** without notice
- **No SLA** guarantees
- **Limited regions** initially
- **No autoscaling** - manual via `getRandom()`
- **Rolling deploys** only (not instant like Workers)

Plan for API changes, test thoroughly before production.
