# Cloudflare Static Assets Skill Reference

Expert guidance for deploying and configuring static assets with Cloudflare Workers. This skill covers configuration patterns, routing architectures, asset binding usage, and best practices for SPAs, SSG sites, and full-stack applications.

## Quick Start

```jsonc
// wrangler.jsonc
{
  "name": "my-app",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "assets": {
    "directory": "./dist",
    "binding": "ASSETS"
  }
}
```

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return env.ASSETS.fetch(request);
  }
};
```

Deploy: `wrangler deploy`

## When to Use Workers Static Assets vs Pages

Workers Static Assets supports pure static sites, SPAs, and full-stack apps. Pages supports static sites and dynamic Pages Functions. Both platforms support Git-based deployment workflows; Git integration alone does not select Pages.

For new projects, check the [current framework guide](https://developers.cloudflare.com/workers/framework-guides/) and adapter support. Preserve an existing platform unless migration is part of the task. Choose routing and configuration according to that platform rather than treating static versus dynamic content as the deciding factor.

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## In This Reference

- **[configuration.md](configuration.md)** - Setup, deployment, configuration
- **[api.md](api.md)** - API endpoints, methods, interfaces
- **[patterns.md](patterns.md)** - Common patterns, use cases, examples
- **[gotchas.md](gotchas.md)** - Troubleshooting, best practices, limitations

## See Also

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Static Assets Docs](https://developers.cloudflare.com/workers/static-assets/)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
