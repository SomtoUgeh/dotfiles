# Configuration

Fetch https://developers.cloudflare.com/agents/api-reference/configuration/ for complete documentation.

## Wrangler Config (`wrangler.jsonc`)

```jsonc
{
  "name": "my-agent",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-28",
  "compatibility_flags": ["nodejs_compat"],
  "durable_objects": {
    "bindings": [
      { "name": "MyAgent", "class_name": "MyAgent" },
      { "name": "ChatAgent", "class_name": "ChatAgent" }
    ]
  },
  "exports": {
    "MyAgent": { "type": "durable-object", "storage": "sqlite" },
    "ChatAgent": { "type": "durable-object", "storage": "sqlite" }
  },
  "ai": { "binding": "AI" },
  "assets": {
    "directory": "./dist/client",
    "binding": "ASSETS",
    "not_found_handling": "single-page-application",
    "run_worker_first": true
  }
}
```

## Key Rules

- For a new deployment, every agent class needs a Durable Object binding and a SQLite lifecycle entry in `exports`
- `nodejs_compat` is required
- Existing migration-based deployments remain supported; keep adding migration tags there. `migrations` and Durable Object `exports` cannot appear together
- Do NOT enable `experimentalDecorators` in tsconfig — it breaks `@callable`
- For Workers AI locally, set `"ai": { "binding": "AI", "remote": true }` in Wrangler config; `.dev.vars` holds secret/environment values, not binding configuration
- Use `wrangler secret put` for secrets, never hardcode them

## Vite Setup

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { cloudflare } from "@cloudflare/vite-plugin";
import agents from "agents/vite";

export default defineConfig({
  plugins: [react(), cloudflare(), agents()]
});
```

## Type Generation

```bash
npx wrangler types
```

By default this generates `worker-configuration.d.ts` with typed bindings (or the output path passed to the command). Regenerate after changing `wrangler.jsonc`.

## tsconfig

Extend the agents tsconfig for correct settings:

```jsonc
{
  "extends": ["agents/tsconfig"],
  "include": ["src/**/*.ts", "src/**/*.tsx"],
  "compilerOptions": { "paths": { "~/*": ["./src/*"] } }
}
```
