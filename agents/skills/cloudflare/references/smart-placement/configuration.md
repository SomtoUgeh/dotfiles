# Smart Placement Configuration

## wrangler.jsonc Setup

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "placement": {
    "mode": "smart"
  }
}
```

## Placement Mode Values

| Mode | Behavior |
|------|----------|
| `"smart"` | Enable Smart Placement - automatic optimization based on traffic analysis |
| `"off"` | Explicitly disable Smart Placement - always run at edge closest to user |
| Not specified | Default behavior - run at edge closest to user (same as `"off"`) |

**Note:** Smart Placement vs Explicit Placement are separate features. Smart Placement (`mode: "smart"`) uses automatic analysis. For manual placement control, see explicit placement options (`region`, `host`, `hostname` fields - not covered in this reference).

## Frontend + Backend Split Configuration

### Frontend Worker (No Smart Placement)

```jsonc
// frontend-worker/wrangler.jsonc
{
  "name": "frontend",
  "main": "frontend-worker.ts",
  // No "placement" - runs at edge
  "services": [
    {
      "binding": "BACKEND",
      "service": "backend-api"
    }
  ]
}
```

### Backend Worker (Smart Placement Enabled)

```jsonc
// backend-api/wrangler.jsonc
{
  "name": "backend-api",
  "main": "backend-worker.ts",
  "placement": {
    "mode": "smart"
  },
  "d1_databases": [
    {
      "binding": "DATABASE",
      "database_id": "xxx"
    }
  ]
}
```

## Requirements & Limitations

### Requirements
- **Wrangler version:** 2.20.0+
- **Analysis time:** Up to 15 minutes
- **Traffic requirements:** Consistent multi-location traffic
- **Workers plan:** All plans (Free, Paid, Enterprise)

### What Smart Placement Affects

The current placement documentation explicitly limits optimization to default `fetch` handlers and excludes named entrypoints, RPC methods, and non-fetch events. That same page also includes an RPC placement example. These statements conflict: the examples here use fetch-based service bindings, and RPC placement is not verified. Do not migrate a working RPC API on this reference alone; verify current hosted behavior and guidance first.

### Baseline Traffic
Smart Placement automatically routes 1% of requests WITHOUT optimization as baseline for performance comparison.

### Validation Rules

**Mutually exclusive fields:**
- `mode` cannot be used with explicit placement fields (`region`, `host`, `hostname`)
- Choose either Smart Placement OR explicit placement, not both

```jsonc
// ✅ Valid - Smart Placement
{ "placement": { "mode": "smart" } }

// ✅ Valid - Explicit Placement (different feature)
{ "placement": { "region": "gcp:us-east1" } }

// ❌ Invalid - Cannot combine
{ "placement": { "mode": "smart", "region": "gcp:us-east1" } }
```

## Dashboard Configuration

**Workers & Pages** → Select Worker → **Settings** → **General** → **Placement: Smart** → Wait 15min → Check **Metrics**

## TypeScript Types

```typescript
interface Env {
  BACKEND: Fetcher;
  DATABASE: D1Database;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const data = await env.DATABASE.prepare('SELECT * FROM users').all();
    return Response.json(data);
  }
} satisfies ExportedHandler<Env>;
```

## Static Assets and Placement

Static assets served directly are delivered near the incoming request. Assets fetched by your code through `env.ASSETS.fetch()` are served where that Worker runs. `run_worker_first` affects which requests execute code; measure the full route before deciding to split frontend/backend Workers. Pages Functions and Workers Static Assets use different configuration models. There is no universal 2–5x penalty or blanket prohibition on combining assets with placement.

[Current placement behavior](https://developers.cloudflare.com/workers/configuration/placement/)

## Local Development

Smart Placement does NOT work in `wrangler dev` (local only). Test by deploying: `wrangler deploy --env staging`

The official placement page currently contains an RPC example that conflicts with its explicit fetch-only limitation. Rely on fetch-based calls for this reference; verify hosted RPC placement before changing architecture based on that example.
