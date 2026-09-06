# Wrangler Development Patterns

Common workflows and best practices.

## New Worker Project

```bash
wrangler init my-worker && cd my-worker
wrangler dev              # Develop locally
wrangler deploy           # Deploy
```

## Local Development

```bash
wrangler dev              # Local mode (fast, simulated)
wrangler dev --remote     # Remote mode (production-accurate)
wrangler dev --env staging --port 8787
wrangler dev --inspector-port 9229  # Enable debugging
```

Debug: chrome://inspect → Configure → localhost:9229

## Secrets

```bash
# Production
wrangler secret put SECRET_KEY  # Enter the value at the prompt, not in shell history

# Local: use .dev.vars (gitignored)
# SECRET_KEY=local-dev-key
```

## Adding KV

```bash
wrangler kv namespace create MY_KV
wrangler kv namespace create MY_KV --preview
# Add to wrangler.jsonc: { "binding": "MY_KV", "id": "abc123" }
wrangler deploy
```

## Adding D1

```bash
wrangler d1 create my-db
wrangler d1 migrations create my-db "initial_schema"
# Edit migration file in migrations/, then:
wrangler d1 migrations apply my-db --local
wrangler deploy
wrangler d1 migrations apply my-db --remote

# Time Travel (restore to point in time)
wrangler d1 time-travel restore my-db --timestamp 2025-01-01T12:00:00Z
```

## Multi-Environment

```bash
wrangler deploy --env staging
wrangler deploy --env production
```

```jsonc
{ "env": { "staging": { "vars": { "ENV": "staging" } } } }
```

## Testing

### Integration Tests with Node.js Test Runner

Use the complete [`createTestHarness` example](./api.md#integration-tests). It closes the local runtime even when an assertion fails.

### Testing with Vitest

Install the Vitest version supported by the plugin. For `@cloudflare/vitest-plugin@1.1.4`: `npm install -D vitest@^4.1 @cloudflare/vitest-plugin@1.1.4`. Use an ESM project (`"type": "module"` in package.json).

**vitest.config.ts:**
```typescript
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })]
});
```

**tests/api.test.ts:**
```typescript
import { env, SELF } from "cloudflare:test";
import { describe, it, expect } from "vitest";

it("fetches users", async () => {
  const response = await SELF.fetch("https://example.com/api/users");
  expect(response.status).toBe(200);
});

it("uses bindings", async () => {
  await env.MY_KV.put("key", "value");
  expect(await env.MY_KV.get("key")).toBe("value");
});
```

### Multi-Worker Development and External API Mocks

List all Worker configs in the [test harness](./api.md#integration-tests) and declare service bindings in those configs. For unit tests, use the [Vitest outbound request mocks](https://developers.cloudflare.com/workers/testing/vitest-integration/test-apis/#fetchmock) and disable unmatched network access. Do not pass a Worker instance as a binding or copy Miniflare's `outboundService` into Wrangler options.

## Monitoring & Versions

```bash
wrangler tail                 # Real-time logs
wrangler tail --status error  # Filter errors
wrangler versions list
wrangler rollback [id]
```

## TypeScript

```bash
wrangler types  # Generate types from config
```

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return Response.json({ value: await env.MY_KV.get("key") });
  }
} satisfies ExportedHandler<Env>;
```

## Workers Assets

```jsonc
{ "assets": { "directory": "./dist", "binding": "ASSETS" } }
```

```typescript
export default {
  async fetch(request, env) {
    // API routes first
    if (new URL(request.url).pathname.startsWith("/api/")) {
      return Response.json({ data: "from API" });
    }
    return env.ASSETS.fetch(request);  // Static assets
  }
}
```

## See Also

- [README.md](./README.md) - Commands
- [configuration.md](./configuration.md) - Config
- [api.md](./api.md) - Programmatic API
- [gotchas.md](./gotchas.md) - Issues
