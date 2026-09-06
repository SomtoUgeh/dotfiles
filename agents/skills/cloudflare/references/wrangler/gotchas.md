# Wrangler Common Issues

## Common Errors

### "Binding ID vs name mismatch"

**Cause:** Confusion between binding name (code) and resource ID
**Solution:** Bindings use `binding` (code name) and `id`/`database_id`/`bucket_name` (resource ID). Preview bindings need separate IDs: `preview_id`, `preview_database_id`

### "Environment not inheriting config"

**Cause:** Non-inheritable keys not redefined per environment
**Solution:** Non-inheritable keys (bindings, vars) must be redefined per environment. Inheritable keys (routes, compatibility_date) can be overridden

### "Local development differs from production"

Local workerd uses the same runtime engine, but local storage and network placement differ. Start with reproducible local tests. If the task needs account resources, check each binding's supported development modes; `wrangler dev --remote` runs remotely and can mutate real data. There is no `remote: "minimal"` Wrangler test option.

### "Unexpected runtime changes"

**Cause:** Missing compatibility_date
**Solution:** Always set `compatibility_date`:
```jsonc
{ "compatibility_date": "2025-01-01" }
```

### "Durable Object binding not working"

**Cause:** Missing script_name for external DOs
**Solution:** Always specify `script_name` for external Durable Objects:
```jsonc
{
  "durable_objects": {
    "bindings": [
      { "name": "MY_DO", "class_name": "MyDO", "script_name": "my-worker" }
    ]
  }
}
```

For local DOs in same Worker, `script_name` is optional.

### "Auto-provisioned resources not appearing"

**Cause:** IDs written back to config on first deploy, but config not reloaded
**Solution:** After first deploy with auto-provisioning, config file is updated with IDs. Commit the updated config. On subsequent deploys, existing resources are reused.

### "Secrets not available in local dev"

**Cause:** Secrets set with `wrangler secret put` only work in deployed Workers
**Solution:** For local dev, use `.dev.vars`

### "Node.js compatibility error"

**Cause:** Missing Node.js compatibility flag
**Solution:** Some bindings (Hyperdrive with `pg`) require:
```jsonc
{ "compatibility_flags": ["nodejs_compat"] }
```

### "Workers Assets 404 errors"

**Cause:** Asset path mismatch or incorrect `html_handling`
**Solution:** 
- Check `assets.directory` points to correct build output
- Set `html_handling: "auto-trailing-slash"` for SPAs
- Use `not_found_handling: "single-page-application"` to serve index.html for 404s
```jsonc
{
  "assets": {
    "directory": "./dist",
    "html_handling": "auto-trailing-slash",
    "not_found_handling": "single-page-application"
  }
}
```

### "Placement not reducing latency"

Smart Placement can reduce latency to backend services, including external APIs. Measure the actual request path; proximity alone does not guarantee improvement.

### "startWorker not found"

Wrangler 4.129.0 exports `unstable_startWorker`, not `startWorker`. Prefer the [integration test harness](./api.md) for tests. Miniflare and Wrangler options are not interchangeable.

## Limits

| Resource/Limit | Value | Notes |
|----------------|-------|-------|
| Static asset file size | 25 MiB | Per file |
| Static asset files | 20,000 free; 100,000 paid | Per Worker version |

Other limits depend on plan and workload. Check the [current platform limits](https://developers.cloudflare.com/workers/platform/limits/) before planning capacity; no universal 64-binding or 1 MB Wrangler config limit is established here.

## Troubleshooting

### Authentication Issues
```bash
wrangler logout
wrangler login
wrangler whoami
```

### Configuration Errors
```bash
wrangler check startup  # Profile Worker startup time and detect scripts exceeding the startup time limit
```
Use wrangler.jsonc with `$schema` for validation.

### Binding Not Available
- Check binding exists in config
- For environments, ensure binding defined for that env
- Local dev: some bindings need `--remote`

### Deployment Failures
```bash
wrangler tail              # Check logs
wrangler deploy --dry-run  # Validate
wrangler whoami            # Check account limits
```

### Local Development Issues
```bash
# Back up or rename .wrangler/state before resetting local data
wrangler dev --remote      # Use remote bindings
wrangler dev --persist-to ./local-state  # Custom persist location
wrangler dev --inspector-port 9229  # Enable debugging
```

### Testing Issues

Always close the [test harness](./api.md#integration-tests) or dispose the platform proxy in `finally`. Do not switch tests to remote resources merely because a binding was missing; first check the selected config and environment.

## Resources

- Docs: https://developers.cloudflare.com/workers/wrangler/
- Config: https://developers.cloudflare.com/workers/wrangler/configuration/
- Commands: https://developers.cloudflare.com/workers/wrangler/commands/
- Examples: https://github.com/cloudflare/workers-sdk/tree/main/templates
- Discord: https://discord.gg/cloudflaredev

## See Also

- [README.md](./README.md) - Commands
- [configuration.md](./configuration.md) - Config
- [api.md](./api.md) - Programmatic API
- [patterns.md](./patterns.md) - Workflows
