# Configuration

## wrangler.jsonc

```jsonc
{
  "name": "my-pages-project",
  "pages_build_output_dir": "./dist",
  "compatibility_date": "2026-01-01", // Use current date for new projects
  "compatibility_flags": ["nodejs_compat"],
  "placement": {
    "mode": "smart"  // Optional: Enable Smart Placement
  },
  "kv_namespaces": [{"binding": "KV", "id": "abcd1234..."}],
  "d1_databases": [{"binding": "DB", "database_id": "xxxx-xxxx", "database_name": "production-db"}],
  "r2_buckets": [{"binding": "BUCKET", "bucket_name": "my-bucket"}],
  "durable_objects": {"bindings": [{"name": "COUNTER", "class_name": "Counter", "script_name": "counter-worker"}]},
  "services": [{"binding": "API", "service": "api-worker"}],
  "queues": {"producers": [{"binding": "QUEUE", "queue": "my-queue"}]},
  "vectorize": [{"binding": "VECTORIZE", "index_name": "my-index"}],
  "ai": {"binding": "AI"},
  "analytics_engine_datasets": [{"binding": "ANALYTICS"}],
  "vars": {"API_URL": "https://api.example.com", "ENVIRONMENT": "production"},
  "env": {
    "preview": {
      "vars": {"API_URL": "https://staging-api.example.com"},
      "kv_namespaces": [{"binding": "KV", "id": "preview-namespace-id"}]
    }
  }
}
```

## Build Config

**Git deployment**: Dashboard → Project → Settings → Build settings
Set build command, output dir, env vars. Framework auto-detection configures automatically.

## Environment Variables

### Local (.dev.vars)
```bash
# .dev.vars (never commit)
SECRET_KEY="local-secret-key"
API_TOKEN="dev-token-123"
```

### Production
```bash
echo "secret-value" | npx wrangler pages secret put SECRET_KEY --project-name=my-project
npx wrangler pages secret list --project-name=my-project
npx wrangler pages secret delete SECRET_KEY --project-name=my-project
```

Access: `env.SECRET_KEY`

## Static Config Files

### _redirects
Place in build output (e.g., `dist/_redirects`):

```txt
/old-page /new-page 301          # 301 redirect
/blog/* /news/:splat 301         # Splat wildcard
/users/:id /members/:id 301      # Placeholders
/api/* /api-v2/:splat 200        # Proxy (no redirect)
```

**Limits**: 2,100 total (2,000 static + 100 dynamic), 1,000 char/line
**Note**: Functions take precedence

### _headers
```txt
/secure/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff

/api/*
  Access-Control-Allow-Origin: *

/static/*
  Cache-Control: public, max-age=31536000, immutable
```

**Limits**: 100 rules, 2,000 char/line
**Note**: Only static assets; Functions set headers in Response

### _routes.json
Controls which requests invoke Functions (auto-generated for most frameworks):

```json
{
  "version": 1,
  "include": ["/*"],
  "exclude": ["/build/*", "/static/*", "/assets/*", "/*.ico", "/*.png", "/*.jpg", "/*.css", "/*.js"]
}
```

**Purpose**: Functions are metered; static requests are free. `exclude` takes precedence. Max 100 rules, 100 char/rule.

## TypeScript

```bash
npx wrangler types ./functions/types.d.ts
```

Point `types` in `functions/tsconfig.json` to generated file.

## Smart Placement

Automatically optimizes function execution location based on request patterns.

```jsonc
{
  "placement": {
    "mode": "smart"  // Enable optimization (default: off)
  }
}
```

**How it works**: Placement considers backend round-trip latency and can move execution closer to services/data when that reduces total request duration. It does not promise user-cluster placement or a fixed 24–48-hour improvement. Compare actual request duration with placement enabled; globally distributed users can still benefit when backend data is centralized.

## Local versus remote resources

`wrangler pages dev` runs Pages locally and does not expose a `--remote` flag in Wrangler 4.129. Do not copy Workers' remote-development command into Pages. Use supported local bindings and separately running Workers for service/DO bindings; test remote-only product behavior in a dedicated preview deployment. Check the current Pages binding documentation before assuming support for Workers-only remote binding options.

## Local Dev

```bash
# Basic
npx wrangler pages dev ./dist

# With bindings
npx wrangler pages dev ./dist --kv KV --d1 DB=local-db-id

# Persistence
npx wrangler pages dev ./dist --persist-to=./.wrangler/state/v3

# Framework dev: use the adapter's documented command; Pages proxy-command mode is deprecated
```

## Limits and billing

Check [Pages limits](https://developers.cloudflare.com/pages/platform/limits/) and [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) separately. As checked on 2026-09-05: Pages builds/month are 500 Free, 5,000 Pro, 20,000 Business; sites support 20,000 files Free and up to 100,000 on paid plans with `PAGES_WRANGLER_MAJOR_VERSION=4`; each asset is limited to 25 MiB. Build timeout is 20 minutes. Static asset requests are free; Functions use the Workers plan's request/CPU billing.
