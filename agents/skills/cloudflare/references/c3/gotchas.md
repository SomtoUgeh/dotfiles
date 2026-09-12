# C3 Troubleshooting

## Deployment Issues

### Placeholder IDs

**Error:** "Invalid namespace ID"
**Fix:** Replace placeholders in wrangler.jsonc with real IDs:
```bash
npx wrangler kv namespace create MY_KV  # Get real ID
```

### Authentication

**Error:** "Not authenticated"
**Fix:** `npx wrangler login` or set `CLOUDFLARE_API_TOKEN`

### Name Conflict

**Error:** "Worker already exists"
**Fix:** Confirm the target account/environment and whether this is the intended existing Worker. Change `name` only when creating a distinct Worker.

## Platform Selection

Check the existing deployment, requested platform, and framework support. Workers supports Static Assets and Git builds; Pages remains an explicit supported target rather than the only option for static sites or previews. See [platform selection](README.md#platform-selection).

On a mismatch, preserve local changes and adapt the existing project using the matching framework/migration guide. Recreate only a disposable scaffold with no work to preserve.

## TypeScript Issues

**"Cannot find name 'KVNamespace'"**
```bash
npm run cf-typegen  # Regenerate types
# Restart TS server in editor
```

**Missing types after config change:** Re-run `npm run cf-typegen`

## Package Manager

**Multiple lockfiles causing issues:**
```bash
rm pnpm-lock.yaml  # If using npm
rm package-lock.json  # If using pnpm
```

## CI/CD

**CI hangs on prompts:**
```bash
npm create cloudflare@latest my-app -- \
  --type=hello-world --lang=ts --no-git --no-deploy
```

**Auth in CI:**
```yaml
env:
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

## Framework-Specific

| Framework | Issue | Fix |
|-----------|-------|-----|
| Next.js | create-next-app failed | `npm cache clean --force`, retry |
| Astro | Adapter missing | Install `@astrojs/cloudflare` |
| Remix | Module errors | Update `@remix-run/cloudflare*` |

## Compatibility Date

**"Feature X requires compatibility_date >= ..."**
**Fix:** Identify the required behavior and minimum compatibility date or flag. Preserve the existing date unless a change is needed, then test the affected behavior at the selected date. Do not upgrade all compatibility behavior merely because today is later.

## Node.js Version

**"Node.js version not supported"**
**Fix:** Use a currently supported Node.js LTS release that satisfies both C3 and Wrangler engines (Node.js 22 or newer for current Wrangler).

## Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| Invalid namespace ID | Placeholder binding | Create resource, update config |
| Not authenticated | No login | `npx wrangler login` |
| Cannot find KVNamespace | Missing types | `npm run cf-typegen` |
| Worker already exists | Existing target or name conflict | Confirm intended target before renaming |
| CI hangs | Missing flags | Add --type, --lang, --no-deploy |
| Template not found | Bad name | Check cloudflare/templates |
