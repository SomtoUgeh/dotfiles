# Binding Gotchas and Troubleshooting

## Binding lifetime

Handler-injected `env` is convenient for explicit dependencies. Modern Workers also support `import { env } from "cloudflare:workers"`; global access is not inherently an error. Avoid I/O during module initialization, and do not assume a globally cached client will be rebuilt after binding-only changes. Test secret rotation against the actual deployment mechanism.

## Common Errors

### "env.MY_KV is undefined"

**Cause:** Name mismatch or not configured  
**Solution:** Check wrangler.jsonc (case-sensitive), run `npx wrangler types`, verify `npx wrangler kv namespace list`

### "Property 'MY_KV' does not exist on type 'Env'"

**Cause:** Types not generated  
**Solution:** `npx wrangler types`

### "preview_id is required for --remote"

**Cause:** Missing preview binding  
**Solution:** Add `"preview_id": "dev-id"` or use `npx wrangler dev` (local mode)

### "Secret updated but Worker still uses old value"

**Cause:** Cached in global scope or not redeployed  
**Solution:** Check the target environment and active deployment, then inspect derived-client caching. `wrangler secret put` updates the deployed secret; do not assume a second deploy is always required.

### "KV get() returns null for existing key"

**Cause:** Eventual consistency (potentially 60 seconds or more), wrong namespace, wrong environment
**Solution:**
```bash
# Check key exists
npx wrangler kv key get --binding=MY_KV "your-key"

# Verify namespace ID
npx wrangler kv namespace list

# Check environment
npx wrangler deployments list
```

### "D1 database not found"

**Solution:** `npx wrangler d1 list`, verify ID in wrangler.jsonc

### "Service binding returns 'No such service'"

**Cause:** Target Worker not deployed, name mismatch, environment mismatch  
**Solution:**
```bash
# List deployed Workers
npx wrangler deployments list --name=target-worker

# Check service binding config
cat wrangler.jsonc | grep -A2 services

# Deploy target first
cd ../target-worker && npx wrangler deploy
```

### "Rate limit exceeded" on KV writes

**Cause:** >1 write/second per key  
**Solution:** Use different keys, Durable Objects, or Queues

## Type Safety Gotchas

### Missing @cloudflare/workers-types

**Error:** `Cannot find name 'Request'`  
**Solution:** Generate and include `worker-configuration.d.ts` using the project-local `wrangler types`; avoid duplicate runtime declarations.

### Binding Type Mismatches

```typescript
// ❌ Wrong - KV returns string | null
const value: string = await env.MY_KV.get('key');

// ✅ Handle null
const value = await env.MY_KV.get('key');
if (value === null) return new Response('Not found', { status: 404 });
```

## Environment Gotchas

### Wrong Environment Deployed

**Solution:** Check `npx wrangler deployments list`, use `--env` flag

### Secrets Not Per-Environment

**Solution:** Set per environment: `npx wrangler secret put API_KEY --env staging`

## Development Gotchas

**wrangler dev vs deploy:**
- dev: Uses `preview_id` or local bindings, secrets not available
- deploy: Uses production `id`, secrets available

**Local secrets:** Put development values in gitignored `.dev.vars`; select remote execution only when the task requires real resources.
**Persist local data:** `npx wrangler dev --persist-to .wrangler/state`

## Performance Gotchas

### Sequential Binding Calls

```typescript
// ❌ Slow
const user = await env.DB.prepare('...').first();
const config = await env.MY_KV.get('config');

// ✅ Parallel
const [user, config] = await Promise.all([
  env.DB.prepare('...').first(),
  env.MY_KV.get('config')
]);
```

## Security Gotchas

**❌ Secrets in logs:** `console.log('Key:', env.API_KEY)` - visible in dashboard  
**✅** `console.log('Key:', env.API_KEY ? '***' : 'missing')`

**❌ Exposing env:** `return Response.json(env)` - exposes all bindings  
**✅** Never return env object in responses

## Limits Reference

Use the current [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) and each storage product's limit/pricing page. Do not infer one universal binding cap, service-call allowance, D1 row cap, or free request allocation from this catalog. Free allocations and hard limits are different.

## Debugging Tips

```bash
# Check configuration
npx wrangler deploy --dry-run       # Validate config without deploying
npx wrangler kv namespace list      # List KV namespaces
npx wrangler secret list            # List secrets (not values)
npx wrangler deployments list       # Recent deployments

# Inspect bindings
npx wrangler kv key list --binding=MY_KV
npx wrangler kv key get --binding=MY_KV "key-name"
npx wrangler r2 object get my-bucket/file.txt
npx wrangler d1 execute my-db --command="SELECT * FROM sqlite_master"

# Test locally
npx wrangler dev                  # Local mode
npx wrangler dev --remote         # Production bindings
npx wrangler dev --persist-to .wrangler/state        # Persist data across restarts

# Verify types
npx wrangler types
rg "interface Env" worker-configuration.d.ts

# Debug specific binding issues
npx wrangler tail                 # Stream logs in real-time
npx wrangler tail --format=pretty # Formatted logs
```

## See Also

- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Wrangler Commands](https://developers.cloudflare.com/workers/wrangler/commands/)
