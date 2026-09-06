# Gotchas

## Functions Not Running

**Problem**: Function endpoints return 404 or don't execute
**Causes**: `_routes.json` excludes path; wrong file extension (`.jsx`/`.tsx`); `functions/` directory not at the project root
**Solution**: Check `_routes.json`, rename to `.ts`/`.js`, verify build output structure

## 404 on Static Assets

**Problem**: Static files not serving
**Causes**: Build output dir misconfigured; Functions catching requests; Advanced mode missing `env.ASSETS.fetch()`
**Solution**: Verify output dir, add exclusions to `_routes.json`, call `env.ASSETS.fetch()` in `_worker.js`

## Bindings Not Working

**Problem**: `env.BINDING` undefined or errors
**Causes**: wrangler.jsonc syntax error; wrong binding IDs; missing `.dev.vars`; out-of-sync types
**Solution**: Validate config, verify IDs, create `.dev.vars`, run `npx wrangler types`

## Build Failures

**Problem**: Deployment fails during build
**Causes**: Wrong build command/output dir; Node version incompatibility; missing env vars; 20min timeout; OOM
**Solution**: Check Dashboard → Deployments → Build log; verify settings; add `.nvmrc`; optimize build

## Middleware Not Running

**Problem**: Middleware doesn't execute
**Causes**: Wrong filename (not `_middleware.ts`); missing `onRequest` export; didn't call `next()`
**Solution**: Rename file with underscore prefix; export handler; call `next()` or return Response

## Headers/Redirects Not Working

**Problem**: `_headers` or `_redirects` not applying
**Causes**: Only work for static assets; Functions override; syntax errors; exceeded limits
**Solution**: Set headers in Response object for Functions; verify syntax; check limits (100 headers, 2,100 redirects)

## TypeScript Errors

**Problem**: Type errors in Functions code
**Causes**: Types not generated; Env interface doesn't match wrangler.jsonc
**Solution**: Run `npx wrangler types ./functions/types.d.ts`; update Env interface

## Local Dev Issues

**Problem**: Dev server errors or bindings don't work
**Causes**: Port conflict; bindings not passed; local vs HTTPS differences
**Solution**: Use `--port=3000`; pass bindings via CLI or wrangler.jsonc; account for HTTP/HTTPS differences

## Performance Issues

**Problem**: Slow responses or CPU limit errors
**Causes**: Functions invoked for static assets; cold starts; 10ms CPU limit (free) / 30s default (paid); large bundle
**Solution**: Exclude static via `_routes.json`; optimize hot paths; measure bundle size and startup cost against current limits

## Framework-Specific

Use the installed framework adapter's current documentation and deployment target. Next-on-Pages deprecation is not a reason to switch frameworks: Cloudflare documents Next.js on Workers (vinext and OpenNext) and React Router (formerly Remix). See [current framework guides](https://developers.cloudflare.com/workers/framework-guides/). Do not invent adapter package names or assume old Pages binding-access APIs work in new Workers adapters.

## Debugging

```typescript
// Log request details
console.log('Request:', { method: request.method, url: request.url });
console.log('Env:', Object.keys(env));
console.log('Params:', params);
```

**View logs**: `npx wrangler pages deployment tail --project-name=my-project`

## Placement and remote-development issues

Placement is workload-dependent: compare actual request duration before and after enabling it. Do not promise a fixed learning period or automatic latency reduction.

`wrangler pages dev --remote` is unsupported in Wrangler 4.129. Use local Pages bindings and preview deployments for remote integration tests, or follow the actual Workers development workflow when the project targets Workers. This flag error is not evidence of expired credentials.

## Common Errors

### "Module not found"
**Cause**: Dependencies not bundled or build output incorrect
**Solution**: Check build output directory, ensure dependencies bundled

### "Binding not found"
**Cause**: Binding not configured or types out of sync
**Solution**: Verify wrangler.jsonc, run `npx wrangler types`

### "Request exceeded CPU limit"
**Cause**: Code execution too slow or heavy compute
**Solution**: Optimize hot paths, upgrade to Workers Paid

### "Script too large"
**Cause**: Bundle size exceeds limit
**Solution**: Tree-shake, use dynamic imports, code-split

### "Too many subrequests"
**Cause**: Exceeded 50 subrequest limit
**Solution**: Batch or reduce fetch calls

### "KV key not found"
**Cause**: Key doesn't exist or wrong namespace
**Solution**: Check namespace matches environment

### "D1 error"
**Cause**: Wrong database_id or missing migrations
**Solution**: Verify config, run `wrangler d1 migrations list`

## Limits Reference

Read [Pages limits](https://developers.cloudflare.com/pages/platform/limits/) for builds/assets and [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) for Functions runtime quotas. Avoid a single Free/Paid table that conflates Pages zone-plan builds with Workers billing plans.

## Getting Help

1. Check [Pages Docs](https://developers.cloudflare.com/pages/)
2. Search [Discord #functions](https://discord.com/channels/595317990191398933/910978223968518144)
3. Review [Workers Examples](https://developers.cloudflare.com/workers/examples/)
4. Check framework-specific docs/adapters
