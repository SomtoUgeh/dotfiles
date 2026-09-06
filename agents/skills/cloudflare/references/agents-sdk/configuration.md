# Agents SDK configuration

Use [shared configuration](../../../agents-sdk/references/configuration.md) for Wrangler, SQLite exports, Vite, and type generation, and [routing](../../../agents-sdk/references/routing.md) for HTTP/WebSocket routes.

- Inspect the actual package/lockfile and installed toolchain first.
- Generate binding types with the project's Wrangler; do not mark required bindings optional.
- Configure `nodejs_compat` and use TC39 decorators. `agents/vite` has a default export; do not enable TypeScript legacy `experimentalDecorators`.
- New classes use SQLite Durable Object `exports`. Existing migration-based deployments remain supported; do not combine `exports` and `migrations`.
- Await `getAgentByName()` for initialized named agents instead of using raw namespace stubs that skip agent setup.
- Configure email routing with an explicit resolver; see [Email](../../../agents-sdk/references/email.md).
- Keep API keys in secrets. Configure AI Gateway using the current [Workers AI gateway API](https://developers.cloudflare.com/ai-gateway/providers/workersai/).
