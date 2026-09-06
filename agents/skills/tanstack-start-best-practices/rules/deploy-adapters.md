# deploy-adapters: Configure the Host's Vite Plugin

## Priority: LOW

## Explanation

TanStack Start configures deployment through Vite plugins. Use the plugin documented by the target host, keep `tanstackStart()` before the React plugin, and test the production output locally before deploying. The old `app.config.ts` `server.preset` API is not part of current TanStack Start.

## Bad Example

```tsx
// vite.config.ts — no host plugin, and the React plugin runs too early
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [viteReact(), tanstackStart()],
})
```

## Good Example: Cloudflare Workers

```tsx
// vite.config.ts
import { cloudflare } from '@cloudflare/vite-plugin'
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [
    cloudflare({ viteEnvironment: { name: 'ssr' } }),
    tanstackStart(),
    viteReact(),
  ],
})
```

```jsonc
// wrangler.jsonc
{
  "name": "my-app",
  "compatibility_date": "2025-09-02",
  "compatibility_flags": ["nodejs_compat"],
  "main": "@tanstack/react-start/server-entry"
}
```

## Good Example: Netlify

```tsx
// vite.config.ts
import netlify from '@netlify/vite-plugin-tanstack-start'
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [tanstackStart(), netlify(), viteReact()],
})
```

## Good Example: Nitro Hosts

Use Nitro for Vercel, Railway, Node.js, and Docker deployments.

```tsx
// vite.config.ts
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [tanstackStart(), nitro(), viteReact()],
})
```

Build and run the Node.js output with:

```bash
npm run build
node .output/server/index.mjs
```

For Bun, pass its documented Nitro preset:

```tsx
plugins: [tanstackStart(), nitro({ preset: 'bun' }), viteReact()]
```

## Context

- Provider integrations and their package names can change; check the current TanStack Start hosting guide and provider documentation.
- Cloudflare Workers requires the `nodejs_compat` compatibility flag for Node.js APIs.
- Bun deployment requires React 19; use the Node.js output for React 18.
- Use `tanstackStart()` before `viteReact()` so Start can configure its environments first.
- Static prerendering is configured in `tanstackStart({ prerender, pages })`; it is separate from host configuration.

Reference: [TanStack Start Hosting](https://tanstack.com/start/latest/docs/framework/react/guide/hosting)
