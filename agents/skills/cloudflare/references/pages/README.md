# Cloudflare Pages

JAMstack platform for full-stack apps on Cloudflare's global network.

## Key Features

- **Git-based deploys**: Auto-deploy from GitHub/GitLab
- **Preview deployments**: Unique URL per branch/PR
- **Pages Functions**: File-based serverless routing (Workers runtime)
- **Static + dynamic**: Smart asset caching + edge compute
- **Smart Placement**: Automatic function optimization based on traffic patterns
- **Framework optimized**: SvelteKit, Astro, Nuxt, Qwik, Solid Start

## Deployment Methods

### 1. Git Integration (Production)
Dashboard → Workers & Pages → Create → Connect to Git → Configure build

### 2. Direct Upload
```bash
npx wrangler pages deploy ./dist --project-name=my-project
npx wrangler pages deploy ./dist --project-name=my-project --branch=staging
```

### 3. C3 CLI
```bash
npm create cloudflare@latest my-app -- --platform=pages
# Select a supported Pages framework/template; review generated setup
```

## vs Workers

- **Pages**: Keep existing Pages deployments and choose it when the requested platform and framework support Pages. Functions provide file-based routing.
- **Workers**: Supports static sites, full-stack frameworks, APIs, WebSockets, scheduled tasks, and email handlers. Git-based builds are also available.
- **New projects**: Check the [current framework guide](https://developers.cloudflare.com/workers/framework-guides/) and deployment requirements before selecting a platform.
- **Combine**: Pages Functions use Workers runtime, can bind to Workers

## Quick Start

```bash
# Create
npm create cloudflare@latest my-app -- --platform=pages

# Local dev
npx wrangler pages dev ./dist

# Deploy
npx wrangler pages deploy ./dist --project-name=my-project

# Types
npx wrangler types ./functions/types.d.ts

# Secrets
echo "value" | npx wrangler pages secret put KEY --project-name=my-project

# Logs
npx wrangler pages deployment tail --project-name=my-project
```

## Resources

- [Pages Docs](https://developers.cloudflare.com/pages/)
- [Functions API](https://developers.cloudflare.com/pages/functions/api-reference/)
- [Framework Guides](https://developers.cloudflare.com/pages/framework-guides/)
- [Discord #functions](https://discord.com/channels/595317990191398933/910978223968518144)

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

This directory owns Pages project setup, builds, deployment, and platform troubleshooting. For function routing, EventContext, middleware, and handler implementation, start with [Pages Functions](../pages-functions/README.md). The local API and patterns files retain Pages integration examples; do not load both sets by default.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- Function handlers, routing, and runtime behavior → [Pages Functions API](../pages-functions/api.md)
- Pages integration and advanced-mode examples → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## In This Reference

- [configuration.md](./configuration.md) - wrangler.jsonc, build, env vars, Smart Placement
- [api.md](./api.md) - Functions API, bindings, context, advanced mode
- [patterns.md](./patterns.md) - Full-stack patterns, framework integration
- [gotchas.md](./gotchas.md) - Build issues, limits, debugging, framework warnings

## See Also

- [pages-functions](../pages-functions/) - File-based routing, middleware
- [d1](../d1/) - SQL database for Pages Functions
- [kv](../kv/) - Key-value storage for caching/state
