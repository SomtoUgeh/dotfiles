# C3 Generated Configuration

## Output Structure

```
my-app/
├── src/index.ts          # Worker entry point
├── wrangler.jsonc        # Cloudflare config
├── package.json          # Scripts
├── tsconfig.json
└── .gitignore
```

## wrangler.jsonc

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/cloudflare/workers-sdk/main/packages/wrangler/config-schema.json",
  "name": "my-app",
  "main": "src/index.ts",
  "compatibility_date": "2026-01-27"
}
```

## Binding Placeholders

C3 generates **placeholder IDs** that must be replaced before deploy:

```jsonc
{
  "kv_namespaces": [{ "binding": "MY_KV", "id": "placeholder_kv_id" }],
  "d1_databases": [{ "binding": "DB", "database_id": "00000000-..." }]
}
```

**Replace with real IDs:**
```bash
npx wrangler kv namespace create MY_KV   # Returns real ID
npx wrangler d1 create my-database       # Returns real database_id
```

**Deployment error if not replaced:**
```
Error: Invalid KV namespace ID "placeholder_kv_id"
```

## Scripts

```json
{
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "cf-typegen": "wrangler types"
  }
}
```

## Type Generation

Run after adding bindings:
```bash
npm run cf-typegen
```

Generates `worker-configuration.d.ts` by default:
```typescript
interface Env {
  MY_KV: KVNamespace;
  DB: D1Database;
}
```

## Post-Creation Checklist

1. Review `wrangler.jsonc` - check name, compatibility_date
2. Replace placeholder binding IDs with real resource IDs
3. Run `npm run cf-typegen`
4. Test: `npm run dev`
5. Provision required secrets for the target Worker using `npx wrangler secret put SECRET_NAME`
6. Deploy when configuration and secrets are ready: `npm run deploy`

`--existing-script` downloads a deployed Worker; it does not convert local source or migrate an existing framework app. For an existing app, follow its current Workers framework guide. Workers Static Assets also support static sites, and Workers Builds supports Git workflows; Pages is an explicit framework-dependent choice. Inspect generated package scripts instead of assuming every framework uses the same names.
